import 'package:flutter/material.dart';
import '../../app_state.dart';
import '../../core/config/app_config.dart';
import '../../core/models/app_user.dart';
import '../../core/repositories/auth_repository.dart';
import '../../core/theme/app_theme.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Future<void> _selectRole(BuildContext context, UserRole role) async {
    // Live mode: everyone verifies their phone number. The role shown on the
    // next screen is only a hint – the real role comes from the server profile.
    if (!AppConfig.demoMode) {
      Navigator.pushNamed(context, '/login', arguments: role);
      return;
    }

    // Demo mode shortcuts.
    switch (role) {
      case UserRole.patient:
        Navigator.pushNamed(context, '/login', arguments: role);
        return;
      case UserRole.asha:
        Navigator.pushNamed(context, '/asha_pin_login');
        return;
      default:
        final user = await AuthRepository.instance.loginAsDemoRole(role);
        AppState.instance.setUser(user);
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(context, role.homeRoute, (_) => false);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final theme = Theme.of(context);

    final roles = <(UserRole, String, String, IconData, Color)>[
      (
        UserRole.patient,
        state.translate('Pregnant mother', 'गर्भवती माता', 'गर्भवती माता'),
        state.translate('Track medicines, checkups and get help', 'दवा, जांच और मदद', 'औषधे, तपासणी आणि मदत'),
        Icons.pregnant_woman_rounded,
        AppColors.accent,
      ),
      (
        UserRole.asha,
        state.translate('ASHA worker', 'आशा कार्यकर्ता', 'आशा कार्यकर्ती'),
        state.translate('Home visits and alerts', 'गृह भेंट और अलर्ट', 'गृहभेटी आणि अलर्ट'),
        Icons.volunteer_activism_rounded,
        AppColors.primary,
      ),
      (
        UserRole.anm,
        state.translate('ANM', 'एएनएम', 'एएनएम'),
        state.translate('Clinical review of escalations', 'रेफर किए गए मामलों की समीक्षा', 'पाठवलेल्या प्रकरणांचा आढावा'),
        Icons.local_hospital_rounded,
        AppColors.info,
      ),
      (
        UserRole.supervisor,
        state.translate('PHC supervisor', 'PHC पर्यवेक्षक', 'PHC पर्यवेक्षक'),
        state.translate('Area overview and reports', 'क्षेत्र अवलोकन और रिपोर्ट', 'क्षेत्र आढावा आणि अहवाल'),
        Icons.insights_rounded,
        AppColors.textPrimary,
      ),
      (
        UserRole.caregiver,
        state.translate('Family caregiver', 'परिवार देखभालकर्ता', 'कुटुंबातील काळजीवाहू'),
        state.translate('Support with reminders', 'रिमाइंडर में सहायता', 'आठवणींमध्ये मदत'),
        Icons.family_restroom_rounded,
        AppColors.success,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushReplacementNamed(context, '/language'),
            icon: const Icon(Icons.translate_rounded, size: 18),
            label: Text(state.translate('Language', 'भाषा', 'भाषा')),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.accentContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(Icons.favorite_rounded, color: AppColors.accent, size: 28),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(AppConfig.appName, style: theme.textTheme.headlineMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              state.translate('Who is using the app?', 'ऐप कौन उपयोग कर रहा है?', 'अ‍ॅप कोण वापरत आहे?'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              state.translate('Choose your role to continue', 'जारी रखने के लिए अपनी भूमिका चुनें', 'पुढे जाण्यासाठी तुमची भूमिका निवडा'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final r in roles) ...[
              _RoleCard(
                title: r.$2,
                subtitle: r.$3,
                icon: r.$4,
                color: r.$5,
                onTap: () => _selectRole(context, r.$1),
              ),
              const SizedBox(height: AppSpacing.sm + 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
