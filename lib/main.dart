import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'modules/common/role_selection_screen.dart';
import 'modules/common/language_selection_screen.dart';
import 'modules/patient/auth/login_screen.dart';
import 'modules/patient/auth/otp_screen.dart';
import 'modules/patient/home/patient_home_screen.dart';
import 'modules/asha/auth/asha_pin_login_screen.dart';
import 'modules/asha/home/asha_home_screen.dart';
import 'modules/anm/home/anm_home_screen.dart';
import 'modules/common/consent_screen.dart';
import 'modules/supervisor/home/supervisor_dashboard_screen.dart';
import 'modules/caregiver/home/caregiver_home_screen.dart';
import 'modules/asha/incentives/incentive_tracker_screen.dart';
import 'app_state.dart';
import 'modules/patient/home/medicine_store.dart';
import 'core/database/local_db.dart';
import 'core/network/supabase_service.dart';
import 'core/repositories/patient_repository.dart';
import 'core/repositories/medicine_repository.dart';
import 'core/repositories/alert_repository.dart';
import 'core/repositories/auth_repository.dart';
import 'core/services/sync_service.dart';
import 'core/config/app_config.dart';
import 'core/models/app_user.dart';
import 'core/repositories/care_team_repository.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Local Hive Database & Outbox
  await LocalDb.init();

  // 2. Initialize Supabase Backend Service (with offline resilience)
  await SupabaseService.instance.init();

  // 3. Initialize Offline Sync Manager
  await SyncService.instance.init();

  // 4. Populate default offline caches if first boot
  await PatientRepository.instance.ensureCachePopulated();
  await MedicineRepository.instance.ensureCachePopulated();
  await AlertRepository.instance.ensureCachePopulated();

  // 5. Restore existing session if logged in
  AppState.instance.loadPreferences();

  // Demo deep link (web, demo mode only): ?demo=patient|asha|anm|supervisor|caregiver
  // opens that role's home directly – used for judge demos and screenshots.
  final demoRole = Uri.base.queryParameters['demo'];
  if (kIsWeb && AppConfig.demoMode && demoRole != null) {
    final role = UserRole.values.where((r) => r.name == demoRole).firstOrNull;
    if (role != null) {
      if (!AppState.instance.hasChosenLanguage) AppState.instance.setLanguage(AppLanguage.english);
      AppState.instance.acceptConsent();
      await AuthRepository.instance.loginAsDemoRole(role);
    }
  }

  final session = await AuthRepository.instance.loadSession();
  var initialRoute = !AppState.instance.hasChosenLanguage
      ? '/language'
      : (AppState.instance.hasAcceptedConsent ? '/selection' : '/consent');
  if (session != null) {
    AppState.instance.setUser(session);
    if (session.role.isStaff && AuthRepository.instance.hasOfflinePin && demoRole == null) {
      initialRoute = '/asha_pin_login'; // PIN lock on shared field phones
    } else {
      initialRoute = session.role.homeRoute;
    }
    if (session.role == UserRole.patient) {
      // Refresh SOS contacts in the background; cached copy works offline.
      CareTeamRepository.instance
          .refresh(PatientRepository.instance.findByProfileId(session.id));
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: AppState.instance),
        ChangeNotifierProvider.value(value: MedicineStore.instance),
        ChangeNotifierProvider.value(value: SyncService.instance),
      ],
      child: MaternalHealthApp(initialRoute: initialRoute),
    ),
  );
}

class MaternalHealthApp extends StatelessWidget {
  final String initialRoute;
  const MaternalHealthApp({super.key, this.initialRoute = '/language'});

  @override
  Widget build(BuildContext context) {
    // Rebuild only when the language changes (not on every sync heartbeat).
    return Selector<AppState, AppLanguage>(
      selector: (_, state) => state.language,
      builder: (context, _, _) => _buildApp(),
    );
  }

  Widget _buildApp() {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) => ColoredBox(
        color: const Color(0xFFF1F0F4),
        // On tablets / desktop browsers keep a phone-width column so
        // layouts don't stretch; phones are unaffected.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: DemoBanner(
              // `?clean` hides the ribbon for marketing screenshots.
              enabled: AppConfig.demoMode && !Uri.base.queryParameters.containsKey('clean'),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
      initialRoute: initialRoute,
      routes: {
        '/language': (context) => const LanguageSelectionScreen(),
        '/consent': (context) => const ConsentScreen(),
        '/selection': (context) => const RoleSelectionScreen(),
        '/login': (context) => const LoginScreen(),
        '/otp': (context) => const OtpScreen(),
        '/patient_home': (context) => const PatientHomeScreen(),
        // Legacy route: the old ID/password screen never checked credentials.
        '/asha_login': (context) => const AshaPinLoginScreen(),
        '/asha_pin_login': (context) => const AshaPinLoginScreen(),
        '/asha_home': (context) => const AshaHomeScreen(),
        '/anm_home': (context) => const AnmHomeScreen(),
        '/incentive_tracker': (context) => const IncentiveTrackerScreen(),
        '/supervisor_home': (context) => const SupervisorDashboardScreen(),
        '/caregiver_home': (context) => const CaregiverHomeScreen(),
      },
    );
  }
}
