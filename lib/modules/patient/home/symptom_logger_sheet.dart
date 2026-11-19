import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_state.dart';
import '../../../core/database/local_db.dart';
import '../../../core/repositories/alert_repository.dart';
import '../../../core/repositories/patient_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../emergency/sos_bottom_sheet.dart';

enum _Level { danger, warning, info }

class _Symptom {
  final String key;
  final String en, hi, mr;
  final _Level level;
  const _Symptom(this.key, this.en, this.hi, this.mr, this.level);
}

/// MoHFW danger signs first, then symptoms that need follow-up.
const List<_Symptom> _symptoms = [
  _Symptom('vaginal_bleeding', 'Bleeding from vagina', 'योनि से रक्तस्राव', 'योनीतून रक्तस्त्राव', _Level.danger),
  _Symptom('severe_headache', 'Severe headache or blurred vision', 'तेज सिरदर्द या धुंधला दिखना', 'तीव्र डोकेदुखी किंवा अंधुक दिसणे', _Level.danger),
  _Symptom('convulsions', 'Fits / convulsions', 'दौरे / झटके', 'फेफरे / झटके', _Level.danger),
  _Symptom('reduced_fetal_movement', 'Baby moving less or not at all', 'शिशु की हलचल कम या बंद', 'बाळाची हालचाल कमी किंवा बंद', _Level.danger),
  _Symptom('severe_abdominal_pain', 'Severe pain in the abdomen', 'पेट में तेज दर्द', 'पोटात तीव्र वेदना', _Level.danger),
  _Symptom('leaking_fluid', 'Water leaking from vagina', 'योनि से पानी आना', 'योनीतून पाणी जाणे', _Level.danger),
  _Symptom('high_fever', 'High fever or chills', 'तेज बुखार या ठंड लगना', 'तीव्र ताप किंवा थंडी', _Level.warning),
  _Symptom('swelling_hands_face', 'Swelling of face or hands', 'चेहरे या हाथों में सूजन', 'चेहऱ्यावर किंवा हातांवर सूज', _Level.warning),
  _Symptom('nausea_vomiting', 'Repeated vomiting', 'बार-बार उल्टी', 'वारंवार उलट्या', _Level.info),
];

class SymptomLoggerSheet extends StatefulWidget {
  const SymptomLoggerSheet({super.key});

  /// Opens the logger. If a danger sign is reported, the SOS options open
  /// straight away so the mother can call for help.
  static Future<void> show(BuildContext context) async {
    final result = await showModalBottomSheet<_Level>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const SymptomLoggerSheet(),
    );
    if (result == null || !context.mounted) return;

    final state = AppState.instance;
    final messenger = ScaffoldMessenger.of(context);
    if (result == _Level.danger) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(state.translate(
          'Danger sign reported. Your ASHA has been alerted.',
          'खतरे का लक्षण दर्ज। आपकी आशा को सूचित किया गया।',
          'धोक्याचे लक्षण नोंदवले. तुमच्या आशाला कळवले आहे.',
        )),
      ));
      SosBottomSheet.show(context);
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(state.translate(
          'Saved. Your ASHA will follow up.',
          'सहेजा गया। आपकी आशा संपर्क करेगी।',
          'जतन केले. तुमची आशा संपर्क करेल.',
        )),
      ));
    }
  }

  @override
  State<SymptomLoggerSheet> createState() => _SymptomLoggerSheetState();
}

class _SymptomLoggerSheetState extends State<SymptomLoggerSheet> {
  final Set<String> _selected = {};
  bool _caregiverConsent = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _caregiverConsent = LocalDb.prefsBox.get('caregiver_consent', defaultValue: true) as bool;
  }

  _Level? _overallLevel() {
    final chosen = _symptoms.where((s) => _selected.contains(s.key));
    if (chosen.isEmpty) return null;
    // Swelling together with headache is a pre-eclampsia warning pattern.
    final preEclampsia = _selected.contains('swelling_hands_face') && _selected.contains('severe_headache');
    if (preEclampsia || chosen.any((s) => s.level == _Level.danger)) return _Level.danger;
    if (chosen.any((s) => s.level == _Level.warning)) return _Level.warning;
    return _Level.info;
  }

  Future<void> _submit() async {
    final level = _overallLevel();
    if (level == null) {
      Navigator.pop(context);
      return;
    }
    final patient = PatientRepository.instance
        .findByProfileId(AppState.instance.currentUser?.id);
    if (patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Your patient record is not available on this device yet.'),
      ));
      return;
    }

    setState(() => _saving = true);
    final labels = _symptoms.where((s) => _selected.contains(s.key)).map((s) => s.en).join(', ');
    await AlertRepository.instance.createAlert(
      patientId: patient.id,
      patientName: patient.name,
      type: 'danger_sign_reported',
      severity: switch (level) {
        _Level.danger => 'urgent',
        _Level.warning => 'warning',
        _Level.info => 'info',
      },
      assignedTo: patient.assignedAshaId,
      message: level == _Level.danger
          ? 'Danger signs reported by mother: $labels'
          : 'Symptoms reported by mother: $labels',
    );
    if (mounted) Navigator.pop(context, level);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                state.translate('How are you feeling today?', 'आज आप कैसा महसूस कर रही हैं?', 'आज तुम्हाला कसे वाटते?'),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                state.translate(
                  'Select anything you are feeling. Signs marked in red alert your ASHA immediately.',
                  'जो भी महसूस हो रहा है उसे चुनें। लाल निशान वाले लक्षण तुरंत आशा को सूचित करते हैं।',
                  'जे जाणवते ते निवडा. लाल चिन्हांकित लक्षणे लगेच आशाला कळवली जातात.',
                ),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final s in _symptoms) _buildOption(state, s),
              const SizedBox(height: AppSpacing.sm),
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  state.translate('Share with my family caregiver', 'परिवार के देखभालकर्ता के साथ साझा करें', 'कुटुंबातील काळजीवाहूसोबत शेअर करा'),
                  style: theme.textTheme.titleSmall,
                ),
                subtitle: Text(
                  state.translate('Lets your linked family member see reminders and medicine status.', 'जुड़े परिवार सदस्य को रिमाइंडर और दवा स्थिति देखने देता है।', 'जोडलेल्या कुटुंबातील सदस्याला आठवणी आणि औषध स्थिती पाहू देते.'),
                  style: theme.textTheme.bodySmall,
                ),
                value: _caregiverConsent,
                onChanged: (val) {
                  setState(() => _caregiverConsent = val);
                  LocalDb.prefsBox.put('caregiver_consent', val);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                style: _overallLevel() == _Level.danger
                    ? ElevatedButton.styleFrom(backgroundColor: AppColors.danger)
                    : null,
                onPressed: _saving ? null : _submit,
                child: Text(_selected.isEmpty
                    ? state.translate('I feel fine', 'मैं ठीक हूँ', 'मी ठीक आहे')
                    : state.translate('Send to my ASHA', 'आशा को भेजें', 'आशाला पाठवा')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(AppState state, _Symptom s) {
    final selected = _selected.contains(s.key);
    final isDanger = s.level == _Level.danger;
    final accent = isDanger ? AppColors.danger : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: selected ? accent.withValues(alpha: 0.08) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: selected ? accent : AppColors.border),
        ),
        child: CheckboxListTile(
          value: selected,
          activeColor: accent,
          controlAffinity: ListTileControlAffinity.leading,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          secondary: isDanger ? const Icon(Icons.error_rounded, color: AppColors.danger) : null,
          title: Text(
            state.translate(s.en, s.hi, s.mr),
            style: TextStyle(
              fontWeight: isDanger ? FontWeight.w600 : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          onChanged: (v) => setState(() {
            if (v == true) {
              _selected.add(s.key);
            } else {
              _selected.remove(s.key);
            }
          }),
        ),
      ),
    );
  }
}
