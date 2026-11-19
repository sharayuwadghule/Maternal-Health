import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../database/local_db.dart';
import '../models/app_user.dart';
import '../network/supabase_service.dart';

/// Thrown for login failures that should be shown to the user.
class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);
  @override
  String toString() => message;
}

/// Result of requesting an OTP. [demoCode] is only set in demo mode, where
/// no SMS is sent and the code is shown on screen instead.
class OtpRequest {
  final String phone;
  final String? demoCode;
  const OtpRequest({required this.phone, this.demoCode});
}

/// Authentication.
///
/// * Live mode: every role signs in with Supabase phone OTP, so `auth.uid()`
///   is set and the Row Level Security policies in `schema.sql` apply. The
///   profile is looked up by `profiles.auth_user_id`.
/// * Staff (ASHA/ANM/Supervisor) can then set a 4-digit PIN that locks the
///   app on a shared phone. The PIN never leaves the device and is stored
///   only as a salted, iterated SHA-256 hash.
/// * Demo mode: seeded demo accounts, on-screen OTP codes.
class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  static const String _currentUserKey = 'current_app_user';
  static const String _pinRecordKey = 'staff_pin_record';
  static const String _pinFailuresKey = 'staff_pin_failures';
  static const String _pinLockedUntilKey = 'staff_pin_locked_until';

  static const int _pinIterations = 10000;
  static const int maxPinFailures = 5;
  static const Duration pinLockout = Duration(minutes: 5);

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  /// Load persisted session from local cache on startup.
  Future<AppUser?> loadSession() async {
    try {
      final cached = LocalDb.prefsBox.get(_currentUserKey);
      if (cached == null) return null;

      // In live mode a cached profile without a Supabase session would fail
      // every RLS-protected request, so require a fresh sign-in.
      final client = SupabaseService.instance.client;
      if (!AppConfig.demoMode && client != null && client.auth.currentSession == null) {
        await LocalDb.prefsBox.delete(_currentUserKey);
        return null;
      }

      _currentUser = AppUser.fromMap(Map<String, dynamic>.from(cached as Map));
      return _currentUser;
    } catch (e) {
      debugPrint('Error loading cached session: $e');
    }
    return null;
  }

  Future<void> _persist(AppUser user) async {
    _currentUser = user;
    await LocalDb.prefsBox.put(_currentUserKey, user.toMap());
  }

  // ── Demo accounts ───────────────────────────────────────────────────────

  static const Map<UserRole, AppUser> demoUsers = {
    UserRole.patient: AppUser(
      id: '33333333-3333-3333-3333-333333333301',
      name: 'Priyanka More',
      phone: '9811111101',
      role: UserRole.patient,
      language: 'mr',
      phcId: '11111111-1111-1111-1111-111111111111',
    ),
    UserRole.asha: AppUser(
      id: '22222222-2222-2222-2222-222222222241',
      name: 'Savita Tai',
      phone: '9800000021',
      role: UserRole.asha,
      language: 'mr',
      phcId: '11111111-1111-1111-1111-111111111111',
    ),
    UserRole.anm: AppUser(
      id: '22222222-2222-2222-2222-222222222231',
      name: 'Sunita Gaikwad',
      phone: '9800000011',
      role: UserRole.anm,
      language: 'mr',
      phcId: '11111111-1111-1111-1111-111111111111',
    ),
    UserRole.supervisor: AppUser(
      id: '22222222-2222-2222-2222-222222222221',
      name: 'Dr. Rajesh Patil',
      phone: '9800000001',
      role: UserRole.supervisor,
      language: 'mr',
      phcId: '11111111-1111-1111-1111-111111111111',
    ),
    UserRole.caregiver: AppUser(
      id: '44444444-4444-4444-4444-444444444401',
      name: 'Sachin More',
      phone: '9822222201',
      role: UserRole.caregiver,
      language: 'mr',
      phcId: '11111111-1111-1111-1111-111111111111',
    ),
  };

  /// Sign in as a seeded demo account. Only allowed in demo mode.
  Future<AppUser> loginAsDemoRole(UserRole role) async {
    if (!AppConfig.demoMode) {
      throw const AuthFailure('Demo accounts are disabled when a backend is configured.');
    }
    final user = demoUsers[role]!;
    await _persist(user);
    return user;
  }

  // ── Phone OTP ───────────────────────────────────────────────────────────

  String _e164(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final national = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    return '${AppConfig.phoneCountryCode}$national';
  }

  static bool isValidIndianMobile(String phone) =>
      RegExp(r'^[6-9]\d{9}$').hasMatch(phone.replaceAll(RegExp(r'\D'), ''));

  Future<OtpRequest> requestOtp(String phone) async {
    if (!isValidIndianMobile(phone)) {
      throw const AuthFailure('Enter a valid 10-digit mobile number.');
    }
    final client = SupabaseService.instance.client;
    if (AppConfig.demoMode || client == null) {
      final code = (Random.secure().nextInt(900000) + 100000).toString();
      return OtpRequest(phone: phone, demoCode: code);
    }
    try {
      await client.auth.signInWithOtp(phone: _e164(phone), shouldCreateUser: false);
      return OtpRequest(phone: phone);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  Future<AppUser> verifyOtp({
    required OtpRequest request,
    required String otp,
    UserRole demoRole = UserRole.patient,
  }) async {
    if (request.demoCode != null) {
      if (otp != request.demoCode) throw const AuthFailure('Wrong code. Please check and try again.');
      return loginAsDemoRole(demoRole);
    }

    final client = SupabaseService.instance.client!;
    try {
      final res = await client.auth.verifyOTP(
        type: OtpType.sms,
        phone: _e164(request.phone),
        token: otp,
      );
      final uid = res.user?.id;
      if (uid == null) throw const AuthFailure('Verification failed. Please try again.');

      final profile = await client
          .from('profiles')
          .select('id, name, phone, role, language, phc_id')
          .eq('auth_user_id', uid)
          .maybeSingle();
      if (profile == null) {
        await client.auth.signOut();
        throw const AuthFailure('This number is not registered. Please contact your PHC.');
      }
      final user = AppUser.fromMap(profile);
      await _persist(user);
      return user;
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  // ── Staff offline PIN (device lock) ──────────────────────────────────────

  bool get hasOfflinePin {
    final record = LocalDb.prefsBox.get(_pinRecordKey);
    return record is Map && record['user_id'] == _currentUser?.id;
  }

  DateTime? get pinLockedUntil {
    final raw = LocalDb.prefsBox.get(_pinLockedUntilKey) as String?;
    final until = raw == null ? null : DateTime.tryParse(raw);
    return (until != null && until.isAfter(DateTime.now())) ? until : null;
  }

  String _hashPin(String pin, List<int> salt) {
    var digest = sha256.convert([...salt, ...utf8.encode(pin)]).bytes;
    for (var i = 1; i < _pinIterations; i++) {
      digest = sha256.convert([...digest, ...salt]).bytes;
    }
    return base64Encode(digest);
  }

  Future<void> setOfflinePin(String pin) async {
    final user = _currentUser;
    if (user == null) throw const AuthFailure('Sign in before setting a PIN.');
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) throw const AuthFailure('PIN must be 4 digits.');
    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    await LocalDb.prefsBox.put(_pinRecordKey, {
      'user_id': user.id,
      'salt': base64Encode(salt),
      'hash': _hashPin(pin, salt),
    });
    await LocalDb.prefsBox.delete(_pinFailuresKey);
  }

  /// Returns true when the PIN matches. Locks out after repeated failures.
  Future<bool> verifyOfflinePin(String pin) async {
    if (pinLockedUntil != null) return false;
    final record = LocalDb.prefsBox.get(_pinRecordKey);
    if (record is! Map || record['user_id'] != _currentUser?.id) return false;

    final salt = base64Decode(record['salt'] as String);
    final ok = _hashPin(pin, salt) == record['hash'];
    if (ok) {
      await LocalDb.prefsBox.delete(_pinFailuresKey);
      return true;
    }
    final failures = (LocalDb.prefsBox.get(_pinFailuresKey) as int? ?? 0) + 1;
    await LocalDb.prefsBox.put(_pinFailuresKey, failures);
    if (failures >= maxPinFailures) {
      await LocalDb.prefsBox.put(
        _pinLockedUntilKey,
        DateTime.now().add(pinLockout).toIso8601String(),
      );
      await LocalDb.prefsBox.delete(_pinFailuresKey);
    }
    return false;
  }

  // ── Sign out ────────────────────────────────────────────────────────────

  Future<void> logout() async {
    _currentUser = null;
    await LocalDb.prefsBox.delete(_currentUserKey);
    await LocalDb.prefsBox.delete(_pinRecordKey);
    await LocalDb.prefsBox.delete(_pinFailuresKey);
    await LocalDb.prefsBox.delete(_pinLockedUntilKey);
    try {
      await SupabaseService.instance.client?.auth.signOut();
    } catch (_) {}
  }
}
