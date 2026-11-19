import 'package:flutter/foundation.dart';
import '../../app_state.dart';
import '../database/local_db.dart';
import '../models/medicine_log_model.dart';
import '../repositories/alert_repository.dart';
import '../repositories/patient_repository.dart';

/// Closed loop: missed tablets -> ASHA alert -> ANM escalation -> HRP decision.
///
/// All steps are offline-first: they write to Hive and the sync outbox. The
/// server never receives a direct RPC in addition to the outbox write, so
/// escalations are not duplicated when the device is online.
class ClosedLoopService extends ChangeNotifier {
  ClosedLoopService._();
  static final ClosedLoopService instance = ClosedLoopService._();

  static const String demoPatientId = '55555555-5555-5555-5555-555555555501';
  static const String demoAshaId = '22222222-2222-2222-2222-222222222241';
  static const String demoAnmId = '22222222-2222-2222-2222-222222222231';

  String get _currentUserIdOr => AppState.instance.currentUser?.id ?? '';

  /// Demo step 1: simulate 4 consecutive missed days for the demo mother.
  Future<void> simulateConsecutiveMissedDays() async {
    final now = DateTime.now();
    for (int i = 1; i <= 4; i++) {
      final date = now.subtract(Duration(days: i));
      for (final med in ['Iron', 'Calcium', 'Folic Acid']) {
        final id = '$demoPatientId-${_formatDate(date)}-$med';
        final log = MedicineLogModel(
          id: id,
          patientId: demoPatientId,
          medicine: med,
          logDate: date,
          taken: false,
          loggedAt: date,
        );
        await LocalDb.medicinesBox.put(id, log.toMap());
      }
    }

    // Step 2: alert for the assigned ASHA.
    await AlertRepository.instance.createAlert(
      id: AlertRepository.demoMedicineAlertId,
      patientId: demoPatientId,
      patientName: 'Priyanka More',
      type: 'missed_dose_3_days',
      severity: 'urgent',
      assignedTo: demoAshaId,
      message: 'Automated detection: Priyanka More has missed Iron & Calcium for 4 consecutive days.',
    );

    notifyListeners();
  }

  /// Step 3: ASHA calls/visits and escalates the alert to the ANM.
  Future<void> ashaEscalateAlert({
    required String alertId,
    required String notes,
    String? anmId,
  }) async {
    final ashaId = _currentUserIdOr.isNotEmpty ? _currentUserIdOr : demoAshaId;
    await AlertRepository.instance.escalateToAnm(
      alertId: alertId,
      ashaId: ashaId,
      anmId: anmId ?? demoAnmId,
      notes: notes,
    );
    notifyListeners();
  }

  /// Step 4: ANM confirms HRP status, closing the alert.
  Future<void> anmConfirmHrp({
    required String alertId,
    required String patientId,
    required String notes,
  }) async {
    final anmId = _currentUserIdOr.isNotEmpty ? _currentUserIdOr : demoAnmId;

    await PatientRepository.instance.confirmHrp(patientId, notes, confirmedBy: anmId);
    await AlertRepository.instance.recordEscalationDecision(
      alertId: alertId,
      decision: 'confirm_hrp',
      decidedBy: anmId,
      notes: notes,
    );
    await AlertRepository.instance.closeAlert(
      alertId,
      'Confirmed as High-Risk Pregnancy by ANM: $notes',
      closedBy: anmId,
    );

    notifyListeners();
  }

  /// Reset the closed-loop demo scenario back to its default state.
  Future<void> resetDemoLoop() async {
    final patient = await PatientRepository.instance.getPatientById(demoPatientId);
    if (patient != null) {
      final map = patient.toMap()
        ..['is_confirmed_hrp'] = false
        ..['hrp_category'] = null;
      await LocalDb.patientsBox.put(patient.id, map);
    }

    await LocalDb.alertsBox.clear();
    await AlertRepository.instance.ensureCachePopulated();

    notifyListeners();
  }

  String _formatDate(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
}
