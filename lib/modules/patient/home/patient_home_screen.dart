import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'diet_plan_screen.dart';
import 'vaccine_screen.dart';
import 'medicine_screen.dart';
import 'medicine_store.dart';
import 'patient_history_screen.dart';
import 'patient_profile_screen.dart';
import 'chatbot_widget.dart';
import 'nearest_clinic_screen.dart';
import '../../../app_state.dart';
import '../emergency/sos_bottom_sheet.dart';
import 'symptom_logger_sheet.dart';
import '../../../core/widgets/sync_status_badge.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/patient_model.dart';
import '../../../core/repositories/care_team_repository.dart';
import '../../../core/repositories/patient_repository.dart';
import '../../../core/theme/app_theme.dart';

/// Localised calendar labels used across the patient screens.
class CalendarText {
  CalendarText._();

  static const _weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _weekdaysHi = ['सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि', 'रवि'];
  static const _weekdaysMr = ['सोम', 'मंगळ', 'बुध', 'गुरु', 'शुक्र', 'शनि', 'रवि'];
  static const _fullDaysEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _fullDaysHi = ['सोमवार', 'मंगलवार', 'बुधवार', 'गुरुवार', 'शुक्रवार', 'शनिवार', 'रविवार'];
  static const _fullDaysMr = ['सोमवार', 'मंगळवार', 'बुधवार', 'गुरुवार', 'शुक्रवार', 'शनिवार', 'रविवार'];
  static const _monthsEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  static const _monthsHi = ['जनवरी', 'फ़रवरी', 'मार्च', 'अप्रैल', 'मई', 'जून', 'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर'];
  static const _monthsMr = ['जानेवारी', 'फेब्रुवारी', 'मार्च', 'एप्रिल', 'मे', 'जून', 'जुलै', 'ऑगस्ट', 'सप्टेंबर', 'ऑक्टोबर', 'नोव्हेंबर', 'डिसेंबर'];

  static List<String> weekdays(AppLanguage l) =>
      switch (l) { AppLanguage.hindi => _weekdaysHi, AppLanguage.marathi => _weekdaysMr, AppLanguage.english => _weekdaysEn };

  static String month(AppLanguage l, int m) =>
      switch (l) { AppLanguage.hindi => _monthsHi, AppLanguage.marathi => _monthsMr, AppLanguage.english => _monthsEn }[m - 1];

  static String fullDate(AppLanguage l, DateTime d) {
    final day = switch (l) { AppLanguage.hindi => _fullDaysHi, AppLanguage.marathi => _fullDaysMr, AppLanguage.english => _fullDaysEn }[d.weekday - 1];
    return '$day, ${d.day} ${month(l, d.month)} ${d.year}';
  }

  static String shortDate(AppLanguage l, DateTime d) => '${d.day} ${month(l, d.month)} ${d.year}';
}

/// Mother's app shell: Home · Medicines · Records · Profile, with an SOS button.
class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  int _tab = 0;
  final Set<int> _visited = {0};

  void _openTab(int i) => setState(() {
        _tab = i;
        _visited.add(i);
      });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Tabs are built on first visit (e.g. the medicine reminder dialog
    // should only appear when the mother opens the Medicines tab).
    final builders = <Widget Function()>[
      () => _HomeTab(onOpenTab: _openTab),
      () => const MedicineScreen(),
      () => const PatientHistoryScreen(),
      () => const PatientProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          for (var i = 0; i < builders.length; i++)
            _visited.contains(i) ? builders[i]() : const SizedBox.shrink(),
        ],
      ),
      floatingActionButton: _tab == 0 ? const ChatbotWidget() : null,
      bottomNavigationBar: PillNavBar(
        index: _tab,
        onChanged: _openTab,
        items: [
          (Icons.home_outlined, Icons.home_rounded, state.translate('Home', 'होम', 'होम')),
          (Icons.medication_outlined, Icons.medication_rounded, state.translate('Medicines', 'दवाइयाँ', 'औषधे')),
          (Icons.folder_shared_outlined, Icons.folder_shared_rounded, state.translate('Records', 'रिकॉर्ड', 'नोंदी')),
          (Icons.person_outline_rounded, Icons.person_rounded, state.translate('Profile', 'प्रोफ़ाइल', 'प्रोफाइल')),
        ],
        action: Tooltip(
          message: state.translate('Emergency SOS', 'आपातकालीन SOS', 'तातडीचे SOS'),
          child: Material(
            color: AppColors.danger,
            shape: const CircleBorder(),
            elevation: 6,
            shadowColor: AppColors.danger.withValues(alpha: 0.4),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => SosBottomSheet.show(context),
              child: const SizedBox(
                width: 62,
                height: 62,
                child: Center(
                  child: Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final ValueChanged<int> onOpenTab;
  const _HomeTab({required this.onOpenTab});

  void _push(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final store = context.watch<MedicineStore>();
    final theme = Theme.of(context);
    final user = state.currentUser;
    final patient = PatientRepository.instance.findByProfileId(user?.id);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final team = CareTeamRepository.instance.cached();
    final firstName = (user?.name ?? '').split(' ').first;

    final greeting = now.hour < 12
        ? state.translate('Morning', 'सुप्रभात', 'सुप्रभात')
        : now.hour < 17
            ? state.translate('Good afternoon', 'नमस्ते', 'नमस्कार')
            : state.translate('Good evening', 'शुभ संध्या', 'शुभ संध्याकाळ');

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg - 4, AppSpacing.md, AppSpacing.lg - 4, 96),
        children: [
          // ── Greeting ────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$greeting, $firstName',
                        style: theme.textTheme.headlineMedium?.copyWith(fontSize: 28, height: 1.15)),
                    const SizedBox(height: 4),
                    Text(CalendarText.fullDate(state.language, now), style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => onOpenTab(3),
                child: Container(
                  decoration: const BoxDecoration(color: AppColors.butter, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(3),
                  child: InitialsAvatar(user?.name ?? '', size: 52, color: AppColors.cocoa),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Align(alignment: Alignment.centerLeft, child: SyncStatusBadge()),
          const SizedBox(height: AppSpacing.md),

          // ── Week strip (dots = medicines taken / missed) ───────────
          WeekStrip(
            today: today,
            weekdayLabels: CalendarText.weekdays(state.language),
            onTap: () => onOpenTab(1),
            dotColor: (day) {
              if (day.isAfter(today)) return null;
              if (store.isAllTaken(day)) return AppColors.success;
              return day.isBefore(today) ? AppColors.danger : null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Pregnancy hero card (ring) ─────────────────────────────
          if (patient != null) _PregnancyHero(patient: patient, state: state),
          const SizedBox(height: AppSpacing.md),

          // ── Checkup reminder (peach card) ──────────────────────────
          _CheckupCard(state: state, onDirections: () => _push(context, const NearestClinicScreen())),
          const SizedBox(height: AppSpacing.lg),

          // ── Today's medicines (routine checklist) ──────────────────
          SectionTitle(
            state.translate("Today's medicines", 'आज की दवाइयाँ', 'आजची औषधे'),
            action: state.translate('See all', 'सभी देखें', 'सर्व पहा'),
            onAction: () => onOpenTab(1),
          ),
          for (final (i, med) in store.assignedMedicines.indexed)
            ChecklistTile(
              name: state.translate(med.name, med.nameHi, med.nameMr),
              timing: state.pick(med.timing),
              dose: state.pick(med.dose),
              taken: store.isTaken(med.id, today),
              isLast: i == store.assignedMedicines.length - 1,
              tint: const [AppColors.peach, AppColors.mint, AppColors.lavender][i % 3],
              iconColor: const [AppColors.accent, AppColors.success, Color(0xFF7A5AF8)][i % 3],
              onTap: () => store.toggle(med.id, today),
            ),
          const SizedBox(height: AppSpacing.lg),

          // ── Quick care (pastel cards) ──────────────────────────────
          SectionTitle(state.translate('Quick care', 'त्वरित देखभाल', 'झटपट काळजी')),
          SizedBox(
            height: 156,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                _QuickCard(
                  color: AppColors.blush,
                  title: state.translate('Health check', 'स्वास्थ्य जांच', 'आरोग्य तपासणी'),
                  body: state.translate('How are you feeling today?', 'आज आप कैसा महसूस कर रही हैं?', 'आज तुम्हाला कसे वाटते?'),
                  tag: state.translate('Daily', 'रोज़', 'दररोज'),
                  tagColor: AppColors.danger,
                  icon: Icons.favorite_rounded,
                  onTap: () => SymptomLoggerSheet.show(context),
                ),
                _QuickCard(
                  color: AppColors.mint,
                  title: state.translate('Diet plan', 'भोजन योजना', 'आहार योजना'),
                  body: state.translate('What to eat this week', 'इस सप्ताह क्या खाएं', 'या आठवड्यात काय खावे'),
                  tag: state.translate('Nutrition', 'पोषण', 'पोषण'),
                  tagColor: AppColors.success,
                  icon: Icons.restaurant_rounded,
                  onTap: () => _push(context, const DietPlanScreen()),
                ),
                _QuickCard(
                  color: AppColors.lavender,
                  title: state.translate('Vaccines', 'टीके', 'लसीकरण'),
                  body: state.translate('Your TT shots schedule', 'आपके टीकों की सूची', 'तुमचे लसीकरण वेळापत्रक'),
                  tag: state.translate('Schedule', 'अनुसूची', 'वेळापत्रक'),
                  tagColor: const Color(0xFF6B4FD8),
                  icon: Icons.vaccines_rounded,
                  onTap: () => _push(context, const VaccineScreen()),
                ),
                _QuickCard(
                  color: AppColors.sky,
                  title: state.translate('Nearest clinic', 'निकटतम क्लिनिक', 'जवळचे दवाखाने'),
                  body: state.translate('PHC and hospitals near you', 'आपके पास PHC और अस्पताल', 'जवळची PHC आणि रुग्णालये'),
                  tag: state.translate('Map', 'नक्शा', 'नकाशा'),
                  tagColor: AppColors.info,
                  icon: Icons.local_hospital_rounded,
                  onTap: () => _push(context, const NearestClinicScreen()),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Care team ──────────────────────────────────────────────
          if (team.isNotEmpty) ...[
            SectionTitle(state.translate('Your care team', 'आपकी देखभाल टीम', 'तुमची काळजी टीम')),
            for (final c in team) ...[
              _CareTeamCard(contact: c, state: state),
              const SizedBox(height: AppSpacing.sm + 4),
            ],
          ],
        ],
      ),
    );
  }
}

class _PregnancyHero extends StatelessWidget {
  final PatientModel patient;
  final AppState state;
  const _PregnancyHero({required this.patient, required this.state});

  @override
  Widget build(BuildContext context) {
    final week = patient.gestationalWeeks;
    final daysLeft = patient.edd.difference(DateTime.now()).inDays.clamp(0, 400);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg - 4),
      decoration: BoxDecoration(
        color: AppColors.butter,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text(
                    state.translate('Trimester ${patient.trimester}', 'तिमाही ${patient.trimester}', 'तिमाही ${patient.trimester}'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.cocoa),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 4),
                Text(
                  state.translate("Your baby is growing", 'आपका शिशु बढ़ रहा है', 'तुमचे बाळ वाढत आहे'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.25),
                ),
                const SizedBox(height: 6),
                Text(
                  state.translate(
                    '$daysLeft days to go · Due ${CalendarText.shortDate(state.language, patient.edd)}',
                    '$daysLeft दिन बाकी · ${CalendarText.shortDate(state.language, patient.edd)}',
                    '$daysLeft दिवस बाकी · ${CalendarText.shortDate(state.language, patient.edd)}',
                  ),
                  style: const TextStyle(fontSize: 13, color: AppColors.cocoa, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          RingProgress(
            value: week / 40,
            color: AppColors.cocoa,
            trackColor: Colors.white.withValues(alpha: 0.55),
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$week', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1)),
                Text(state.translate('of 40 wks', '/ 40 सप्ताह', '/ ४० आठवडे'),
                    style: const TextStyle(fontSize: 11, color: AppColors.cocoa, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckupCard extends StatelessWidget {
  final AppState state;
  final VoidCallback onDirections;
  const _CheckupCard({required this.state, required this.onDirections});

  @override
  Widget build(BuildContext context) {
    final days = PatientModel.daysUntilPmsma(DateTime.now());
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day + days);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg - 4),
      decoration: BoxDecoration(color: AppColors.peach, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  days == 0
                      ? state.translate('Free checkup today', 'आज मुफ्त जांच', 'आज मोफत तपासणी')
                      : state.translate('Free checkup in $days days', '$days दिन में मुफ्त जांच', '$days दिवसांत मोफत तपासणी'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  state.translate(
                    'PMSMA at your PHC on ${CalendarText.shortDate(state.language, date)}. Bring your MCP card.',
                    '${CalendarText.shortDate(state.language, date)} को PHC पर PMSMA। MCP कार्ड लाएं।',
                    '${CalendarText.shortDate(state.language, date)} रोजी PHC येथे PMSMA. MCP कार्ड आणा.',
                  ),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: AppSpacing.md - 2),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.cocoa,
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: onDirections,
                  child: Text(state.translate('Find my PHC', 'मेरा PHC खोजें', 'माझे PHC शोधा')),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), shape: BoxShape.circle),
            child: const Icon(Icons.event_available_rounded, size: 44, color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final Color color;
  final String title;
  final String body;
  final String tag;
  final Color tagColor;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickCard({
    required this.color,
    required this.title,
    required this.body,
    required this.tag,
    required this.tagColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm + 4),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Container(
            width: 176,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ),
                    Icon(icon, size: 18, color: tagColor),
                  ],
                ),
                const SizedBox(height: 6),
                Text(body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text(tag, style: TextStyle(fontSize: 12, color: tagColor, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CareTeamCard extends StatelessWidget {
  final CareContact contact;
  final AppState state;
  const _CareTeamCard({required this.contact, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAsha = contact.role == UserRole.asha;
    final role = isAsha
        ? state.translate('ASHA worker', 'आशा कार्यकर्ता', 'आशा कार्यकर्ती')
        : state.translate('ANM · Nurse midwife', 'एएनएम · नर्स', 'एएनएम · परिचारिका');
    return SoftCard(
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(color: isAsha ? AppColors.mint : AppColors.sky, shape: BoxShape.circle),
            child: InitialsAvatar(contact.name, size: 50, color: isAsha ? AppColors.success : AppColors.info),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name, style: theme.textTheme.titleMedium),
                Text(role, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: state.translate('Call', 'कॉल करें', 'कॉल करा'),
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: contact.phone)),
              icon: const Icon(Icons.call_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
