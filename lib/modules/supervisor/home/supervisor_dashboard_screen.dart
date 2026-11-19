import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_state.dart';
import '../../../core/database/local_db.dart';
import '../../../core/models/patient_model.dart';
import '../../../core/repositories/patient_repository.dart';
import '../../../core/services/closed_loop_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/account_sheet.dart';
import '../../../core/widgets/sync_status_badge.dart';
import '../../../core/widgets/ui_kit.dart';

/// PHC supervisor overview: live counts from the device's data.
class SupervisorDashboardScreen extends StatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  State<SupervisorDashboardScreen> createState() => _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState extends State<SupervisorDashboardScreen> {
  List<PatientModel> _patients = [];
  int _openAlerts = 0;
  int _visitsThisMonth = 0;
  bool _isLoading = true;

  // Names of seeded ASHA workers (live mode reads these from profiles).
  static const Map<String, String> _ashaNames = {
    '22222222-2222-2222-2222-222222222241': 'Savita Tai',
    '22222222-2222-2222-2222-222222222242': 'Mangala Kadam',
    '22222222-2222-2222-2222-222222222243': 'Pushpa Pawar',
    '22222222-2222-2222-2222-222222222244': 'Usha Jadhav',
  };

  @override
  void initState() {
    super.initState();
    _loadStats();
    ClosedLoopService.instance.addListener(_loadStats);
  }

  @override
  void dispose() {
    ClosedLoopService.instance.removeListener(_loadStats);
    super.dispose();
  }

  Future<void> _loadStats() async {
    final list = await PatientRepository.instance.getAllPatients();
    final now = DateTime.now();
    final alerts = LocalDb.alertsBox.values.where((e) => (e as Map)['status'] != 'closed').length;
    final visits = LocalDb.visitsBox.values.where((e) {
      final d = DateTime.tryParse((e as Map)['visit_date']?.toString() ?? '');
      return d != null && d.year == now.year && d.month == now.month;
    }).length;
    if (!mounted) return;
    setState(() {
      _patients = list;
      _openAlerts = alerts;
      _visitsThisMonth = visits;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final hrp = _patients.where((p) => p.isConfirmedHrp).toList();

    final byAsha = <String, List<PatientModel>>{};
    for (final p in _patients) {
      byAsha.putIfAbsent(p.assignedAshaId ?? '', () => []).add(p);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(state.translate('PHC overview', 'PHC सारांश', 'PHC आढावा')),
        actions: const [SyncStatusBadge(), SizedBox(width: 6), AccountButton()],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg - 4, AppSpacing.sm, AppSpacing.lg - 4, AppSpacing.lg),
                children: [
                  Text(state.translate('Hello, ${state.currentUser?.name ?? ''}', 'नमस्ते, ${state.currentUser?.name ?? ''}', 'नमस्कार, ${state.currentUser?.name ?? ''}'),
                      style: theme.textTheme.headlineSmall),
                  Text(state.translate('Here is your area today', 'आज आपके क्षेत्र की स्थिति', 'आज तुमच्या क्षेत्राची स्थिती'), style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.md),
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.sm + 2,
                      crossAxisSpacing: AppSpacing.sm + 2,
                      mainAxisExtent: 84,
                    ),
                    children: [
                      StatTile(value: _patients.length, label: state.translate('Active pregnancies', 'सक्रिय गर्भावस्था', 'सक्रिय गर्भधारणा'), color: AppColors.sky, accent: AppColors.info, icon: Icons.pregnant_woman_rounded),
                      StatTile(value: hrp.length, label: state.translate('Confirmed HRP', 'पुष्ट HRP', 'निश्चित HRP'), color: AppColors.blush, accent: AppColors.danger, icon: Icons.shield_rounded),
                      StatTile(value: _openAlerts, label: state.translate('Open alerts', 'खुले अलर्ट', 'उघडे अलर्ट'), color: AppColors.peach, accent: AppColors.accent, icon: Icons.notifications_active_rounded),
                      StatTile(value: _visitsThisMonth, label: state.translate('Visits this month', 'इस माह विजिट', 'या महिन्यातील भेटी'), color: AppColors.mint, accent: AppColors.success, icon: Icons.event_available_rounded),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SectionTitle(state.translate('ASHA workload', 'आशा कार्यभार', 'आशा कार्यभार')),
                  for (final entry in byAsha.entries) ...[
                    SoftCard(
                      child: Row(
                        children: [
                          Container(
                            decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
                            child: InitialsAvatar(_ashaNames[entry.key] ?? 'ASHA', size: 46, color: AppColors.success),
                          ),
                          const SizedBox(width: AppSpacing.sm + 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_ashaNames[entry.key] ?? state.translate('Unassigned', 'असाइन नहीं', 'नियुक्त नाही'), style: theme.textTheme.titleMedium),
                                Text(
                                  state.translate('${entry.value.length} mothers', '${entry.value.length} माताएं', '${entry.value.length} माता'),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (entry.value.any((p) => p.isConfirmedHrp))
                            StatusPill.danger(state.translate(
                              '${entry.value.where((p) => p.isConfirmedHrp).length} HRP',
                              '${entry.value.where((p) => p.isConfirmedHrp).length} HRP',
                              '${entry.value.where((p) => p.isConfirmedHrp).length} HRP',
                            ))
                          else
                            StatusPill.success(state.translate('Stable', 'सामान्य', 'स्थिर')),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm + 4),
                  ],
                  const SizedBox(height: AppSpacing.md - 4),
                  SectionTitle(state.translate('High-risk registry', 'उच्च जोखिम रजिस्टर', 'उच्च धोका नोंदवही')),
                  if (hrp.isEmpty)
                    SoftCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: Text(state.translate('No confirmed high-risk mothers.', 'कोई पुष्ट उच्च जोखिम माता नहीं।', 'निश्चित उच्च धोका माता नाहीत.'))),
                    ),
                  for (final p in hrp) ...[
                    SoftCard(
                      child: Row(
                        children: [
                          Container(
                            decoration: const BoxDecoration(color: AppColors.blush, shape: BoxShape.circle),
                            child: InitialsAvatar(p.name, size: 46, color: AppColors.danger),
                          ),
                          const SizedBox(width: AppSpacing.sm + 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(p.hrpCategory ?? '', style: const TextStyle(fontSize: 12.5, color: AppColors.danger), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text('${state.translate('Wk', 'स', 'आ')} ${p.gestationalWeeks}', style: theme.textTheme.titleSmall),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm + 4),
                  ],
                ],
              ),
            ),
    );
  }
}
