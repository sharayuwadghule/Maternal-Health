import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../patient/home/medicine_store.dart';
import '../../../app_state.dart';
import '../visits/log_visit_bottom_sheet.dart';
import '../../../core/models/patient_model.dart';
import '../../../core/repositories/patient_repository.dart';
import '../../../core/services/risk_engine.dart';
import '../../../core/services/closed_loop_service.dart';
import '../../../core/widgets/sync_status_badge.dart';
import '../../../core/database/local_db.dart';
import '../../../core/models/visit_model.dart';
import '../../../core/repositories/alert_repository.dart';
import '../../../core/repositories/medicine_repository.dart';
import '../../../core/repositories/visit_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';

class AshaHomeScreen extends StatefulWidget {
  const AshaHomeScreen({super.key});

  @override
  State<AshaHomeScreen> createState() => _AshaHomeScreenState();
}

class _AshaHomeScreenState extends State<AshaHomeScreen> {
  final MedicineStore _store = MedicineStore.instance;
  List<PatientModel> _patients = [];
  final Map<String, ({VisitModel? latest, VisitModel? previous})> _vitals = {};
  int _activeAlerts = 0;
  _Filter _filter = _Filter.all;
  String _query = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChange);
    _loadPatients();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChange);
    super.dispose();
  }

  void _onStoreChange() => setState(() {});

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);
    final me = AppState.instance.currentUser?.id ?? '';
    final list = await PatientRepository.instance.getPatientsForAsha(me);
    for (final p in list) {
      _vitals[p.id] = await VisitRepository.instance.getLatestVitals(p.id);
    }
    final alerts = await AlertRepository.instance.getAlertsForAsha(me);
    if (!mounted) return;
    setState(() {
      _patients = list;
      _activeAlerts = alerts.where((a) => a.status.name != 'closed').length;
      _isLoading = false;
    });
  }

  /// Patients with no recorded visit in the last 30 days.
  int get _visitsDue {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return _patients.where((p) {
      final last = _vitals[p.id]?.latest?.visitDate;
      return last == null || last.isBefore(cutoff);
    }).length;
  }

  /// The open missed-medicine alert for [patientId], if any.
  String _medicineAlertIdFor(String patientId) {
    for (final raw in LocalDb.alertsBox.values) {
      final m = Map<String, dynamic>.from(raw as Map);
      if (m['patient_id'] == patientId &&
          m['type'] == 'missed_dose_3_days' &&
          m['status'] != 'closed') {
        return m['id'].toString();
      }
    }
    return AlertRepository.demoMedicineAlertId;
  }

  Future<void> _callPatient(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _escalateToAnm(AppState state, PatientModel patient) async {
    await ClosedLoopService.instance.ashaEscalateAlert(
      alertId: _medicineAlertIdFor(patient.id),
      anmId: patient.assignedAnmId,
      notes: '${patient.name} has missed iron/calcium for 4 consecutive days. Immediate clinical visit required.',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.translate(
            'Alert escalated to the ANM.',
            'अलर्ट एएनएम को भेजा गया।',
            'अलर्ट एएनएमकडे पाठवला.',
          )),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final store = context.watch<MedicineStore>();
    final medicineAlert = store.ashaAlertActive;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPatients,
              child: _buildBody(context, state, medicineAlert),
            ),
    );
  }

  Widget _buildBody(BuildContext context, AppState state, bool medicineAlert) {
    final evaluated = _patients.map((p) {
      // Medicine logs on this device belong to the demo mother.
      final isDemoPatient = p.id == MedicineRepository.demoPatientId;
      final hasMedicineAlert = isDemoPatient && medicineAlert;
      final latest = _vitals[p.id]?.latest;
      final previous = _vitals[p.id]?.previous;

      final risk = RiskEngine.evaluate(
        age: p.age,
        systolic: latest?.systolic,
        diastolic: latest?.diastolic,
        previousSystolic: previous?.systolic,
        hemoglobin: latest?.hemoglobin,
        previousHemoglobin: previous?.hemoglobin,
        dangerSigns: latest?.dangerSigns ?? const [],
        isTwin: p.isTwin,
        hasDiabetes: p.hasDiabetes || p.hasGestationalDiabetes,
        pphHistory: p.pphHistory,
        previousCSection: p.previousCSection,
        stillbirthHistory: p.stillbirthHistory,
        pregnancyLossHistory: p.pregnancyLossHistory,
        isRhNegative: p.rhNegative,
        consecutiveMissedMedsDays: hasMedicineAlert ? 4 : 0,
      );
      final reasons = switch (state.language) {
        AppLanguage.hindi => risk.reasonsHi,
        AppLanguage.marathi => risk.reasonsMr,
        AppLanguage.english => risk.reasonsEn,
      };
      final isHigh = risk.level == RiskLevel.high || hasMedicineAlert || p.isConfirmedHrp;
      return (patient: p, risk: risk, reasons: reasons, isHigh: isHigh, hasMedicineAlert: hasMedicineAlert, lastVisit: latest?.visitDate);
    }).toList();

    evaluated.sort((a, b) {
      if (a.hasMedicineAlert != b.hasMedicineAlert) return a.hasMedicineAlert ? -1 : 1;
      if (a.isHigh != b.isHigh) return a.isHigh ? -1 : 1;
      return b.risk.level.index.compareTo(a.risk.level.index);
    });

    final shown = switch (_filter) {
      _Filter.highRisk => evaluated.where((e) => e.isHigh).toList(),
      _Filter.visitDue => evaluated.where((e) =>
          e.lastVisit == null || e.lastVisit!.isBefore(DateTime.now().subtract(const Duration(days: 30)))).toList(),
      _Filter.all => evaluated,
    };
    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty ? shown : shown.where((e) => e.patient.name.toLowerCase().contains(q)).toList();
    final highCount = evaluated.where((e) => e.isHigh).length;
    final demoPatient = _patients.where((p) => p.id == MedicineRepository.demoPatientId).firstOrNull;

    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg - 4, AppSpacing.md, AppSpacing.lg - 4, AppSpacing.xl),
        children: [
          _buildHeader(state),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: Text(state.translate('Overview', 'सारांश', 'आढावा'), style: Theme.of(context).textTheme.headlineSmall)),
              const SyncStatusBadge(),
            ],
          ),
          const SizedBox(height: AppSpacing.md - 4),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Fixed height keeps tiles compact on any screen width.
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.sm + 2,
              crossAxisSpacing: AppSpacing.sm + 2,
              mainAxisExtent: 84,
            ),
            children: [
              StatTile(value: evaluated.length, label: state.translate('My mothers', 'मेरी माताएं', 'माझ्या माता'), color: AppColors.lavender, accent: const Color(0xFF6B4FD8), icon: Icons.people_alt_rounded, onTap: () => setState(() => _filter = _Filter.all)),
              StatTile(value: highCount, label: state.translate('High risk', 'उच्च जोखिम', 'उच्च धोका'), color: AppColors.blush, accent: AppColors.danger, icon: Icons.warning_rounded, onTap: () => setState(() => _filter = _Filter.highRisk)),
              StatTile(value: _activeAlerts, label: state.translate('Open alerts', 'खुले अलर्ट', 'उघडे अलर्ट'), color: AppColors.peach, accent: AppColors.accent, icon: Icons.notifications_active_rounded),
              StatTile(value: _visitsDue, label: state.translate('Visits due', 'विजिट बाकी', 'भेटी बाकी'), color: AppColors.mint, accent: AppColors.success, icon: Icons.event_note_rounded, onTap: () => setState(() => _filter = _Filter.visitDue)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (medicineAlert && demoPatient != null) ...[
            _buildMedicineMissedAlert(state, demoPatient),
            const SizedBox(height: AppSpacing.lg),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(state.translate('Mothers', 'माताएं', 'माता'), style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  state.translate('${evaluated.length} assigned', '${evaluated.length} सौंपी गईं', '${evaluated.length} नियुक्त'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md - 4),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: state.translate('Search mothers...', 'माता खोजें...', 'माता शोधा...'),
            ),
          ),
          const SizedBox(height: AppSpacing.md - 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(state.translate('All', 'सभी', 'सर्व'), _Filter.all),
                _chip(state.translate('High risk', 'उच्च जोखिम', 'उच्च धोका'), _Filter.highRisk),
                _chip(state.translate('Visit due', 'विजिट बाकी', 'भेट बाकी'), _Filter.visitDue),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (visible.isEmpty)
            SoftCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  const Icon(Icons.people_outline_rounded, size: 40, color: AppColors.textSecondary),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    state.translate('No mothers in this list.', 'इस सूची में कोई माता नहीं।', 'या यादीत कोणतीही माता नाही.'),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          for (final e in visible) ...[
            _PatientCard(
              patient: e.patient,
              level: e.risk.level,
              isHigh: e.isHigh,
              reasons: e.reasons,
              hasMedicineAlert: e.hasMedicineAlert,
              lastVisit: e.lastVisit,
              state: state,
              onCall: () => _callPatient(e.patient.phone),
              onVisit: () => LogVisitBottomSheet.show(context, patientId: e.patient.id, patientName: e.patient.name),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
          ],
          SoftCard(
            onTap: () => Navigator.pushNamed(context, '/incentive_tracker'),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: AppColors.butter, borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: const Icon(Icons.workspace_premium_rounded, color: AppColors.cocoa),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.translate('Incentives this month', 'इस महीने का प्रोत्साहन', 'या महिन्याचे प्रोत्साहन'), style: Theme.of(context).textTheme.titleMedium),
                      Text(state.translate('JSY / PMSMA tracking', 'JSY / PMSMA ट्रैकिंग', 'JSY / PMSMA ट्रॅकिंग'), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, _Filter f) {
    final selected = _filter == f;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.muted,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) => setState(() => _filter = f),
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
            decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
            child: InitialsAvatar(user?.name ?? '', size: 52, color: AppColors.success),
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.translate('Welcome', 'स्वागत है', 'स्वागत आहे'), style: Theme.of(context).textTheme.bodyMedium),
              Text(user?.name ?? '', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
            ],
          ),
        ),
        Badge(
          isLabelVisible: _activeAlerts > 0,
          label: Text('$_activeAlerts'),
          backgroundColor: AppColors.accent,
          child: Material(
            color: AppColors.surface,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: state.translate('Account', 'खाता', 'खाते'),
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () => _showAccountMenu(state),
            ),
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
            ListTile(leading: const Icon(Icons.translate_rounded), title: const Text('English'), onTap: () => Navigator.pop(ctx, 'english')),
            ListTile(leading: const Icon(Icons.translate_rounded), title: const Text('हिंदी'), onTap: () => Navigator.pop(ctx, 'hindi')),
            ListTile(leading: const Icon(Icons.translate_rounded), title: const Text('मराठी'), onTap: () => Navigator.pop(ctx, 'marathi')),
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

  Widget _buildMedicineMissedAlert(AppState state, PatientModel patient) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_rounded, color: AppColors.danger),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  state.translate('Missed medicine alert', 'दवा छूटी अलर्ट', 'औषध चुकल्याचा अलर्ट'),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger, fontSize: 16),
                ),
              ),
              StatusPill.danger(state.translate('URGENT', 'तत्काल', 'तातडीचे')),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            state.translate(
              '${patient.name} has missed iron & calcium for 4 days in a row. Call or visit today, or escalate to the ANM.',
              '${patient.name} ने लगातार 4 दिन आयरन और कैल्शियम नहीं लिया। आज कॉल या विजिट करें, या एएनएम को भेजें।',
              '${patient.name} यांनी सलग ४ दिवस लोह व कॅल्शियम घेतले नाही. आज कॉल किंवा भेट द्या, किंवा एएनएमकडे पाठवा.',
            ),
            style: const TextStyle(color: AppColors.textPrimary, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callPatient(patient.phone),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: Text(state.translate('Call', 'कॉल', 'कॉल')),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                  onPressed: () => _escalateToAnm(state, patient),
                  icon: const Icon(Icons.north_east_rounded, size: 18),
                  label: Text(state.translate('Escalate', 'एएनएम को भेजें', 'पाठवा')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _Filter { all, highRisk, visitDue }

class _PatientCard extends StatelessWidget {
  final PatientModel patient;
  final RiskLevel level;
  final bool isHigh;
  final List<String> reasons;
  final bool hasMedicineAlert;
  final DateTime? lastVisit;
  final AppState state;
  final VoidCallback onCall;
  final VoidCallback onVisit;

  const _PatientCard({
    required this.patient,
    required this.level,
    required this.isHigh,
    required this.reasons,
    required this.hasMedicineAlert,
    required this.lastVisit,
    required this.state,
    required this.onCall,
    required this.onVisit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color color, Color tint, StatusPill pill) = isHigh
        ? (AppColors.danger, AppColors.blush, StatusPill.danger(state.translate('High risk', 'उच्च जोखिम', 'उच्च धोका')))
        : level == RiskLevel.moderate
            ? (AppColors.warning, AppColors.peach, StatusPill.warning(state.translate('Moderate', 'मध्यम', 'मध्यम')))
            : (AppColors.success, AppColors.mint, StatusPill.success(state.translate('Stable', 'सामान्य', 'स्थिर')));
    final visitText = lastVisit == null
        ? state.translate('No visit yet', 'कोई विजिट नहीं', 'अद्याप भेट नाही')
        : state.translate(
            'Visited ${DateTime.now().difference(lastVisit!).inDays}d ago',
            '${DateTime.now().difference(lastVisit!).inDays} दिन पहले विजिट',
            '${DateTime.now().difference(lastVisit!).inDays} दिवसांपूर्वी भेट',
          );

    return SoftCard(
      onTap: onVisit,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                child: InitialsAvatar(patient.name, size: 46, color: color),
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
              Text(
                '${state.translate('Wk', 'स', 'आ')} ${patient.gestationalWeeks}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
              ),
            ],
          ),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            Padding(
              padding: const EdgeInsets.only(left: 58),
              child: Text(
                reasons.take(3).join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: isHigh ? AppColors.danger : AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm + 4),
          const Padding(padding: EdgeInsets.only(left: 58), child: DashedDivider()),
          const SizedBox(height: AppSpacing.sm + 2),
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Row(
              children: [
                pill,
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(visitText, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                _RoundAction(icon: Icons.call_rounded, tooltip: state.translate('Call', 'कॉल', 'कॉल'), onTap: onCall),
                const SizedBox(width: 6),
                _RoundAction(icon: Icons.edit_note_rounded, tooltip: state.translate('Log visit', 'विजिट दर्ज', 'भेट नोंदवा'), onTap: onVisit, filled: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;
  const _RoundAction({required this.icon, required this.tooltip, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? AppColors.primary : AppColors.muted,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: filled ? Colors.white : AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
