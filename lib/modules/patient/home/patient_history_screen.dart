import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_state.dart';
import '../../../core/models/patient_model.dart';
import '../../../core/models/visit_model.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/patient_repository.dart';
import '../../../core/repositories/visit_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import 'patient_home_screen.dart' show CalendarText;

/// The mother's health records: profile summary, latest vitals and the
/// real visit history recorded by her ASHA / ANM.
class PatientHistoryScreen extends StatefulWidget {
  const PatientHistoryScreen({super.key});

  @override
  State<PatientHistoryScreen> createState() => _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends State<PatientHistoryScreen> {
  PatientModel? _patient;
  List<VisitModel> _visits = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final patient = PatientRepository.instance.findByProfileId(AppState.instance.currentUser?.id);
    final visits = patient == null ? <VisitModel>[] : await VisitRepository.instance.getVisitsForPatient(patient.id);
    if (!mounted) return;
    setState(() {
      _patient = patient;
      _visits = visits;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final patient = _patient;
    final latest = _visits.where((v) => v.systolic != null || v.hemoglobin != null || v.weightKg != null).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(state.translate('My records', 'मेरे रिकॉर्ड', 'माझ्या नोंदी'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg - 4, AppSpacing.sm, AppSpacing.lg - 4, AppSpacing.lg),
                children: [
                  if (patient != null) _ProfileCard(patient: patient, state: state),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Latest vitals ───────────────────────────────────
                  SectionTitle(state.translate('Latest vitals', 'नवीनतम जांच', 'नवीनतम तपासणी')),
                  Row(
                    children: [
                      Expanded(child: _VitalTile(
                        label: state.translate('Blood pressure', 'रक्तचाप', 'रक्तदाब'),
                        value: latest?.systolic != null ? '${latest!.systolic}/${latest.diastolic ?? '–'}' : '–',
                        unit: 'mmHg',
                        color: AppColors.lavender,
                        warn: (latest?.systolic ?? 0) >= 140 || (latest?.diastolic ?? 0) >= 90,
                      )),
                      const SizedBox(width: AppSpacing.sm + 2),
                      Expanded(child: _VitalTile(
                        label: state.translate('Haemoglobin', 'हीमोग्लोबिन', 'हिमोग्लोबिन'),
                        value: latest?.hemoglobin?.toStringAsFixed(1) ?? '–',
                        unit: 'g/dL',
                        color: AppColors.blush,
                        warn: latest?.hemoglobin != null && latest!.hemoglobin! < 11,
                      )),
                      const SizedBox(width: AppSpacing.sm + 2),
                      Expanded(child: _VitalTile(
                        label: state.translate('Weight', 'वज़न', 'वजन'),
                        value: latest?.weightKg?.toStringAsFixed(1) ?? '–',
                        unit: 'kg',
                        color: AppColors.mint,
                      )),
                    ],
                  ),
                  if (latest != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      state.translate(
                        'Recorded on ${CalendarText.shortDate(state.language, latest.visitDate)}',
                        '${CalendarText.shortDate(state.language, latest.visitDate)} को दर्ज',
                        '${CalendarText.shortDate(state.language, latest.visitDate)} रोजी नोंद',
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),

                  // ── Visit history ───────────────────────────────────
                  SectionTitle(state.translate('Visit history', 'विजिट इतिहास', 'भेटींचा इतिहास')),
                  if (_visits.isEmpty)
                    SoftCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(color: AppColors.sky, shape: BoxShape.circle),
                            child: const Icon(Icons.event_note_rounded, color: AppColors.info),
                          ),
                          const SizedBox(height: AppSpacing.sm + 4),
                          Text(state.translate('No visits recorded yet', 'अभी कोई विजिट दर्ज नहीं', 'अद्याप भेट नोंदलेली नाही'), style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            state.translate('Your ASHA will record your checkups here.', 'आपकी आशा यहाँ जांच दर्ज करेगी।', 'तुमची आशा येथे तपासणी नोंदवेल.'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  for (final (i, v) in _visits.indexed)
                    _VisitTile(visit: v, state: state, isLast: i == _visits.length - 1),
                ],
              ),
            ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final PatientModel patient;
  final AppState state;
  const _ProfileCard({required this.patient, required this.state});

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(AppRadius.pill)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.cocoa),
              const SizedBox(width: 4),
              Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.cocoa)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg - 4),
      decoration: BoxDecoration(color: AppColors.peach, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: InitialsAvatar(patient.name, size: 56, color: AppColors.accent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.name.replaceAll(RegExp(r'\s*\(.*\)'), ''),
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text(
                      state.translate(
                        'Week ${patient.gestationalWeeks} · Trimester ${patient.trimester}',
                        'सप्ताह ${patient.gestationalWeeks} · तिमाही ${patient.trimester}',
                        'आठवडा ${patient.gestationalWeeks} · तिमाही ${patient.trimester}',
                      ),
                      style: const TextStyle(fontSize: 13, color: AppColors.cocoa),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (patient.bloodGroup != null) chip(Icons.bloodtype_rounded, patient.bloodGroup!),
              chip(Icons.child_friendly_rounded, 'G${patient.gravida} P${patient.para}'),
              chip(Icons.event_rounded, '${state.translate('Due', 'प्रसव', 'प्रसूती')} ${CalendarText.shortDate(state.language, patient.edd)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _VitalTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final bool warn;
  const _VitalTile({required this.label, required this.value, required this.unit, required this.color, this.warn = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.sm + 4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              ),
              if (warn) const Icon(Icons.error_rounded, size: 14, color: AppColors.danger),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: warn ? AppColors.danger : AppColors.textPrimary)),
          ),
          Text(unit, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _VisitTile extends StatelessWidget {
  final VisitModel visit;
  final AppState state;
  final bool isLast;
  const _VisitTile({required this.visit, required this.state, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byAnm = visit.recordedByRole == 'anm';
    final recorder = AuthRepository.demoUsers.values.where((u) => u.id == visit.recordedBy).firstOrNull?.name;
    final title = byAnm
        ? state.translate('ANM checkup', 'एएनएम जांच', 'एएनएम तपासणी')
        : state.translate('ASHA home visit', 'आशा गृह भेंट', 'आशा गृहभेट');
    final d = visit.visitDate;

    final chips = <String>[
      if (visit.systolic != null) 'BP ${visit.systolic}/${visit.diastolic ?? '–'}',
      if (visit.hemoglobin != null) 'Hb ${visit.hemoglobin!.toStringAsFixed(1)}',
      if (visit.weightKg != null) '${visit.weightKg!.toStringAsFixed(1)} kg',
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date column + timeline line
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Container(
                  width: 50,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: byAnm ? AppColors.sky : AppColors.mint,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Column(
                    children: [
                      Text('${d.day}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            state.language == AppLanguage.english
                                ? CalendarText.month(state.language, d.month).substring(0, 3)
                                : CalendarText.month(state.language, d.month),
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 1.2, margin: const EdgeInsets.symmetric(vertical: 4), color: AppColors.border)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
              child: SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(byAnm ? Icons.local_hospital_rounded : Icons.home_rounded,
                            size: 18, color: byAnm ? AppColors.info : AppColors.success),
                        const SizedBox(width: 6),
                        Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
                        if (visit.dangerSigns.isNotEmpty) StatusPill.danger(state.translate('Danger sign', 'खतरा', 'धोका')),
                      ],
                    ),
                    if (recorder != null) ...[
                      const SizedBox(height: 2),
                      Text(recorder, style: theme.textTheme.bodySmall),
                    ],
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in chips)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(AppRadius.pill)),
                              child: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            ),
                        ],
                      ),
                    ],
                    if ((visit.notes ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(visit.notes!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
