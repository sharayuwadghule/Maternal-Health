import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';

class NearestClinicScreen extends StatelessWidget {
  const NearestClinicScreen({super.key});

  /// Opens the phone's maps app searching for the facility near the user.
  Future<void> _directions(BuildContext context, String query) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '$query near me'});
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open maps on this device.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    final clinics = [
      (state.translate('Primary Health Centre (PHC)', 'प्राथमिक स्वास्थ्य केंद्र', 'प्राथमिक आरोग्य केंद्र'), 'Primary Health Centre', '1.2 km', state.translate('Free checkups · PMSMA on 9th', 'मुफ्त जांच · 9 तारीख को PMSMA', 'मोफत तपासणी · ९ तारखेला PMSMA'), true, AppColors.mint, AppColors.success),
      (state.translate('District Civil Hospital', 'जिला सिविल अस्पताल', 'जिल्हा सामान्य रुग्णालय'), 'District Hospital', '4.5 km', state.translate('Delivery · blood bank · 24×7', 'प्रसव · ब्लड बैंक · 24×7', 'प्रसूती · रक्तपेढी · २४×७'), true, AppColors.sky, AppColors.info),
      (state.translate('Maternity Clinic', 'मातृत्व क्लिनिक', 'प्रसूतिगृह'), 'Maternity Clinic', '5.8 km', state.translate('Sonography · closes 5 PM', 'सोनोग्राफी · शाम 5 बजे बंद', 'सोनोग्राफी · ५ वाजता बंद'), false, AppColors.lavender, Color(0xFF6B4FD8)),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(state.translate('Nearest clinics', 'निकटतम क्लिनिक', 'जवळचे दवाखाने'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg - 4, AppSpacing.sm, AppSpacing.lg - 4, AppSpacing.lg),
        children: [
          // ── Map preview ──────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              height: 190,
              color: AppColors.sky,
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _MapGridPainter())),
                  const Positioned(top: 34, left: 40, child: _Pin(label: 'PHC', color: AppColors.success)),
                  const Positioned(bottom: 30, right: 44, child: _Pin(label: 'Hospital', color: AppColors.info)),
                  Center(
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: const [BoxShadow(color: Color(0x332B2440), blurRadius: 12)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary, minimumSize: const Size(0, 40), shape: const StadiumBorder()),
                      onPressed: () => _directions(context, 'hospital'),
                      icon: const Icon(Icons.map_rounded, size: 18),
                      label: Text(state.translate('Open in Maps', 'मैप्स में खोलें', 'मॅप्समध्ये उघडा')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionTitle(state.translate('Nearby facilities', 'आसपास की सुविधाएं', 'जवळपासच्या सुविधा')),
          for (final c in clinics) ...[
            SoftCard(
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: c.$6, borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: Icon(Icons.local_hospital_rounded, color: c.$7),
                  ),
                  const SizedBox(width: AppSpacing.md - 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.$1, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(c.$4, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.near_me_rounded, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(c.$3, style: theme.textTheme.bodySmall),
                            const SizedBox(width: AppSpacing.sm),
                            c.$5
                                ? StatusPill.success(state.translate('Open', 'खुला', 'उघडे'))
                                : StatusPill.warning(state.translate('Closes soon', 'जल्द बंद', 'लवकरच बंद')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: state.translate('Directions', 'रास्ता', 'मार्ग'),
                      onPressed: () => _directions(context, c.$2),
                      icon: const Icon(Icons.directions_rounded, color: Colors.white, size: 20),
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
}

class _Pin extends StatelessWidget {
  final String label;
  final Color color;
  const _Pin({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.pill)),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ),
        Icon(Icons.location_on_rounded, color: color, size: 28),
      ],
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final lane = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 4;
    canvas.drawLine(Offset(0, size.height * 0.62), Offset(size.width, size.height * 0.38), road);
    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(size.width * 0.55, size.height), road);
    for (var x = 0.0; x < size.width; x += 56) {
      canvas.drawLine(Offset(x, 0), Offset(x + 30, size.height), lane);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
