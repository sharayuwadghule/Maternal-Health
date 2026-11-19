import '../network/supabase_service.dart';

/// Central runtime configuration.
///
/// The app has two explicit modes:
///  * **Live mode** – a real Supabase backend is configured
///    (`--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`).
///    Real phone-OTP login is enforced and demo shortcuts are hidden.
///  * **Demo mode** – no backend is configured (or `--dart-define=DEMO_MODE=true`).
///    Seeded demo accounts, on-screen demo OTPs and the judge "simulate"
///    controls are available, and the UI shows a DEMO label.
class AppConfig {
  AppConfig._();

  static const String appName = 'Janani';

  static const bool _hasDemoOverride = bool.hasEnvironment('DEMO_MODE');
  static const bool _demoOverride = bool.fromEnvironment('DEMO_MODE');

  /// True when demo shortcuts are allowed.
  static bool get demoMode =>
      _hasDemoOverride ? _demoOverride : !SupabaseService.instance.isConfigured;

  /// Country calling code used for Supabase phone auth.
  static const String phoneCountryCode = '+91';

  /// National emergency ambulance number (India).
  static const String ambulanceNumber = '108';
}
