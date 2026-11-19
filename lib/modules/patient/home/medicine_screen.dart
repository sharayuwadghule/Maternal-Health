import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'medicine_store.dart';
import 'patient_home_screen.dart' show CalendarText;
import '../../../core/widgets/ui_kit.dart';
import '../../../app_state.dart';

class MedicineScreen extends StatefulWidget {
  const MedicineScreen({super.key});

  @override
  State<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends State<MedicineScreen> {
  final MedicineStore _store = MedicineStore.instance;
  final DateTime _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChange);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChange);
    super.dispose();
  }

  void _onStoreChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final level = _store.alertLevel(_today);
    final meds = _store.assignedMedicines;
    final takenToday = _store.takenCount(_today);
    final allDone = _store.isAllTaken(_today);
    final weekStart = DateTime(_today.year, _today.month, _today.day - 6);

    return Scaffold(
      appBar: AppBar(title: Text(state.translate('My medicines', 'मेरी दवाइयाँ', 'माझी औषधे'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg - 4, AppSpacing.sm, AppSpacing.lg - 4, AppSpacing.lg),
        children: [
          // ── Today's progress (ring card) ────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg - 4),
            decoration: BoxDecoration(
              color: allDone ? AppColors.mint : AppColors.lavender,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allDone
                            ? state.translate('All done for today!', 'आज की सभी दवाएं ली गईं!', 'आजची सर्व औषधे घेतली!')
                            : state.translate("Today's goal", 'आज का लक्ष्य', 'आजचे ध्येय'),
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.translate(
                          '$takenToday of ${meds.length} medicines taken',
                          '${meds.length} में से $takenToday दवाएं ली गईं',
                          '${meds.length} पैकी $takenToday औषधे घेतली',
                        ),
                        style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.translate('Tap a medicine to mark it taken.', 'दवा लेने पर उस पर टैप करें।', 'औषध घेतल्यावर त्यावर टॅप करा.'),
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                RingProgress(
                  value: meds.isEmpty ? 0 : takenToday / meds.length,
                  size: 96,
                  color: allDone ? AppColors.success : const Color(0xFF6B4FD8),
                  trackColor: Colors.white.withValues(alpha: 0.7),
                  center: Text(
                    '$takenToday/${meds.length}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Missed-dose banner ─────────────────────────────────────
          if (level != MissedAlert.none) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: level == MissedAlert.ashaAlert ? AppColors.blush : AppColors.peach,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(
                    level == MissedAlert.ashaAlert ? Icons.error_rounded : Icons.notifications_active_rounded,
                    color: level == MissedAlert.ashaAlert ? AppColors.danger : AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Text(
                      level == MissedAlert.ashaAlert
                          ? state.translate(
                              'You missed medicines for several days. Your ASHA has been informed – please take them today.',
                              'आपने कई दिन दवाएं नहीं लीं। आपकी आशा को सूचित किया गया है – कृपया आज दवा लें।',
                              'तुम्ही अनेक दिवस औषधे घेतली नाहीत. तुमच्या आशाला कळवले आहे – कृपया आज औषधे घ्या.')
                          : state.translate(
                              "Don't forget your medicines today.",
                              'आज अपनी दवाएं लेना न भूलें।',
                              'आज तुमची औषधे घ्यायला विसरू नका.'),
                      style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary, height: 1.4, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // ── Today's checklist ──────────────────────────────────────
          SectionTitle(state.translate('Today', 'आज', 'आज')),
          for (final (i, med) in meds.indexed)
            ChecklistTile(
              name: state.translate(med.name, med.nameHi, med.nameMr),
              timing: state.pick(med.timing),
              dose: state.pick(med.dose),
              taken: _store.isTaken(med.id, _today),
              isLast: i == meds.length - 1,
              tint: const [AppColors.peach, AppColors.mint, AppColors.lavender][i % 3],
              iconColor: const [AppColors.accent, AppColors.success, Color(0xFF6B4FD8)][i % 3],
              onTap: () => _store.toggle(med.id, _today),
            ),
          const SizedBox(height: AppSpacing.md),

          // ── Last 7 days ────────────────────────────────────────────
          SectionTitle(state.translate('Last 7 days', 'पिछले 7 दिन', 'मागील ७ दिवस')),
          SoftCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Builder(builder: (context) {
                      final day = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
                      final isToday = i == 6;
                      final done = _store.isAllTaken(day);
                      final (Color bg, Color fg, IconData icon) = done
                          ? (AppColors.successContainer, AppColors.success, Icons.check_rounded)
                          : isToday
                              ? (AppColors.muted, AppColors.textSecondary, Icons.more_horiz_rounded)
                              : (AppColors.dangerContainer, AppColors.danger, Icons.close_rounded);
                      return Column(
                        children: [
                          Text(
                            CalendarText.weekdays(state.language)[day.weekday - 1],
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isToday ? AppColors.textPrimary : AppColors.textSecondary,
                              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                            child: Icon(icon, size: 18, color: fg),
                          ),
                          const SizedBox(height: 6),
                          Text('${day.day}', style: theme.textTheme.bodySmall),
                        ],
                      );
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
