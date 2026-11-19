import '../database/local_db.dart';
import '../models/visit_model.dart';
import '../utils/ids.dart';

class VisitRepository {
  VisitRepository._();
  static final VisitRepository instance = VisitRepository._();

  static final List<VisitModel> defaultSeedVisits = [
    VisitModel(
      id: 'b15e0000-0000-4000-8000-000000000001',
      patientId: '55555555-5555-5555-5555-555555555501',
      recordedBy: '22222222-2222-2222-2222-222222222241',
      recordedByRole: 'asha',
      visitDate: DateTime.now().subtract(const Duration(days: 14)),
      systolic: 118,
      diastolic: 76,
      hemoglobin: 11.2,
      weightKg: 54.5,
      notes: 'Regular home checkup. Patient feeling healthy.',
      recordedAt: DateTime.now().subtract(const Duration(days: 14)),
    ),
    VisitModel(
      id: 'b15e0000-0000-4000-8000-000000000002',
      patientId: '55555555-5555-5555-5555-555555555502',
      recordedBy: '22222222-2222-2222-2222-222222222231',
      recordedByRole: 'anm',
      visitDate: DateTime.now().subtract(const Duration(days: 5)),
      systolic: 146,
      diastolic: 94,
      hemoglobin: 10.4,
      weightKg: 49.0,
      dangerSigns: ['severe_headache'],
      notes: 'Stage 1 gestational hypertension detected. Referred for ANM review.',
      recordedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    VisitModel(
      id: 'b15e0000-0000-4000-8000-000000000003',
      patientId: '55555555-5555-5555-5555-555555555503',
      recordedBy: '22222222-2222-2222-2222-222222222231',
      recordedByRole: 'anm',
      visitDate: DateTime.now().subtract(const Duration(days: 3)),
      systolic: 112,
      diastolic: 72,
      hemoglobin: 6.8,
      weightKg: 47.0,
      notes: 'Severe anemia on Hb test. Referred to PHC for IV iron.',
      recordedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    VisitModel(
      id: 'b15e0000-0000-4000-8000-000000000004',
      patientId: '55555555-5555-5555-5555-555555555505',
      recordedBy: '22222222-2222-2222-2222-222222222243',
      recordedByRole: 'asha',
      visitDate: DateTime.now().subtract(const Duration(days: 8)),
      systolic: 124,
      diastolic: 80,
      hemoglobin: 8.8,
      weightKg: 58.0,
      notes: 'Moderate anemia. Counselled on iron-rich diet.',
      recordedAt: DateTime.now().subtract(const Duration(days: 8)),
    ),
  ];

  static const List<String> _legacyIds = ['visit-seed-01', 'visit-seed-02'];

  Future<void> ensureCachePopulated() async {
    final box = LocalDb.visitsBox;
    for (final legacy in _legacyIds) {
      if (box.containsKey(legacy)) await box.delete(legacy);
    }
    // Add any missing seed visit (keeps upgrades consistent with fresh installs).
    for (final v in defaultSeedVisits) {
      if (!box.containsKey(v.id)) await box.put(v.id, v.toMap());
    }
  }

  /// Get visits for a specific patient
  Future<List<VisitModel>> getVisitsForPatient(String patientId) async {
    await ensureCachePopulated();
    final box = LocalDb.visitsBox;
    final all = box.values
        .map((e) => VisitModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((v) => v.patientId == patientId)
        .toList();

    all.sort((a, b) => b.visitDate.compareTo(a.visitDate));
    return all;
  }

  /// Latest and previous visit with vitals, for risk scoring and trends.
  Future<({VisitModel? latest, VisitModel? previous})> getLatestVitals(String patientId) async {
    final visits = await getVisitsForPatient(patientId);
    final withVitals = visits
        .where((v) => v.systolic != null || v.hemoglobin != null || v.dangerSigns.isNotEmpty)
        .toList();
    return (
      latest: withVitals.isNotEmpty ? withVitals[0] : null,
      previous: withVitals.length > 1 ? withVitals[1] : null,
    );
  }

  /// Record a new visit
  Future<VisitModel> logVisit({
    required String patientId,
    required String recordedBy,
    required String recordedByRole,
    required DateTime visitDate,
    int? systolic,
    int? diastolic,
    double? hemoglobin,
    double? weightKg,
    List<String> dangerSigns = const [],
    String? notes,
  }) async {
    final newVisit = VisitModel(
      id: Ids.newId(),
      patientId: patientId,
      recordedBy: recordedBy,
      recordedByRole: recordedByRole,
      visitDate: visitDate,
      systolic: systolic,
      diastolic: diastolic,
      hemoglobin: hemoglobin,
      weightKg: weightKg,
      dangerSigns: dangerSigns,
      notes: notes,
      recordedAt: DateTime.now(),
    );

    // 1. Write to local Hive cache
    await LocalDb.visitsBox.put(newVisit.id, newVisit.toMap());

    // 2. Queue in outbox (the sync service pushes it when online)
    await LocalDb.enqueueSync(
      table: 'visits',
      action: 'upsert',
      payload: newVisit.toMap(),
    );

    return newVisit;
  }
}
