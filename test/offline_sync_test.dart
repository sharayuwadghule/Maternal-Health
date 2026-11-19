import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:maternalhealth_app/app_state.dart';
import 'package:maternalhealth_app/core/database/local_db.dart';
import 'package:maternalhealth_app/core/services/sync_service.dart';
import 'package:maternalhealth_app/core/services/risk_engine.dart';
import 'package:maternalhealth_app/core/repositories/patient_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_offline_test');
    Hive.init(tempDir.path);
    for (final name in LocalDb.allBoxNames) {
      await Hive.openBox(name);
    }

    await PatientRepository.instance.ensureCachePopulated();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Offline-First Architecture & Outbox Queue Verification', () {
    test('1. Patient repository serves data 100% offline from local Hive cache', () async {
      final patients = await PatientRepository.instance.getAllPatients();
      expect(patients.isNotEmpty, true);
      expect(patients.first.name.contains('Priyanka More'), true);
    });

    test('2. RiskEngine v2 computes risk and trilingual reasons 100% on-device offline', () {
      final risk = RiskEngine.evaluate(
        age: 17,
        systolic: 145,
        diastolic: 95,
        hemoglobin: 8.4,
        consecutiveMissedMedsDays: 4,
      );

      // Total: Age(2) + BP(3) + Hb(2) + Missed(2) = 9 (High Risk)
      expect(risk.level, RiskLevel.high);
      expect(risk.score, 9);
      expect(risk.reasonsEn.isNotEmpty, true);
      expect(risk.reasonsMr.isNotEmpty, true);
      expect(risk.reasonsHi.isNotEmpty, true);
    });

    test('3. Simulated Offline Mode blocks remote network calls and increments outbox', () async {
      final sync = SyncService.instance;
      sync.setSimulatedOffline(true);

      expect(sync.isOnline, false);
      expect(sync.isSimulatedOffline, true);
      expect(AppState.instance.isOnline, false);

      // Enqueue a local offline medicine log
      await LocalDb.enqueueSync(
        table: 'medicine_logs',
        action: 'insert',
        payload: {
          'patient_id': '55555555-5555-5555-5555-555555555501',
          'medicine': 'iron',
          'taken': true,
        },
      );

      // Enqueue an offline symptom log
      await LocalDb.enqueueSync(
        table: 'visits',
        action: 'insert',
        payload: {
          'patient_id': '55555555-5555-5555-5555-555555555501',
          'systolic': 120,
          'diastolic': 80,
        },
      );

      expect(LocalDb.syncQueueBox.length, 2);
      expect(AppState.instance.pendingSyncCount, 2);

      // Attempting to sync while offline should be safely prevented
      final result = await sync.syncNow();
      expect(result.success, false);
      expect(result.message.contains('Offline mode is currently active'), true);
      expect(LocalDb.syncQueueBox.length, 2);
    });

    test('4. Reconnection allows outbox drainage and clears pending count', () async {
      final sync = SyncService.instance;
      sync.setSimulatedOffline(false);

      expect(sync.isSimulatedOffline, false);

      // Drain outbox in mock/offline demo mode
      final result = await sync.syncNow();
      expect(result.success, true);
      expect(result.syncedCount, 2);
      expect(LocalDb.syncQueueBox.isEmpty, true);
      expect(AppState.instance.pendingSyncCount, 0);
    });
  });
}
