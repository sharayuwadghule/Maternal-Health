import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../app_state.dart';
import '../../../core/models/alert_model.dart';
import '../../../core/models/patient_model.dart';
import '../../../core/repositories/alert_repository.dart';
import '../../../core/repositories/patient_repository.dart';
import '../../../core/repositories/visit_repository.dart';
import '../../../core/services/closed_loop_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sync_status_badge.dart';
import '../../../core/widgets/ui_kit.dart';

/// ANM clinical inbox: escalations from ASHAs, decisions, and HRP registry.
class AnmHomeScreen extends StatefulWidget {
  const AnmHomeScreen({super.key});

  @override
  State<AnmHomeScreen> createState() => _AnmHomeScreenState();
}

enum _Tab { inbox, resolved, hrp }

class _AnmHomeScreenState extends State<AnmHomeScreen> {
  List<AlertModel> _alerts = [];
  List<PatientModel> _patients = [];
  bool _isLoading = true;
  _Tab _tab = _Tab.inbox;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final me = AppState.instance.currentUser?.id;
    final all = await PatientRepository.instance.getAllPatients();
    final mine = all.where((p) => p.assignedAnmId == me).toList();
    final patients = mine.isNotEmpty ? mine : all; // supervisors / unassigned demo
    final alerts = await AlertRepository.instance
        .getAlertsForAnm(patients.map((p) => p.id).toSet());
    if (!mounted) return;
    setState(() {
      _patients = patients;
      _alerts = alerts;
      _isLoading = false;
    });
  }

  List<AlertModel> get _pending => _alerts.where((a) => a.status == AlertStatus.escalated).toList();
  List<AlertModel> get _resolved => _alerts.where((a) => a.status == AlertStatus.closed).toList();
  List<PatientModel> get _hrp => _patients.where((p) => p.isConfirmedHrp).toList();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              bottom: false,
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg - 4, AppSpacing.md, AppSpacing.lg - 4, AppSpacing.xl),
                  children: [
                    _buildHeader(state),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(child: Text(state.translate('Overview', 'सारांश', 'आढावा'), style: theme.textTheme.headlineSmall)),
                        const SyncStatusBadge(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md - 4),
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
                        StatTile(value: _pending.length, label: state.translate('Needs decision', 'निर्णय बाकी', 'निर्णय बाकी'), color: AppColors.blush, accent: AppColors.danger, icon: Icons.inbox_rounded, onTap: () => setState(() => _tab = _Tab.inbox)),
                        StatTile(value: _hrp.length, label: state.translate('Confirmed HRP', 'पुष्ट HRP', 'निश्चित HRP'), color: AppColors.lavender, accent: const Color(0xFF6B4FD8), icon: Icons.shield_rounded, onTap: () => setState(() => _tab = _Tab.hrp)),
                        StatTile(value: _resolved.length, label: state.translate('Resolved', 'निपटाए गए', 'निकाली'), color: AppColors.mint, accent: AppColors.success, icon: Icons.task_alt_rounded, onTap: () => setState(() => _tab = _Tab.resolved)),
                        StatTile(value: _patients.length, label: state.translate('Mothers', 'माताएं', 'माता'), color: AppColors.sky, accent: AppColors.info, icon: Icons.people_alt_rounded),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _chip(state.translate('Inbox (${_pending.length})', 'इनबॉक्स (${_pending.length})', 'इनबॉक्स (${_pending.length})'), _Tab.inbox),
                          _chip(state.translate('High-risk mothers', 'उच्च जोखिम माताएं', 'उच्च धोका माता'), _Tab.hrp),
                          _chip(state.translate('Resolved', 'निपटाए गए', 'निकाली'), _Tab.resolved),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ..._buildTabContent(state),
                  ],
                ),
              ),
            ),
    );
  }

  List<Widget> _buildTabContent(AppState state) {
    switch (_tab) {
      case _Tab.inbox:
        if (_pending.isEmpty) {
          return [
            _empty(
              Icons.mark_email_read_rounded,
              state.translate('All caught up', 'सब निपट गया', 'सर्व पूर्ण'),
              state.translate('No escalations waiting for your decision.', 'आपके निर्णय के लिए कोई मामला नहीं।', 'तुमच्या निर्णयासाठी कोणतेही प्रकरण नाही.'),
            ),
          ];
        }
        return [for (final a in _pending) _EscalationCard(alert: a, state: state, onConfirm: () => _handleConfirmHrp(a), onRefer: () => _handleReferToPhc(a), onClear: () => _handleClearAlert(a))];
      case _Tab.resolved:
        if (_resolved.isEmpty) {
          return [_empty(Icons.history_rounded, state.translate('Nothing resolved yet', 'अभी कुछ नहीं', 'अद्याप काही नाही'), '')];
        }
        return [for (final a in _resolved) _ResolvedCard(alert: a, state: state)];
      case _Tab.hrp:
        if (_hrp.isEmpty) {
          return [_empty(Icons.shield_outlined, state.translate('No confirmed high-risk mothers', 'कोई पुष्ट उच्च जोखिम माता नहीं', 'निश्चित उच्च धोका माता नाहीत'), '')];
        }
        return [for (final p in _hrp) _HrpCard(patient: p, state: state, onRecord: () => _showVitalsSheet(p, state))];
    }
  }

  Widget _chip(String label, _Tab t) {
    final selected = _tab == t;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.muted,
        labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
        onSelected: (_) => setState(() => _tab = t),
      ),
    );
  }

  Widget _empty(IconData icon, String title, String body) {
    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.success),
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(body, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(AppState state) {
    final user = state.currentUser;
    return Row(
      children: [
        GestureDetector(
          onTap: () => _showAccountMenu(state),
          child: Container(
            decoration: const BoxDecoration(color: AppColors.sky, shape: BoxShape.circle),
            child: InitialsAvatar(user?.name ?? '', size: 52, color: AppColors.info),
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.translate('ANM · Clinical inbox', 'एएनएम · क्लिनिकल इनबॉक्स', 'एएनएम · क्लिनिकल इनबॉक्स'), style: Theme.of(context).textTheme.bodyMedium),
              Text(user?.name ?? '', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
            ],
          ),
        ),
        Badge(
          isLabelVisible: _pending.isNotEmpty,
          label: Text('${_pending.length}'),
          backgroundColor: AppColors.danger,
          child: Material(
            color: AppColors.muted,
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () => setState(() => _tab = _Tab.inbox),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Material(
          color: AppColors.muted,
          shape: const CircleBorder(),
          child: IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: () => _showAccountMenu(state),
          ),
        ),
      ],
    );
  }

  Future<void> _showAccountMenu(AppState state) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final l in const [('english', 'English'), ('hindi', 'हिंदी'), ('marathi', 'मराठी')])
              ListTile(leading: const Icon(Icons.translate_rounded), title: Text(l.$2), onTap: () => Navigator.pop(ctx, l.$1)),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: Text(state.translate('Sign out', 'लॉग आउट', 'लॉग आउट'), style: const TextStyle(color: AppColors.danger)),
              onTap: () => Navigator.pop(ctx, 'logout'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'logout') {
      await state.logout();
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/selection', (_) => false);
    } else {
      state.setLanguage(AppLanguage.values.byName(choice));
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────

  void _toast(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleConfirmHrp(AlertModel alert) async {
    await ClosedLoopService.instance.anmConfirmHrp(
      alertId: alert.id,
      patientId: alert.patientId,
      notes: 'High-risk condition confirmed from alert: ${alert.type}',
    );
    await _loadData();
    _toast(AppState.instance.translate('High-risk pregnancy confirmed and added to the PHC registry.', 'उच्च जोखिम गर्भावस्था की पुष्टि की गई।', 'उच्च धोका गर्भधारणा निश्चित केली.'));
  }

  Future<void> _decide(AlertModel alert, String decision, String notes) async {
    final me = AppState.instance.currentUser?.id ?? '';
    await AlertRepository.instance.recordEscalationDecision(alertId: alert.id, decision: decision, decidedBy: me, notes: notes);
    await AlertRepository.instance.closeAlert(alert.id, notes, closedBy: me);
    await _loadData();
  }

  Future<void> _handleReferToPhc(AlertModel alert) async {
    await _decide(alert, 'refer_to_phc', 'Referred to PHC Medical Officer');
    _toast(AppState.instance.translate('Referred to the PHC Medical Officer.', 'PHC चिकित्सा अधिकारी को रेफर किया गया।', 'PHC वैद्यकीय अधिकाऱ्यांकडे पाठवले.'));
  }

  Future<void> _handleClearAlert(AlertModel alert) async {
    await _decide(alert, 'clear', 'Cleared after in-person clinical assessment');
    _toast(AppState.instance.translate('Alert cleared.', 'अलर्ट बंद किया गया।', 'अलर्ट बंद केला.'));
  }

  Future<void> _showVitalsSheet(PatientModel patient, AppState state) async {
    final sys = TextEditingController();
    final dia = TextEditingController();
    final hb = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(state.translate('Record vitals', 'वाइटल्स दर्ज करें', 'तपासणी नोंदवा'), style: Theme.of(ctx).textTheme.headlineSmall),
            Text(patient.name, style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: _numField(sys, state.translate('Systolic BP', 'सिस्टोलिक BP', 'सिस्टोलिक BP'), 'mmHg')),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(child: _numField(dia, state.translate('Diastolic BP', 'डायस्टोलिक BP', 'डायस्टोलिक BP'), 'mmHg')),
              ],
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            _numField(hb, state.translate('Haemoglobin', 'हीमोग्लोबिन', 'हिमोग्लोबिन'), 'g/dL', decimal: true),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(state.translate('Save vitals', 'सहेजें', 'जतन करा'))),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final me = state.currentUser;
    await VisitRepository.instance.logVisit(
      patientId: patient.id,
      recordedBy: me?.id ?? '',
      recordedByRole: me?.role.name ?? 'anm',
      visitDate: DateTime.now(),
      systolic: int.tryParse(sys.text),
      diastolic: int.tryParse(dia.text),
      hemoglobin: double.tryParse(hb.text),
      notes: 'Clinical reading recorded by ANM.',
    );
    _toast(state.translate('Vitals saved.', 'वाइटल्स सहेजे गए।', 'तपासणी जतन केली.'));
  }

  Widget _numField(TextEditingController c, String label, String unit, {bool decimal = false}) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.]' : r'[0-9]'))],
      decoration: InputDecoration(labelText: label, suffixText: unit),
    );
  }
}

class _EscalationCard extends StatelessWidget {
  final AlertModel alert;
  final AppState state;
  final VoidCallback onConfirm;
  final VoidCallback onRefer;
  final VoidCallback onClear;

  const _EscalationCard({required this.alert, required this.state, required this.onConfirm, required this.onRefer, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hours = DateTime.now().difference(alert.createdAt).inHours;
    final ago = hours < 24
        ? state.translate('${hours}h ago', '$hours घंटे पहले', '$hours तासांपूर्वी')
        : state.translate('${hours ~/ 24}d ago', '${hours ~/ 24} दिन पहले', '${hours ~/ 24} दिवसांपूर्वी');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
      child: SoftCard(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: const BoxDecoration(color: AppColors.blush, shape: BoxShape.circle),
                  child: InitialsAvatar(alert.patientName, size: 46, color: AppColors.danger),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.patientName, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(state.translate('Escalated by ASHA · $ago', 'आशा द्वारा भेजा · $ago', 'आशाने पाठवले · $ago'), style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                alert.isUrgent
                    ? StatusPill.danger(state.translate('Urgent', 'तत्काल', 'तातडीचे'))
                    : StatusPill.warning(state.translate('Review', 'समीक्षा', 'आढावा')),
              ],
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm + 4),
              decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Text(alert.message, style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary, height: 1.4)),
            ),
            const SizedBox(height: AppSpacing.md - 2),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size.fromHeight(46)),
              onPressed: onConfirm,
              icon: const Icon(Icons.shield_rounded, size: 18),
              label: Text(state.translate('Confirm high-risk (HRP)', 'HRP की पुष्टि करें', 'HRP निश्चित करा')),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    onPressed: onRefer,
                    icon: const Icon(Icons.local_hospital_rounded, size: 18),
                    label: Text(state.translate('Refer to PHC', 'PHC रेफर', 'PHC कडे')),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: AppColors.success),
                    onPressed: onClear,
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: Text(state.translate('Clear', 'बंद करें', 'बंद करा')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolvedCard extends StatelessWidget {
  final AlertModel alert;
  final AppState state;
  const _ResolvedCard({required this.alert, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
      child: SoftCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
              child: const Icon(Icons.task_alt_rounded, color: AppColors.success),
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.patientName, style: theme.textTheme.titleMedium),
                  Text(alert.resolutionNotes ?? alert.message, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HrpCard extends StatelessWidget {
  final PatientModel patient;
  final AppState state;
  final VoidCallback onRecord;
  const _HrpCard({required this.patient, required this.state, required this.onRecord});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
      child: SoftCard(
        onTap: onRecord,
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: const BoxDecoration(color: AppColors.lavender, shape: BoxShape.circle),
                  child: InitialsAvatar(patient.name, size: 46, color: const Color(0xFF6B4FD8)),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patient.name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        '${patient.age} ${state.translate('yrs', 'वर्ष', 'वर्षे')} · ${state.translate('Week', 'सप्ताह', 'आठवडा')} ${patient.gestationalWeeks}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusPill.danger('HRP'),
              ],
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            Padding(
              padding: const EdgeInsets.only(left: 58),
              child: Text(
                patient.hrpCategory ?? '',
                style: const TextStyle(fontSize: 12.5, color: AppColors.danger, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            const Padding(padding: EdgeInsets.only(left: 58), child: DashedDivider()),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: 58),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      state.translate('Tap to record BP & Hb', 'BP व Hb दर्ज करने हेतु टैप करें', 'BP व Hb नोंदवण्यासाठी टॅप करा'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const Icon(Icons.edit_note_rounded, color: AppColors.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
