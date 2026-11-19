import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';

enum _Status { done, due, ongoing }

class VaccineScreen extends StatelessWidget {
  const VaccineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    final items = [
      ('TT / Td – 1', state.translate('First dose · early pregnancy', 'पहली खुराक · गर्भावस्था की शुरुआत', 'पहिली मात्रा · गर्भधारणेच्या सुरुवातीला'), _Status.done, state.translate('Given', 'दी गई', 'दिली')),
      ('TT / Td – 2', state.translate('Second dose · 4 weeks after the first', 'दूसरी खुराक · पहली के 4 सप्ताह बाद', 'दुसरी मात्रा · पहिल्यानंतर ४ आठवड्यांनी'), _Status.due, state.translate('Due in 5 days', '5 दिन में', '५ दिवसांत')),
      ('IFA', state.translate('Iron & folic acid · 180 days', 'आयरन व फोलिक एसिड · 180 दिन', 'लोह व फोलिक ऍसिड · १८० दिवस'), _Status.ongoing, state.translate('Daily', 'रोज़', 'दररोज')),
      (state.translate('Calcium', 'कैल्शियम', 'कॅल्शियम'), state.translate('2 tablets daily from 4th month', 'चौथे महीने से रोज़ 2 गोली', 'चौथ्या महिन्यापासून रोज २ गोळ्या'), _Status.ongoing, state.translate('Daily', 'रोज़', 'दररोज')),
    ];
    final done = items.where((i) => i.$3 == _Status.done).length;
    const total = 2; // TT doses

    return Scaffold(
      appBar: AppBar(title: Text(state.translate('Vaccines', 'टीकाकरण', 'लसीकरण'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg - 4, AppSpacing.sm, AppSpacing.lg - 4, AppSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg - 4),
            decoration: BoxDecoration(color: AppColors.lavender, borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.translate('Tetanus protection', 'टिटनेस से सुरक्षा', 'धनुर्वातापासून संरक्षण'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      Text(
                        state.translate('$done of $total doses given. Next dose at your PHC.', '$total में से $done खुराक दी गई। अगली खुराक PHC पर।', '$total पैकी $done मात्रा दिल्या. पुढील मात्रा PHC येथे.'),
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                RingProgress(
                  value: done / total,
                  size: 88,
                  color: const Color(0xFF6B4FD8),
                  trackColor: Colors.white.withValues(alpha: 0.7),
                  center: Text('$done/$total', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionTitle(state.translate('Schedule', 'अनुसूची', 'वेळापत्रक')),
          for (final i in items) ...[
            SoftCard(
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: switch (i.$3) { _Status.done => AppColors.mint, _Status.due => AppColors.peach, _Status.ongoing => AppColors.sky },
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      switch (i.$3) { _Status.done => Icons.check_rounded, _Status.due => Icons.vaccines_rounded, _Status.ongoing => Icons.medication_rounded },
                      color: switch (i.$3) { _Status.done => AppColors.success, _Status.due => AppColors.accent, _Status.ongoing => AppColors.info },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md - 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.$1, style: theme.textTheme.titleMedium),
                        Text(i.$2, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  switch (i.$3) {
                    _Status.done => StatusPill.success(i.$4),
                    _Status.due => StatusPill.warning(i.$4),
                    _Status.ongoing => StatusPill(label: i.$4, icon: Icons.repeat_rounded, color: AppColors.info, background: AppColors.infoContainer),
                  },
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
          ],
        ],
      ),
    );
  }
}
