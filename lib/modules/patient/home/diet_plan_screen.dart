import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_state.dart';
import '../../../core/repositories/patient_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import 'diet_data.dart';

class DietPlanScreen extends StatefulWidget {
  const DietPlanScreen({super.key});

  @override
  State<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends State<DietPlanScreen> {
  late int _month; // 1..9

  static const _meals = [
    ('Early Morning', Icons.wb_twilight_rounded, AppColors.butter, Color(0xFF8A5A00), 'Early morning', 'सुबह जल्दी', 'पहाटे'),
    ('Breakfast', Icons.free_breakfast_rounded, AppColors.peach, AppColors.accent, 'Breakfast', 'नाश्ता', 'न्याहारी'),
    ('Mid-Morning', Icons.apple_rounded, AppColors.mint, AppColors.success, 'Mid-morning', 'दोपहर से पहले', 'दुपारआधी'),
    ('Lunch', Icons.lunch_dining_rounded, AppColors.sky, AppColors.info, 'Lunch', 'दोपहर का भोजन', 'दुपारचे जेवण'),
    ('Evening Snack', Icons.cookie_rounded, AppColors.blush, AppColors.danger, 'Evening snack', 'शाम का नाश्ता', 'संध्याकाळचा नाश्ता'),
    ('Dinner', Icons.dinner_dining_rounded, AppColors.lavender, Color(0xFF6B4FD8), 'Dinner', 'रात का खाना', 'रात्रीचे जेवण'),
    ('Bedtime', Icons.bedtime_rounded, AppColors.muted, AppColors.primary, 'Bedtime', 'सोते समय', 'झोपताना'),
  ];

  @override
  void initState() {
    super.initState();
    // Open on the mother's current month of pregnancy.
    final patient = PatientRepository.instance.findByProfileId(AppState.instance.currentUser?.id);
    final weeks = patient?.gestationalWeeks ?? 4;
    _month = ((weeks / 4.35).ceil()).clamp(1, maternalDietPlans.length);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final plan = maternalDietPlans[_month - 1];
    final focus = switch (state.language) {
      AppLanguage.hindi => plan.primaryNutritionalFocusHi,
      AppLanguage.marathi => plan.primaryNutritionalFocusMr,
      AppLanguage.english => plan.primaryNutritionalFocus,
    };
    final schedule = switch (state.language) {
      AppLanguage.hindi => plan.mealScheduleHi,
      AppLanguage.marathi => plan.mealScheduleMr,
      AppLanguage.english => plan.mealSchedule,
    };

    return Scaffold(
      appBar: AppBar(title: Text(state.translate('Diet plan', 'भोजन योजना', 'आहार योजना'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, AppSpacing.lg),
        children: [
          // ── Month selector (pill chips) ──────────────────────────────
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg - 4),
              itemCount: maternalDietPlans.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) {
                final m = i + 1;
                final selected = m == _month;
                return ChoiceChip(
                  label: Text(state.translate('Month $m', 'महीना $m', 'महिना $m')),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.muted,
                  labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
                  onSelected: (_) => setState(() => _month = m),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg - 4, AppSpacing.md, AppSpacing.lg - 4, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Focus card ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg - 4),
                  decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(AppRadius.lg)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(AppRadius.pill)),
                            child: Text(
                              state.translate('Trimester ${plan.trimesterIndex}', 'तिमाही ${plan.trimesterIndex}', 'तिमाही ${plan.trimesterIndex}'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.eco_rounded, color: AppColors.success),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm + 4),
                      Text(
                        state.translate('Focus this month', 'इस महीने ध्यान दें', 'या महिन्यात लक्ष द्या'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final f in focus)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.pill)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 15, color: AppColors.success),
                                  const SizedBox(width: 6),
                                  Text(f, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SectionTitle(state.translate('Daily meals', 'दैनिक भोजन', 'दैनंदिन जेवण')),
                for (final (i, m) in _meals.indexed)
                  _MealRow(
                    title: state.translate(m.$5, m.$6, m.$7),
                    description: schedule[m.$1] ?? '',
                    icon: m.$2,
                    tint: m.$3,
                    iconColor: m.$4,
                    isLast: i == _meals.length - 1,
                    theme: theme,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final bool isLast;
  final ThemeData theme;

  const _MealRow({
    required this.title,
    required this.description,
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.isLast,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 1.2, margin: const EdgeInsets.symmetric(vertical: 4), color: AppColors.border)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md - 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md + 4, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.45)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
