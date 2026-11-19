import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app_state.dart';
import '../../../core/config/app_config.dart';
import '../../../core/repositories/care_team_repository.dart';
import '../../../core/repositories/patient_repository.dart';
import '../../../core/theme/app_theme.dart';

/// Emergency options for the mother.
///
/// Every action records an SOS event and an urgent alert for the assigned
/// ASHA (queued offline if needed). The "no internet" option opens the
/// phone's SMS app with a pre-filled message – SMS works on a basic cellular
/// signal without mobile data.
class SosBottomSheet extends StatefulWidget {
  const SosBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const SosBottomSheet(),
    );
  }

  @override
  State<SosBottomSheet> createState() => _SosBottomSheetState();
}

class _SosBottomSheetState extends State<SosBottomSheet> {
  bool _recorded = false;

  Future<void> _recordOnce() async {
    if (_recorded) return;
    _recorded = true;
    final patient = PatientRepository.instance
        .findByProfileId(AppState.instance.currentUser?.id);
    if (patient != null) {
      await CareTeamRepository.instance.recordSos(patient);
    }
  }

  Future<void> _launch(Uri uri, String failureMessage) async {
    await _recordOnce();
    bool ok = false;
    try {
      ok = await launchUrl(uri);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final asha = CareTeamRepository.instance.assignedAsha();
    final patientName = state.currentUser?.name ?? '';
    final cannotOpen = state.translate(
      'Could not open the phone app on this device.',
      'इस डिवाइस पर फ़ोन ऐप नहीं खुल सका।',
      'या डिव्हाइसवर फोन अ‍ॅप उघडता आले नाही.',
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              state.translate('Emergency help', 'आपातकालीन सहायता', 'तातडीची मदत'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              state.translate(
                'Your ASHA will be alerted automatically.',
                'आपकी आशा को स्वतः सूचित किया जाएगा।',
                'तुमच्या आशा कार्यकर्तीला आपोआप कळवले जाईल.',
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            _SosAction(
              icon: Icons.emergency_rounded,
              title: state.translate('Call ambulance (${AppConfig.ambulanceNumber})', 'एम्बुलेंस बुलाएं (${AppConfig.ambulanceNumber})', 'रुग्णवाहिका बोलवा (${AppConfig.ambulanceNumber})'),
              color: AppColors.danger,
              filled: true,
              onTap: () => _launch(Uri(scheme: 'tel', path: AppConfig.ambulanceNumber), cannotOpen),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            _SosAction(
              icon: Icons.call_rounded,
              title: asha != null
                  ? state.translate('Call my ASHA – ${asha.name}', 'मेरी आशा को कॉल करें – ${asha.name}', 'माझ्या आशाला कॉल करा – ${asha.name}')
                  : state.translate('ASHA number not available', 'आशा का नंबर उपलब्ध नहीं', 'आशाचा नंबर उपलब्ध नाही'),
              color: AppColors.primary,
              onTap: asha == null
                  ? null
                  : () => _launch(Uri(scheme: 'tel', path: asha.phone), cannotOpen),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            _SosAction(
              icon: Icons.sms_rounded,
              title: state.translate('No internet? Send SMS to ASHA', 'इंटरनेट नहीं? आशा को SMS भेजें', 'इंटरनेट नाही? आशाला SMS पाठवा'),
              color: AppColors.textPrimary,
              onTap: asha == null
                  ? null
                  : () => _launch(
                        Uri(
                          scheme: 'sms',
                          path: asha.phone,
                          queryParameters: {
                            'body': 'EMERGENCY (Janani): $patientName needs urgent help. Please call back immediately.',
                          },
                        ),
                        cannotOpen,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SosAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;

  const _SosAction({
    required this.icon,
    required this.title,
    required this.color,
    this.filled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    return Material(
      color: filled ? color : color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 18),
            child: Row(
              children: [
                Icon(icon, color: fg, size: 28),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(title, style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                Icon(Icons.chevron_right_rounded, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
