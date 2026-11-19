import 'package:flutter/material.dart';
import 'core/models/app_user.dart';
import 'core/repositories/auth_repository.dart';
import 'core/database/local_db.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum AppLanguage { english, hindi, marathi }

class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  AppLanguage _language = AppLanguage.english;
  AppLanguage get language => _language;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  UserRole get currentRole => _currentUser?.role ?? UserRole.patient;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  int _pendingSyncCount = 0;
  int get pendingSyncCount => _pendingSyncCount;

  static const String _languageKey = 'app_language';
  static const String _consentKey = 'consent_accepted';

  /// True once the user has explicitly picked a language on this device.
  bool get hasChosenLanguage => _prefs?.get(_languageKey) != null;

  bool get hasAcceptedConsent => _prefs?.get(_consentKey) == true;

  Box? get _prefs =>
      Hive.isBoxOpen(LocalDb.prefsBoxName) ? LocalDb.prefsBox : null;

  /// Restore the saved language on startup.
  void loadPreferences() {
    final saved = _prefs?.get(_languageKey) as String?;
    if (saved != null) {
      _language = AppLanguage.values.firstWhere(
        (l) => l.name == saved,
        orElse: () => AppLanguage.english,
      );
    }
  }

  void setLanguage(AppLanguage lang) {
    _language = lang;
    _prefs?.put(_languageKey, lang.name);
    notifyListeners();
  }

  void acceptConsent() => _prefs?.put(_consentKey, true);

  /// Sets the signed-in user. The language the user chose on this device
  /// always wins; the profile language is only used if none was chosen.
  void setUser(AppUser? user) {
    _currentUser = user;
    if (user != null && !hasChosenLanguage) {
      _language = switch (user.language) {
        'hi' => AppLanguage.hindi,
        'mr' => AppLanguage.marathi,
        _ => AppLanguage.english,
      };
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await AuthRepository.instance.logout();
    _currentUser = null;
    notifyListeners();
  }

  void setOnlineStatus(bool online) {
    _isOnline = online;
    notifyListeners();
  }

  void setPendingSyncCount(int count) {
    _pendingSyncCount = count;
    notifyListeners();
  }

  /// Picks this language's part of an "English / हिंदी / मराठी" string.
  String pick(String combined) {
    final parts = combined.split(' / ');
    final idx = switch (_language) {
      AppLanguage.english => 0,
      AppLanguage.hindi => 1,
      AppLanguage.marathi => 2,
    };
    return parts.length > idx ? parts[idx] : parts.first;
  }

  // Helper to get text based on language
  String translate(String en, String hi, String mr) {
    switch (_language) {
      case AppLanguage.hindi:
        return hi;
      case AppLanguage.marathi:
        return mr;
      case AppLanguage.english:
        return en;
    }
  }
}
