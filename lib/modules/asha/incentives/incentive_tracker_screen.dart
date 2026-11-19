import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';

/// ASHA incentives (JSY / PMSMA). Figures are demo values until the
/// backend reports claim status.
class IncentiveTrackerScreen extends StatelessWidget {
  const IncentiveTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    final schemes = [
      (state.translate('ANC checkups', 'एएनसी जांच', 'एएनसी तपासणी'), 12, 15, AppColors.success, AppColors.mint, Icons.fact_check_rounded),
      (state.translate('High-risk follow-ups', 'उच्च जोखिम फॉलो-अप', 'उच्च धोका फॉलो-अप'), 4, 5, AppColors.accent, AppColors.peach, Icons.shield_rounded),
      (state.translate('Institutional deliveries', 'संस्थागत प्रसव', 'संस्थात्मक प्रसूती'), 2, 2, AppColors.info, AppColors.sky, Icons.local_hospital_rounded),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(state.translate('Incentives', 'प्रोत्साहन', 'प्रोत्साहन'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg - 4, AppSpacing.sm, AppSpacing.lg - 4, AppSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg - 4),
            decoration: BoxDecoration(color: AppColors.butter, borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.translate('This month', 'इस महीने', 'या महिन्यात'), style: const TextStyle(fontSize: 13, color: AppColors.cocoa, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('₹450', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.1)),
                Text(state.translate('Estimated incentive', 'अनुमानित प्रोत्साहन', 'अंदाजित प्रोत्साहन'), style: const TextStyle(fontSize: 13, color: AppColors.cocoa)),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _stat('15', state.translate('Visits', 'विजिट', 'भेटी')),
                    _stat('3', state.translate('HRP found', 'HRP मिले', 'HRP आढळले')),
                    _stat('2', state.translate('Deliveries', 'प्रसव', 'प्रसूती')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionTitle(state.translate('Scheme progress', 'योजना प्रगति', 'योजना प्रगती')),
          for (final s in schemes) ...[
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: s.$5, borderRadius: BorderRadius.circular(AppRadius.sm)),
                        child: Icon(s.$6, color: s.$4, size: 22),
                      ),
                      const SizedBox(width: AppSpacing.sm + 4),
                      Expanded(child: Text(s.$1, style: theme.textTheme.titleMedium)),
                      Text('${s.$2} / ${s.$3}', style: TextStyle(fontWeight: FontWeight.w700, color: s.$4)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm + 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: s.$2 / s.$3,
                      minHeight: 8,
                      backgroundColor: AppColors.muted,
                      color: s.$4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
          ],
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.cocoa)),
          ],
        ),
      ),
    );
  }
}
