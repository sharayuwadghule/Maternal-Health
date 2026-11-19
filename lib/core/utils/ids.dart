import 'package:uuid/uuid.dart';

/// ID helpers. Every table in Supabase uses UUID primary keys, so every
/// record created on the device must carry a real UUID.
class Ids {
  Ids._();

  static const Uuid _uuid = Uuid();

  /// Namespace for deterministic v5 UUIDs derived from legacy/local keys.
  static const String _namespace = '6f1c2b8e-4c1d-4b7a-9a51-3d0f1e2a7c44';

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// A fresh random UUID (v4) for new records.
  static String newId() => _uuid.v4();

  static bool isUuid(String? value) => value != null && _uuidPattern.hasMatch(value);

  /// Returns [value] unchanged if it is already a UUID, otherwise a stable
  /// v5 UUID derived from it. Used to repair legacy local IDs such as
  /// `alert-1712345678` that were queued before IDs became UUIDs, so they
  /// sync idempotently instead of being rejected by Postgres forever.
  static String toUuid(String value) =>
      isUuid(value) ? value : _uuid.v5(_namespace, value);
}
