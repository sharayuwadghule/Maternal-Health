import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:maternalhealth_app/core/database/local_db.dart';
import 'package:maternalhealth_app/core/models/app_user.dart';
import 'package:maternalhealth_app/core/models/patient_model.dart';
import 'package:maternalhealth_app/core/network/remote_schema.dart';
import 'package:maternalhealth_app/core/repositories/alert_repository.dart';
import 'package:maternalhealth_app/core/repositories/auth_repository.dart';
import 'package:maternalhealth_app/core/repositories/patient_repository.dart';
import 'package:maternalhealth_app/core/services/sync_service.dart';
import 'package:maternalhealth_app/core/utils/ids.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_core_fixes');
    Hive.init(tempDir.path);
    for (final name in LocalDb.allBoxNames) {
      await Hive.openBox(name);
    }
    await PatientRepository.instance.ensureCachePopulated();
    SyncService.instance.setSimulatedOffline(true); // keep the outbox inspectable
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('IDs and remote payloads', () {
    test('legacy non-UUID ids are mapped to stable UUIDs', () {
      final a = Ids.toUuid('alert-1712345678');
      expect(Ids.isUuid(a), true);
      expect(Ids.toUuid('alert-1712345678'), a); // deterministic
      const real = '55555555-5555-5555-5555-555555555501';
      expect(Ids.toUuid(real), real);
    });

    test('alert payload drops local-only columns and fixes ids', () {
      final out = RemoteSchema.sanitize('alerts', {
        'id': 'alert-seed-01',
        'patient_id': '55555555-5555-5555-5555-555555555501',
        'patient_name': 'Priyanka',
        'escalation_id': 'x',
        'type': 'high_bp',
      });
      expect(out.containsKey('patient_name'), false);
      expect(out.containsKey('escalation_id'), false);
      expect(Ids.isUuid(out['id'] as String), true);
    });

    test('medicine logs upsert on their natural key, without local id', () {
      final out = RemoteSchema.sanitize('medicine_logs', {
        'id': 'p-2026-01-01-Iron',
        'patient_id': '55555555-5555-5555-5555-555555555501',
        'medicine': 'Iron',
        'log_date': '2026-01-01',
        'taken': true,
        'is_synced': false,
      });
      expect(out.keys.toSet(), {'patient_id', 'medicine', 'log_date', 'taken'});
      expect(RemoteSchema.conflictTargets['medicine_logs'], 'patient_id,medicine,log_date');
    });

    test('new alerts get UUIDs and are queued for sync', () async {
      final before = LocalDb.syncQueueBox.length;
      final alert = await AlertRepository.instance.createAlert(
        patientId: '55555555-5555-5555-5555-555555555501',
        patientName: 'Priyanka',
        type: 'danger_sign_reported',
        severity: 'urgent',
        message: 'test',
      );
      expect(Ids.isUuid(alert.id), true);
      expect(LocalDb.syncQueueBox.length, before + 1);
    });
  });

  group('Patient lookups', () {
    test('unknown patient id returns null, never another patient', () async {
      expect(await PatientRepository.instance.getPatientById('does-not-exist'), isNull);
    });

    test('ASHA only sees her own assigned mothers', () async {
      final list = await PatientRepository.instance
          .getPatientsForAsha('22222222-2222-2222-2222-222222222241');
      expect(list.every((p) => p.assignedAshaId == '22222222-2222-2222-2222-222222222241'), true);
      expect(await PatientRepository.instance.getPatientsForAsha('unknown'), isEmpty);
    });
  });

  group('PMSMA countdown', () {
    test('counts calendar days regardless of time of day', () {
      expect(PatientModel.daysUntilPmsma(DateTime(2026, 3, 8, 23, 59)), 1);
      expect(PatientModel.daysUntilPmsma(DateTime(2026, 3, 9, 18)), 0);
      expect(PatientModel.daysUntilPmsma(DateTime(2026, 3, 10, 8)), 30);
      expect(PatientModel.daysUntilPmsma(DateTime(2026, 12, 20)), 20);
    });
  });

  group('Session persistence', () {
    test('a signed-in user is restored after an app restart', () async {
      await AuthRepository.instance.loginAsDemoRole(UserRole.patient);
      // Simulate a fresh launch: in-memory state is gone, only Hive remains.
      final restored = await AuthRepository.instance.loadSession();
      expect(restored?.id, AuthRepository.demoUsers[UserRole.patient]!.id);
      await AuthRepository.instance.logout();
      expect(await AuthRepository.instance.loadSession(), isNull);
    });
  });

  group('Staff offline PIN', () {
    test('PIN is stored hashed and verified', () async {
      await AuthRepository.instance.loginAsDemoRole(UserRole.asha);
      await AuthRepository.instance.setOfflinePin('4821');
      final record = LocalDb.prefsBox.get('staff_pin_record') as Map;
      expect(record.values.contains('4821'), false);
      expect(await AuthRepository.instance.verifyOfflinePin('4821'), true);
      expect(await AuthRepository.instance.verifyOfflinePin('0000'), false);
    });

    test('locks out after repeated failures', () async {
      for (var i = 0; i < AuthRepository.maxPinFailures; i++) {
        await AuthRepository.instance.verifyOfflinePin('0000');
      }
      expect(AuthRepository.instance.pinLockedUntil, isNotNull);
      expect(await AuthRepository.instance.verifyOfflinePin('4821'), false);
      await AuthRepository.instance.logout();
      expect(AuthRepository.instance.pinLockedUntil, isNull);
    });
  });
}
