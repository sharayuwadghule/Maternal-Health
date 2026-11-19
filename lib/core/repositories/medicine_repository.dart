import 'package:flutter/foundation.dart';
import '../database/local_db.dart';
import '../models/medicine_log_model.dart';

class MedicineRepository {
  MedicineRepository._();
  static final MedicineRepository instance = MedicineRepository._();

  static const String demoPatientId = '55555555-5555-5555-5555-555555555501';

  /// Ensure initial demo logs exist in local Hive cache
  Future<void> ensureCachePopulated() async {
    final box = LocalDb.medicinesBox;
    if (box.isEmpty) {
      final now = DateTime.now();
      // Populate past 7 days: days -7 to -5 were taken; days -4 to -1 were missed
      for (int i = 7; i >= 1; i--) {
        final d = now.subtract(Duration(days: i));
        final taken = i > 4; // Days 7, 6, 5 taken; Days 4, 3, 2, 1 missed (triggers 4 consecutive missed days!)
        for (final med in ['Iron', 'Calcium', 'Folic Acid']) {
          final log = MedicineLogModel(
            id: '$demoPatientId-${_formatDate(d)}-$med',
            patientId: demoPatientId,
            medicine: med,
            logDate: d,
            taken: taken,
            loggedAt: d,
            isSynced: true,
          );
          await box.put(log.id, log.toMap());
        }
      }
      debugPrint('Populated Hive medicinesBox with demo adherence history (4 missed days).');
    }
  }

  String _formatDate(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  /// Get status for a specific medicine on a given date
  Future<bool> isMedicineTaken({
    required String patientId,
    required String medicine,
    required DateTime date,
  }) async {
    await ensureCachePopulated();
    final id = '$patientId-${_formatDate(date)}-$medicine';
    final raw = LocalDb.medicinesBox.get(id);
    if (raw != null) {
      final map = Map<String, dynamic>.from(raw as Map);
      return map['taken'] == true;
    }
    return false;
  }

  /// Toggle medicine status (Cache-first + Outbox queue + Remote sync)
  Future<bool> toggleMedicine({
    required String patientId,
    required String medicine,
    required DateTime date,
  }) async {
    await ensureCachePopulated();
    final currentlyTaken = await isMedicineTaken(
      patientId: patientId,
      medicine: medicine,
      date: date,
    );
    final newTakenStatus = !currentlyTaken;

    final id = '$patientId-${_formatDate(date)}-$medicine';
    final log = MedicineLogModel(
      id: id,
      patientId: patientId,
      medicine: medicine,
      logDate: date,
      taken: newTakenStatus,
      loggedAt: DateTime.now(),
      isSynced: false,
    );

    // 1. Write to local Hive cache immediately
    await LocalDb.medicinesBox.put(id, log.toMap());

    // 2. Enqueue into offline sync outbox (upserted on patient/medicine/date)
    await LocalDb.enqueueSync(
      table: 'medicine_logs',
      action: 'upsert',
      payload: log.toMap(),
    );

    return newTakenStatus;
  }

  /// Calculate consecutive missed days prior to [today]
  Future<int> getConsecutiveMissedDays(String patientId, DateTime today) async {
    await ensureCachePopulated();
    int missedCount = 0;
    for (int i = 1; i <= 14; i++) {
      final checkDate = today.subtract(Duration(days: i));
      // Check if Iron or Calcium was taken
      final ironTaken = await isMedicineTaken(patientId: patientId, medicine: 'Iron', date: checkDate);
      final calciumTaken = await isMedicineTaken(patientId: patientId, medicine: 'Calcium', date: checkDate);

      if (!ironTaken && !calciumTaken) {
        missedCount++;
      } else {
        break; // Streak broken
      }
    }
    return missedCount;
  }
}
