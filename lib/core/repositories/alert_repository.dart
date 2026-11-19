import '../database/local_db.dart';
import '../models/alert_model.dart';
import '../utils/ids.dart';

class AlertRepository {
  AlertRepository._();
  static final AlertRepository instance = AlertRepository._();

  /// Stable UUID of the demo "missed medicine" alert used by the closed-loop demo.
  static const String demoMedicineAlertId = 'a1e7a000-0000-4000-8000-000000000001';
  static const String _demoBpAlertId = 'a1e7a000-0000-4000-8000-000000000002';

  /// IDs used by older builds (not UUIDs) – removed on startup.
  static const List<String> _legacyIds = ['alert-seed-01', 'alert-seed-02', 'alert-loop-01'];

  static List<AlertModel> get defaultSeedAlerts => [
        AlertModel(
          id: demoMedicineAlertId,
          patientId: '55555555-5555-5555-5555-555555555501',
          patientName: 'Priyanka More',
          type: 'missed_dose_3_days',
          severity: 'urgent',
          status: AlertStatus.open,
          assignedTo: '22222222-2222-2222-2222-222222222241',
          message: 'Medicine alert: Priyanka More has missed Iron & Calcium for 4 consecutive days.',
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        ),
        AlertModel(
          id: _demoBpAlertId,
          patientId: '55555555-5555-5555-5555-555555555502',
          patientName: 'Sita Devi',
          type: 'high_bp',
          severity: 'urgent',
          status: AlertStatus.escalated,
          assignedTo: '22222222-2222-2222-2222-222222222241',
          message: 'High BP alert: Sita Devi systolic BP reached 146 mmHg.',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];

  Future<void> ensureCachePopulated() async {
    final box = LocalDb.alertsBox;
    for (final legacy in _legacyIds) {
      if (box.containsKey(legacy)) await box.delete(legacy);
    }
    if (box.isEmpty) {
      for (final a in defaultSeedAlerts) {
        await box.put(a.id, a.toMap());
      }
    }
  }

  /// Create a new alert locally and queue it for sync.
  Future<AlertModel> createAlert({
    required String patientId,
    required String patientName,
    required String type,
    required String severity,
    required String message,
    String? assignedTo,
    String? id,
  }) async {
    final alert = AlertModel(
      id: id ?? Ids.newId(),
      patientId: patientId,
      patientName: patientName,
      type: type,
      severity: severity,
      status: AlertStatus.open,
      assignedTo: assignedTo,
      message: message,
      createdAt: DateTime.now(),
    );
    await LocalDb.alertsBox.put(alert.id, alert.toMap());
    await LocalDb.enqueueSync(table: 'alerts', action: 'upsert', payload: alert.toMap());
    return alert;
  }

  /// Alerts assigned to an ASHA (all alerts in demo data are hers).
  Future<List<AlertModel>> getAlertsForAsha(String ashaId) async {
    await ensureCachePopulated();
    final list = LocalDb.alertsBox.values
        .map((e) => AlertModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((a) => a.assignedTo == null || a.assignedTo == ashaId)
        .toList();

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Alerts escalated to an ANM (plus ones she already decided), newest first.
  Future<List<AlertModel>> getAlertsForAnm(Set<String> patientIds) async {
    await ensureCachePopulated();
    final list = LocalDb.alertsBox.values
        .map((e) => AlertModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((a) =>
            (patientIds.isEmpty || patientIds.contains(a.patientId)) &&
            (a.status == AlertStatus.escalated || a.status == AlertStatus.closed))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Check if there is an active medicine-missed alert
  Future<bool> hasActiveMedicineAlert() async {
    await ensureCachePopulated();
    return LocalDb.alertsBox.values.any((e) {
      final map = Map<String, dynamic>.from(e as Map);
      return map['type'] == 'missed_dose_3_days' && map['status'] == 'open';
    });
  }

  Future<void> _updateStatus(String alertId, Map<String, dynamic> changes) async {
    final box = LocalDb.alertsBox;
    final raw = box.get(alertId);
    if (raw != null) {
      final map = Map<String, dynamic>.from(raw as Map)..addAll(changes);
      await box.put(alertId, map);
    }
    await LocalDb.enqueueSync(
      table: 'alerts',
      action: 'update',
      payload: {'id': alertId, ...changes},
    );
  }

  /// ASHA acknowledges an alert
  Future<void> acknowledgeAlert(String alertId) => _updateStatus(alertId, {
        'status': 'acknowledged',
        'acknowledged_at': DateTime.now().toIso8601String(),
      });

  /// ASHA escalates alert to ANM
  Future<void> escalateToAnm({
    required String alertId,
    required String ashaId,
    required String anmId,
    required String notes,
  }) async {
    final escalationId = Ids.newId();
    await _updateStatus(alertId, {'status': 'escalated'});
    // Remember the escalation locally so the ANM decision can update it.
    final raw = LocalDb.alertsBox.get(alertId);
    if (raw != null) {
      await LocalDb.alertsBox.put(
        alertId,
        Map<String, dynamic>.from(raw as Map)..['escalation_id'] = escalationId,
      );
    }

    final escalation = EscalationModel(
      id: escalationId,
      alertId: alertId,
      escalatedBy: ashaId,
      escalatedTo: anmId,
      decisionNotes: notes,
      createdAt: DateTime.now(),
    );

    await LocalDb.enqueueSync(
      table: 'escalations',
      action: 'upsert',
      payload: escalation.toMap(),
    );
  }

  /// Record the ANM's decision on the escalation linked to [alertId].
  Future<void> recordEscalationDecision({
    required String alertId,
    required String decision,
    required String decidedBy,
    required String notes,
  }) async {
    final raw = LocalDb.alertsBox.get(alertId);
    final escalationId = raw is Map ? raw['escalation_id']?.toString() : null;
    if (escalationId == null) return;
    await LocalDb.enqueueSync(
      table: 'escalations',
      action: 'update',
      payload: {
        'id': escalationId,
        'decision': decision,
        'decision_notes': notes,
        'decided_by': decidedBy,
        'decided_at': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Close alert
  Future<void> closeAlert(String alertId, String resolutionNotes, {String? closedBy}) =>
      _updateStatus(alertId, {
        'status': 'closed',
        'closed_at': DateTime.now().toIso8601String(),
        'resolution_notes': resolutionNotes,
        'closed_by': ?closedBy,
      });
}
