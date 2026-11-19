import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../database/local_db.dart';
import '../models/app_user.dart';
import '../models/patient_model.dart';
import '../network/supabase_service.dart';
import '../utils/ids.dart';
import 'alert_repository.dart';
import 'auth_repository.dart';

class CareContact {
  final UserRole role;
  final String name;
  final String phone;
  const CareContact({required this.role, required this.name, required this.phone});

  Map<String, dynamic> toMap() => {'role': role.name, 'name': name, 'phone': phone};
  factory CareContact.fromMap(Map<String, dynamic> m) => CareContact(
        role: UserRole.fromString(m['role']?.toString() ?? 'asha'),
        name: m['name']?.toString() ?? '',
        phone: m['phone']?.toString() ?? '',
      );
}

/// The mother's assigned ASHA / ANM contacts, cached on the device so the
/// SOS screen works with no data connection.
class CareTeamRepository {
  CareTeamRepository._();
  static final CareTeamRepository instance = CareTeamRepository._();

  static const String _cacheKey = 'care_team';

  List<CareContact> cached() {
    final raw = LocalDb.prefsBox.get(_cacheKey);
    if (raw is! List) return const [];
    return raw.map((e) => CareContact.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  CareContact? assignedAsha() {
    for (final c in cached()) {
      if (c.role == UserRole.asha && c.phone.isNotEmpty) return c;
    }
    return null;
  }

  /// Refreshes the cache. Live mode uses the `get_my_care_team()` RPC
  /// (see supabase/schema.sql) because RLS hides other profiles from mothers.
  Future<void> refresh(PatientModel? patient) async {
    final contacts = <CareContact>[];
    final client = SupabaseService.instance.client;

    if (!AppConfig.demoMode && client != null) {
      try {
        final rows = await client.rpc('get_my_care_team') as List<dynamic>;
        for (final r in rows) {
          contacts.add(CareContact.fromMap(Map<String, dynamic>.from(r as Map)));
        }
      } catch (e) {
        debugPrint('Care team refresh failed, keeping cached contacts: $e');
        return;
      }
    } else if (patient != null) {
      for (final user in AuthRepository.demoUsers.values) {
        if (user.id == patient.assignedAshaId || user.id == patient.assignedAnmId) {
          contacts.add(CareContact(role: user.role, name: user.name, phone: user.phone));
        }
      }
    }

    await LocalDb.prefsBox.put(_cacheKey, contacts.map((c) => c.toMap()).toList());
  }

  /// Records an SOS: an `sos_events` row plus an urgent alert for the ASHA.
  Future<void> recordSos(PatientModel patient) async {
    final now = DateTime.now();
    await LocalDb.enqueueSync(
      table: 'sos_events',
      action: 'upsert',
      payload: {
        'id': Ids.newId(),
        'patient_id': patient.id,
        'triggered_at': now.toIso8601String(),
        'status': 'active',
      },
    );
    await AlertRepository.instance.createAlert(
      patientId: patient.id,
      patientName: patient.name,
      type: 'danger_sign_reported',
      severity: 'urgent',
      assignedTo: patient.assignedAshaId,
      message: 'SOS: ${patient.name} pressed the emergency button.',
    );
  }

}
