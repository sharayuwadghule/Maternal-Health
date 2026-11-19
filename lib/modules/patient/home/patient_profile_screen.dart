import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_state.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/local_db.dart';
import '../../../core/repositories/patient_repository.dart';
import '../../../core/services/closed_loop_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  bool _shareWithCaregiver = LocalDb.prefsBox.get('caregiver_consent', defaultValue: true) as bool;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickLanguage(AppState state) async {
    final picked = await showModalBottomSheet<AppLanguage>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in const [
              (AppLanguage.english, 'English'),
              (AppLanguage.hindi, 'हिंदी (Hindi)'),
              (AppLanguage.marathi, 'मराठी (Marathi)'),
            ])
              ListTile(
                title: Text(o.$2),
                trailing: state.language == o.$1 ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                onTap: () => Navigator.pop(ctx, o.$1),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (picked != null) state.setLanguage(picked);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final user = state.currentUser;
    final patient = PatientRepository.instance.findByProfileId(user?.id);
    final langName = switch (state.language) {
      AppLanguage.english => 'English',
      AppLanguage.hindi => 'हिंदी',
      AppLanguage.marathi => 'मराठी',
    };

    return Scaffold(
      appBar: AppBar(title: Text(state.translate('Profile', 'प्रोफ़ाइल', 'प्रोफाइल'))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          SoftCard(
            child: Row(
              children: [
                InitialsAvatar(user?.name ?? '', size: 60, color: AppColors.accent),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? '', style: theme.textTheme.titleLarge),
                      Text('+91 ${user?.phone ?? ''}', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (patient != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SectionTitle(state.translate('Pregnancy details', 'गर्भावस्था विवरण', 'गर्भधारणा तपशील')),
            Card(
              child: Column(
                children: [
                  _InfoRow(state.translate('Last period (LMP)', 'अंतिम मासिक धर्म', 'शेवटची पाळी'), _fmt(patient.lmp)),
                  const Divider(indent: 16),
                  _InfoRow(state.translate('Expected delivery', 'संभावित प्रसव', 'संभाव्य प्रसूती'), _fmt(patient.edd)),
                  const Divider(indent: 16),
                  _InfoRow(state.translate('Blood group', 'रक्त समूह', 'रक्तगट'), patient.bloodGroup ?? '—'),
                  const Divider(indent: 16),
                  _InfoRow(state.translate('Pregnancy no.', 'गर्भावस्था क्रमांक', 'गर्भधारणा क्रमांक'), 'G${patient.gravida} P${patient.para}'),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SectionTitle(state.translate('Settings', 'सेटिंग्स', 'सेटिंग्ज')),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.translate_rounded),
                  title: Text(state.translate('Language', 'भाषा', 'भाषा')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Text(langName), const Icon(Icons.chevron_right_rounded)],
                  ),
                  onTap: () => _pickLanguage(state),
                ),
                const Divider(indent: 56),
                SwitchListTile(
                  secondary: const Icon(Icons.family_restroom_rounded),
                  title: Text(state.translate('Share with family caregiver', 'परिवार के साथ साझा करें', 'कुटुंबासोबत शेअर करा')),
                  value: _shareWithCaregiver,
                  onChanged: (v) {
                    setState(() => _shareWithCaregiver = v);
                    LocalDb.prefsBox.put('caregiver_consent', v);
                  },
                ),
              ],
            ),
          ),
          if (AppConfig.demoMode) ...[
            const SizedBox(height: AppSpacing.lg),
            SectionTitle(state.translate('Demo tools', 'डेमो टूल्स', 'डेमो साधने')),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.bolt_rounded, color: AppColors.warning),
                    title: const Text('Simulate 4 missed medicine days'),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await ClosedLoopService.instance.simulateConsecutiveMissedDays();
                      messenger.showSnackBar(const SnackBar(content: Text('Simulated 4 missed days. ASHA alert created.')));
                    },
                  ),
                  const Divider(indent: 56),
                  ListTile(
                    leading: const Icon(Icons.restart_alt_rounded),
                    title: const Text('Reset demo scenario'),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await ClosedLoopService.instance.resetDemoLoop();
                      messenger.showSnackBar(const SnackBar(content: Text('Demo scenario reset.')));
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.dangerContainer),
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () async {
              await state.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/selection', (_) => false);
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: Text(state.translate('Sign out', 'लॉग आउट', 'लॉग आउट')),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(child: Text('${AppConfig.appName} v1.0.0', style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
