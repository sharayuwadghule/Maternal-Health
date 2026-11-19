import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/sync_service.dart';
import '../utils/ids.dart';

class LocalDb {
  static const String patientsBoxName = 'patients';
  static const String visitsBoxName = 'visits';
  static const String alertsBoxName = 'alerts';
  static const String medicinesBoxName = 'medicines';
  static const String syncQueueBoxName = 'sync_queue';
  static const String deadLetterBoxName = 'sync_dead_letter';
  static const String prefsBoxName = 'prefs';

  static const List<String> allBoxNames = [
    patientsBoxName,
    visitsBoxName,
    alertsBoxName,
    medicinesBoxName,
    syncQueueBoxName,
    deadLetterBoxName,
    prefsBoxName,
  ];

  static Future<void> init() async {
    await Hive.initFlutter();
    for (final name in allBoxNames) {
      await Hive.openBox(name);
    }
    debugPrint('Hive Local Database initialized with ${allBoxNames.length} storage boxes.');
  }

  static Box get patientsBox => Hive.box(patientsBoxName);
  static Box get visitsBox => Hive.box(visitsBoxName);
  static Box get alertsBox => Hive.box(alertsBoxName);
  static Box get medicinesBox => Hive.box(medicinesBoxName);
  static Box get syncQueueBox => Hive.box(syncQueueBoxName);
  static Box get deadLetterBox => Hive.box(deadLetterBoxName);
  static Box get prefsBox => Hive.box(prefsBoxName);

  /// Outbox helper: queues a local mutation to be synced to the remote backend.
  ///
  /// [action] is `insert`/`upsert` (idempotent upsert), `update` (partial
  /// update of an existing row by `id`) or `delete`.
  static Future<void> enqueueSync({
    required String table,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final item = {
      'id': Ids.newId(),
      'table': table,
      'action': action,
      'payload': payload,
      'enqueued_at': DateTime.now().toIso8601String(),
      'attempts': 0,
    };
    await syncQueueBox.add(item);
    SyncService.instance.triggerSync();
  }

  /// Get pending sync items
  static List<Map<String, dynamic>> getPendingSyncItems() {
    return syncQueueBox.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Clear synced item from outbox
  static Future<void> removeSyncItem(int key) async {
    await syncQueueBox.delete(key);
  }
}
