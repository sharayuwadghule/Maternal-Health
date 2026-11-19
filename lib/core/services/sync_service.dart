import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../network/remote_schema.dart';
import '../database/local_db.dart';
import '../network/supabase_service.dart';
import '../../app_state.dart';

class SyncResult {
  final bool success;
  final int syncedCount;
  final String message;

  const SyncResult({
    required this.success,
    this.syncedCount = 0,
    required this.message,
  });
}

/// Offline Sync Manager
///
/// Implements the cache-first, outbox pattern for the Maternal Health App.
/// Handles network connectivity monitoring, live demo offline simulation,
/// queue draining, and synchronization with Supabase backend.
class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService instance = SyncService._();

  bool _isOnline = true;
  bool _isSimulatedOffline = false;
  bool _isSyncing = false;
  DateTime? _lastSyncedAt;
  String? _lastError;
  Timer? _periodicTimer;
  Timer? _debounceTimer;
  RealtimeChannel? _alertsChannel;

  bool get isOnline => !_isSimulatedOffline && _isOnline;
  bool get isSimulatedOffline => _isSimulatedOffline;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get lastError => _lastError;
  int get pendingCount => LocalDb.syncQueueBox.length;

  /// Initialize sync manager and start background heartbeat
  Future<void> init() async {
    final count = pendingCount;
    AppState.instance.setPendingSyncCount(count);
    AppState.instance.setOnlineStatus(isOnline);

    await checkConnectivity();

    // Start background sync heartbeat (every 20 seconds)
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      await checkConnectivity();
      if (isOnline && pendingCount > 0 && !_isSyncing) {
        await syncNow();
      }
    });

    _setupRealtimeSubscriptions();
    debugPrint('SyncService initialized. Pending queue items: $pendingCount');
  }

  /// Toggle simulated offline mode (for Avishkar live demo)
  void setSimulatedOffline(bool simulated) {
    _isSimulatedOffline = simulated;
    AppState.instance.setOnlineStatus(isOnline);
    notifyListeners();
  }

  /// Test network connectivity
  Future<bool> checkConnectivity() async {
    if (_isSimulatedOffline) {
      _isOnline = false;
      AppState.instance.setOnlineStatus(false);
      notifyListeners();
      return false;
    }

    try {
      // Fast DNS lookup to verify real internet connectivity
      // Probe the backend host itself when configured (that is what we sync to).
      final host = SupabaseService.instance.isConfigured
          ? Uri.parse(SupabaseService.supabaseUrl).host
          : 'google.com';
      final result = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 3));
      final connected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _isOnline = connected;
      AppState.instance.setOnlineStatus(connected);
      notifyListeners();
      return connected;
    } catch (_) {
      _isOnline = false;
      AppState.instance.setOnlineStatus(false);
      notifyListeners();
      return false;
    }
  }

  /// Trigger debounced sync (called after local data mutations)
  void triggerSync() {
    AppState.instance.setPendingSyncCount(pendingCount);
    notifyListeners();

    if (!isOnline) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      if (isOnline && pendingCount > 0 && !_isSyncing) {
        syncNow();
      }
    });
  }

  /// Max push attempts before an item is moved to the dead-letter box.
  static const int maxAttempts = 10;

  int get deadLetterCount => LocalDb.deadLetterBox.length;

  /// Drain the outbox queue and push items to Supabase.
  ///
  /// Items are pushed strictly in order. A transient failure (network, auth,
  /// server) stops the drain so later updates never overtake earlier inserts;
  /// the head item is retried with exponential backoff. A permanent failure
  /// (constraint / type / unknown column) moves the item to the dead-letter
  /// box so one bad record can never block the whole queue.
  Future<SyncResult> syncNow() async {
    if (_isSimulatedOffline) {
      return const SyncResult(
        success: false,
        message: 'Offline mode is currently active (Airplane simulation)',
      );
    }

    if (_isSyncing) {
      return const SyncResult(
        success: false,
        message: 'Sync is already in progress',
      );
    }

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    int successCount = 0;
    final queueBox = LocalDb.syncQueueBox;

    try {
      final keys = queueBox.keys.toList();

      if (keys.isEmpty) {
        _lastSyncedAt = DateTime.now();
        return const SyncResult(
          success: true,
          syncedCount: 0,
          message: 'Outbox is clean. Everything is up to date.',
        );
      }

      final client = SupabaseService.instance.client;

      if (client == null) {
        if (AppConfig.demoMode) {
          // Demo mode has no server: the device is the source of truth, so the
          // outbox is acknowledged locally. This is explicit and only in demo.
          final count = keys.length;
          await queueBox.clear();
          _lastSyncedAt = DateTime.now();
          return SyncResult(
            success: true,
            syncedCount: count,
            message: 'Demo mode: $count changes saved on this device (no backend configured).',
          );
        }
        _lastError = 'Backend not configured';
        return SyncResult(
          success: false,
          message: 'Backend not configured. ${keys.length} changes kept on device.',
        );
      }

      for (final key in keys) {
        final rawItem = queueBox.get(key);
        if (rawItem == null) continue;

        final item = Map<String, dynamic>.from(rawItem as Map);

        final nextAttempt = DateTime.tryParse(item['next_attempt_at']?.toString() ?? '');
        if (nextAttempt != null && nextAttempt.isAfter(DateTime.now())) {
          break; // Head of queue is backing off; preserve ordering.
        }

        final table = item['table'] as String;
        final action = item['action'] as String? ?? 'upsert';
        final payload = RemoteSchema.sanitize(
          table,
          Map<String, dynamic>.from(item['payload'] as Map),
        );

        try {
          await _push(client, table, action, payload);
          await queueBox.delete(key);
          successCount++;
        } catch (e) {
          _lastError = e.toString();
          final attempts = (item['attempts'] as int? ?? 0) + 1;
          if (_isPermanentError(e) || attempts >= maxAttempts) {
            debugPrint('Sync item $key ($table) moved to dead-letter: $e');
            await LocalDb.deadLetterBox.add({
              ...item,
              'attempts': attempts,
              'last_error': e.toString(),
              'failed_at': DateTime.now().toIso8601String(),
            });
            await queueBox.delete(key);
            continue;
          }
          final backoffSeconds = (15 * (1 << attempts)).clamp(15, 1800);
          await queueBox.put(key, {
            ...item,
            'attempts': attempts,
            'last_error': e.toString(),
            'next_attempt_at':
                DateTime.now().add(Duration(seconds: backoffSeconds)).toIso8601String(),
          });
          debugPrint('Sync item $key ($table) failed (attempt $attempts), retry in ${backoffSeconds}s: $e');
          break;
        }
      }

      _lastSyncedAt = DateTime.now();
      final remaining = queueBox.length;
      return SyncResult(
        success: _lastError == null,
        syncedCount: successCount,
        message: 'Synced $successCount items. $remaining remaining.',
      );
    } catch (e) {
      _lastError = e.toString();
      return SyncResult(
        success: false,
        syncedCount: successCount,
        message: 'Sync error: $e',
      );
    } finally {
      _isSyncing = false;
      AppState.instance.setPendingSyncCount(queueBox.length);
      notifyListeners();
    }
  }

  Future<void> _push(
    SupabaseClient client,
    String table,
    String action,
    Map<String, dynamic> payload,
  ) async {
    switch (action) {
      case 'delete':
        await client.from(table).delete().eq('id', payload['id']);
        break;
      case 'update':
        final id = payload.remove('id');
        await client.from(table).update(payload).eq('id', id);
        break;
      default:
        await client.from(table).upsert(
              payload,
              onConflict: RemoteSchema.conflictTargets[table],
            );
    }
  }

  /// Postgres data/constraint/schema errors will never succeed on retry.
  bool _isPermanentError(Object e) {
    if (e is PostgrestException) {
      final code = e.code ?? '';
      return code.startsWith('22') || // data exception (bad uuid, bad value)
          code.startsWith('23') || // integrity constraint violation
          code.startsWith('42') || // undefined column / table / syntax
          code == 'PGRST204'; // column not found in schema cache
    }
    return false;
  }

  /// Supabase Realtime: mirror server-side alert changes into the local cache
  /// so ASHA/ANM devices see new alerts without a manual refresh.
  void _setupRealtimeSubscriptions() {
    final client = SupabaseService.instance.client;
    if (client == null) return;

    try {
      _alertsChannel = client
          .channel('public:alerts')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'alerts',
            callback: (change) {
              final record = change.newRecord;
              if (record.isEmpty || record['id'] == null) return;
              final map = Map<String, dynamic>.from(record);
              final patient = LocalDb.patientsBox.get(map['patient_id']);
              if (patient is Map && patient['name'] != null) {
                map['patient_name'] = patient['name'];
              }
              LocalDb.alertsBox.put(map['id'], map);
              notifyListeners();
            },
          )
          .subscribe();
      debugPrint('Supabase Realtime: listening for alert changes.');
    } catch (e) {
      debugPrint('Error setting up Supabase Realtime: $e');
    }
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _debounceTimer?.cancel();
    _alertsChannel?.unsubscribe();
    super.dispose();
  }
}
