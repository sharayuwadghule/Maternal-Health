import '../utils/ids.dart';

/// Describes the columns each Supabase table actually has, so local-only
/// fields (e.g. `patient_name`, `is_synced`) are never sent to the server.
/// Keep this in sync with `supabase/schema.sql`.
class RemoteSchema {
  RemoteSchema._();

  static const Map<String, Set<String>> _columns = {
    'alerts': {
      'id', 'patient_id', 'type', 'severity', 'status', 'assigned_to', 'message',
      'created_at', 'acknowledged_at', 'closed_at', 'closed_by', 'resolution_notes',
    },
    'escalations': {
      'id', 'alert_id', 'escalated_by', 'escalated_to', 'decision',
      'decision_notes', 'decided_by', 'decided_at', 'created_at',
    },
    'visits': {
      'id', 'patient_id', 'recorded_by', 'recorded_by_role', 'visit_date', 'systolic',
      'diastolic', 'hemoglobin', 'weight_kg', 'fundal_height_cm', 'fetal_heart_rate',
      'danger_signs', 'notes', 'recorded_at',
    },
    // `id` intentionally omitted: rows are keyed by (patient_id, medicine, log_date).
    'medicine_logs': {'patient_id', 'medicine', 'log_date', 'taken', 'logged_at'},
    'patients': {
      'id', 'is_confirmed_hrp', 'hrp_category', 'confirmed_by_anm_id', 'confirmed_at',
    },
    'sos_events': {
      'id', 'patient_id', 'triggered_at', 'latitude', 'longitude', 'status', 'resolved_at',
    },
  };

  /// Upsert conflict targets for tables whose natural key is not `id`.
  static const Map<String, String> conflictTargets = {
    'medicine_logs': 'patient_id,medicine,log_date',
  };

  /// Columns that hold UUID references.
  static const Set<String> _uuidColumns = {
    'id', 'patient_id', 'alert_id', 'assigned_to', 'escalated_by', 'escalated_to',
    'decided_by', 'recorded_by', 'closed_by', 'confirmed_by_anm_id',
  };

  static bool isKnownTable(String table) => _columns.containsKey(table);

  /// Strips unknown columns and repairs non-UUID identifiers.
  static Map<String, dynamic> sanitize(String table, Map<String, dynamic> payload) {
    final allowed = _columns[table];
    final out = <String, dynamic>{};
    payload.forEach((key, value) {
      if (allowed != null && !allowed.contains(key)) return;
      if (_uuidColumns.contains(key) && value is String && value.isNotEmpty) {
        out[key] = Ids.toUuid(value);
      } else {
        out[key] = value;
      }
    });
    return out;
  }
}
