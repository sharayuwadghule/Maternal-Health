import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app_state.dart';
import '../../../core/database/local_db.dart';
import '../../../core/models/patient_model.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/medicine_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/account_sheet.dart';
import '../../../core/widgets/sync_status_badge.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../patient/home/medicine_store.dart';
import '../../patient/home/patient_home_screen.dart' show CalendarText;

/// Family caregiver view of the linked mother (respects her sharing consent).
class CaregiverHomeScreen extends StatelessWidget {
  const CaregiverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final store = context.watch<MedicineStore>();
    final theme = Theme.of(context);
    final hasConsent = LocalDb.prefsBox.get('caregiver_consent', defaultValue: true) as bool;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final missedDays = store.consecutiveMissedDaysBefore(now);

    // Demo link: the caregiver account is linked to the demo mother.
    final PatientModel? mother = LocalDb.patientsBox.get(MedicineRepository.demoPatientId) is Map
        ? PatientModel.fromMap(Map<String, dynamic>.from(LocalDb.patientsBox.get(MedicineRepository.demoPatientId) as Map))
        : null;
    final motherName = (mother?.name ?? '').replaceAll(RegExp(r'\s*\(.*\)'), '');
    final asha = AuthRepository.demoUsers.values.where((u) => u.id == mother?.assignedAshaId).firstOrNull;
    final days = PatientModel.daysUntilPmsma(now);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.translate('Family', 'परिवार', 'कुटुंब')),
        actions: const [SyncStatusBadge(), SizedBox(width: 6), AccountButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg - 4, AppSpacing.sm, AppSpacing.lg - 4, AppSpacing.lg),
        children: [
          Text(
            state.translate('Supporting $motherName', '$motherName की देखभाल', '$motherName यांची काळजी'),
            style: theme.textTheme.headlineSmall,
          ),
          Text(state.translate('Signed in as ${state.currentUser?.name ?? ''}', '${state.currentUser?.name ?? ''} के रूप में', '${state.currentUser?.name ?? ''} म्हणून'), style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),

          if (!hasConsent)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: AppColors.peach, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: AppColors.cocoa),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Text(
                      state.translate(
                        'She has paused sharing. Only emergency contacts are shown.',
                        'उन्होंने जानकारी साझा करना रोका है। केवल आपातकालीन संपर्क दिखेंगे।',
                        'त्यांनी माहिती शेअर करणे थांबवले आहे. फक्त आपत्कालीन संपर्क दिसतील.',
                      ),
                      style: const TextStyle(color: AppColors.textPrimary, height: 1.4),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (mother != null)
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg - 4),
                decoration: BoxDecoration(color: AppColors.butter, borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(state.translate('Week ${mother.gestationalWeeks} of 40', 'सप्ताह ${mother.gestationalWeeks} / 40', 'आठवडा ${mother.gestationalWeeks} / ४०'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 6),
                          Text(
                            state.translate('Due ${CalendarText.shortDate(state.language, mother.edd)}', 'प्रसव ${CalendarText.shortDate(state.language, mother.edd)}', 'प्रसूती ${CalendarText.shortDate(state.language, mother.edd)}'),
                            style: const TextStyle(fontSize: 13, color: AppColors.cocoa),
                          ),
                        ],
                      ),
                    ),
                    RingProgress(
                      value: mother.gestationalWeeks / 40,
                      size: 80,
                      color: AppColors.cocoa,
                      trackColor: Colors.white.withValues(alpha: 0.55),
                      center: Text('${mother.gestationalWeeks}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            SectionTitle(state.translate('Medicines this week', 'इस सप्ताह दवाइयाँ', 'या आठवड्यातील औषधे')),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WeekStrip(
                    today: today,
                    weekdayLabels: CalendarText.weekdays(state.language),
                    dotColor: (day) {
                      if (day.isAfter(today)) return null;
                      if (store.isAllTaken(day)) return AppColors.success;
                      return day.isBefore(today) ? AppColors.danger : null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  missedDays >= 3
                      ? StatusPill.danger(state.translate('Missed $missedDays days – please remind her', '$missedDays दिन छूटे – कृपया याद दिलाएं', '$missedDays दिवस चुकले – कृपया आठवण करून द्या'))
                      : StatusPill.success(state.translate('Taking medicines regularly', 'नियमित दवा ले रही हैं', 'नियमित औषधे घेत आहेत')),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg - 4),
              decoration: BoxDecoration(color: AppColors.peach, borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Row(
                children: [
                  const Icon(Icons.event_available_rounded, color: AppColors.accent, size: 32),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      days == 0
                          ? state.translate('Free checkup today at the PHC. Please go with her.', 'आज PHC पर मुफ्त जांच। कृपया साथ जाएं।', 'आज PHC येथे मोफत तपासणी. कृपया सोबत जा.')
                          : state.translate('Free checkup in $days days at the PHC. Please go with her.', '$days दिन में PHC पर मुफ्त जांच। कृपया साथ जाएं।', '$days दिवसांत PHC येथे मोफत तपासणी. कृपया सोबत जा.'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SectionTitle(state.translate('Emergency contacts', 'आपातकालीन संपर्क', 'आपत्कालीन संपर्क')),
          if (asha != null) ...[
            _ContactCard(name: asha.name, role: state.translate('ASHA worker', 'आशा कार्यकर्ता', 'आशा कार्यकर्ती'), phone: asha.phone, tint: AppColors.mint, color: AppColors.success),
            const SizedBox(height: AppSpacing.sm + 4),
          ],
          _ContactCard(name: state.translate('Ambulance', 'एम्बुलेंस', 'रुग्णवाहिका'), role: '108', phone: '108', tint: AppColors.blush, color: AppColors.danger),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final String name;
  final String role;
  final String phone;
  final Color tint;
  final Color color;
  const _ContactCard({required this.name, required this.role, required this.phone, required this.tint, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: InitialsAvatar(name, size: 46, color: color),
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.titleMedium),
                Text(role, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
              icon: const Icon(Icons.call_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
