import 'package:flutter/foundation.dart';
import '../database/local_db.dart';
import '../models/patient_model.dart';
import '../network/supabase_service.dart';

class PatientRepository {
  PatientRepository._();
  static final PatientRepository instance = PatientRepository._();

  /// Initial seed patients matching the Implementation Plan seed dataset
  static final List<PatientModel> defaultSeedPatients = [
    PatientModel(
      id: '55555555-5555-5555-5555-555555555501',
      profileId: '33333333-3333-3333-3333-333333333301',
      name: 'Priyanka More',
      phone: '9811111101',
      dateOfBirth: DateTime(1998, 4, 12),
      lmp: DateTime.now().subtract(const Duration(days: 160)),
      edd: DateTime.now().add(const Duration(days: 120)),
      heightCm: 152.0,
      bloodGroup: 'B+',
      gravida: 1,
      para: 0,
      assignedAshaId: '22222222-2222-2222-2222-222222222241',
      assignedAnmId: '22222222-2222-2222-2222-222222222231',
    ),
    PatientModel(
      id: '55555555-5555-5555-5555-555555555502',
      profileId: '33333333-3333-3333-3333-333333333302',
      name: 'Sita Devi',
      phone: '9811111102',
      dateOfBirth: DateTime(2009, 2, 15), // 17 yrs (Teenage pregnancy)
      lmp: DateTime.now().subtract(const Duration(days: 180)),
      edd: DateTime.now().add(const Duration(days: 100)),
      heightCm: 148.0,
      bloodGroup: 'O+',
      gravida: 1,
      para: 0,
      isConfirmedHrp: true,
      hrpCategory: 'Teenage Pregnancy & High BP',
      assignedAshaId: '22222222-2222-2222-2222-222222222241',
      assignedAnmId: '22222222-2222-2222-2222-222222222231',
    ),
    PatientModel(
      id: '55555555-5555-5555-5555-555555555503',
      profileId: '33333333-3333-3333-3333-333333333303',
      name: 'Meena Rao',
      phone: '9811111103',
      dateOfBirth: DateTime(1996, 8, 20),
      lmp: DateTime.now().subtract(const Duration(days: 130)),
      edd: DateTime.now().add(const Duration(days: 150)),
      heightCm: 155.0,
      bloodGroup: 'AB-',
      rhNegative: true,
      stillbirthHistory: true,
      isConfirmedHrp: true,
      hrpCategory: 'Severe Anemia (Hb 6.8 g/dL)',
      assignedAshaId: '22222222-2222-2222-2222-222222222241',
      assignedAnmId: '22222222-2222-2222-2222-222222222231',
    ),
    PatientModel(
      id: '55555555-5555-5555-5555-555555555504',
      profileId: '33333333-3333-3333-3333-333333333304',
      name: 'Pooja Singh',
      phone: '9811111104',
      dateOfBirth: DateTime(1999, 11, 5),
      lmp: DateTime.now().subtract(const Duration(days: 90)),
      edd: DateTime.now().add(const Duration(days: 190)),
      heightCm: 158.0,
      bloodGroup: 'A+',
      gravida: 1,
      para: 0,
      assignedAshaId: '22222222-2222-2222-2222-222222222242',
      assignedAnmId: '22222222-2222-2222-2222-222222222232',
    ),
    PatientModel(
      id: '55555555-5555-5555-5555-555555555505',
      profileId: '33333333-3333-3333-3333-333333333305',
      name: 'Aarti Deshmukh',
      phone: '9811111105',
      dateOfBirth: DateTime(1988, 9, 14), // 36 yrs
      lmp: DateTime.now().subtract(const Duration(days: 200)),
      edd: DateTime.now().add(const Duration(days: 80)),
      heightCm: 150.0,
      bloodGroup: 'O-',
      rhNegative: true,
      previousCSection: true,
      isConfirmedHrp: true,
      hrpCategory: 'Previous C-Section & Age Risk Factor',
      assignedAshaId: '22222222-2222-2222-2222-222222222243',
      assignedAnmId: '22222222-2222-2222-2222-222222222232',
    ),
  ];

  /// Initialize local cache with seed data if currently empty
  Future<void> ensureCachePopulated() async {
    final box = LocalDb.patientsBox;
    if (box.isEmpty) {
      for (final p in defaultSeedPatients) {
        await box.put(p.id, p.toMap());
      }
      debugPrint('Populated local Hive cache with ${defaultSeedPatients.length} seed patients.');
    }
  }

  /// Get all patients (cache-first)
  Future<List<PatientModel>> getAllPatients() async {
    await ensureCachePopulated();
    final box = LocalDb.patientsBox;
    final cached = box.values
        .map((e) => PatientModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    // If Supabase is connected, refresh from backend in background
    if (SupabaseService.instance.isConfigured) {
      try {
        final client = SupabaseService.instance.client;
        final res = await client?.from('patients').select('*, profiles(name, phone)');
        if (res != null && res.isNotEmpty) {
          final List<PatientModel> remoteList = [];
          for (final item in res) {
            final profile = item['profiles'] as Map<String, dynamic>?;
            final map = Map<String, dynamic>.from(item);
            map['name'] = profile?['name'] ?? 'Mother';
            map['phone'] = profile?['phone'] ?? '';
            final model = PatientModel.fromMap(map);
            remoteList.add(model);
            await box.put(model.id, model.toMap());
          }
          return remoteList;
        }
      } catch (e) {
        debugPrint('Error fetching patients from Supabase: $e');
      }
    }

    return cached;
  }

  /// Patients assigned to a specific ASHA worker. Never falls back to
  /// "all patients" – an ASHA must only see her own mothers.
  Future<List<PatientModel>> getPatientsForAsha(String ashaId) async {
    final all = await getAllPatients();
    return all.where((p) => p.assignedAshaId == ashaId).toList();
  }

  /// Get single patient by ID. Returns null when unknown – never another
  /// patient's record.
  Future<PatientModel?> getPatientById(String id) async {
    await ensureCachePopulated();
    final raw = LocalDb.patientsBox.get(id);
    if (raw == null) return null;
    return PatientModel.fromMap(Map<String, dynamic>.from(raw as Map));
  }

  /// Synchronous lookup of the patient record linked to a login profile.
  PatientModel? findByProfileId(String? profileId) {
    if (profileId == null || profileId.isEmpty) return null;
    for (final raw in LocalDb.patientsBox.values) {
      final map = Map<String, dynamic>.from(raw as Map);
      if (map['profile_id'] == profileId) return PatientModel.fromMap(map);
    }
    return null;
  }

  /// Mark or confirm High-Risk Pregnancy status (ANM action)
  Future<void> confirmHrp(String patientId, String hrpCategory, {String? confirmedBy}) async {
    final patient = await getPatientById(patientId);
    if (patient == null) return;

    final updated = patient.withHrp(confirmed: true, category: hrpCategory);
    await LocalDb.patientsBox.put(patient.id, updated.toMap());

    await LocalDb.enqueueSync(
      table: 'patients',
      action: 'update',
      payload: {
        'id': patientId,
        'is_confirmed_hrp': true,
        'hrp_category': hrpCategory,
        'confirmed_at': DateTime.now().toIso8601String(),
        'confirmed_by_anm_id': ?confirmedBy,
      },
    );
  }
}
