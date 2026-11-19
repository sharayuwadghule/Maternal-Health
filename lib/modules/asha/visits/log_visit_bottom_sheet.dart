import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../../app_state.dart';
import '../../../core/repositories/visit_repository.dart';

class LogVisitBottomSheet extends StatelessWidget {
  final String patientId;
  final String patientName;
  
  const LogVisitBottomSheet({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  static void show(BuildContext context, {required String patientId, required String patientName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => LogVisitBottomSheet(
        patientId: patientId,
        patientName: patientName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.translate('Log Home Visit', 'गृह भेंट दर्ज करें', 'घर भेट नोंदवा'),
                style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          Text(
            patientName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: AppColors.successContainer,
            leading: const Icon(Icons.check_circle, color: AppColors.success, size: 28),
            title: Text(state.translate('Routine ANC Visit', 'नियमित प्रसवपूर्व जांच', 'नियमित तपासणी भेट'), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(state.translate('Diet advice, medicine supply checked', 'आहार सलाह, दवा आपूर्ति की जांच', 'आहार सल्ला, औषध पुरवठा तपासला')),
            onTap: () => _logAndClose(context, 'Routine ANC checkup conducted by ASHA. Mother counselled on nutrition.'),
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: AppColors.warningContainer,
            leading: const Icon(Icons.medication, color: AppColors.warning, size: 28),
            title: Text(state.translate('Follow-up (Missed Meds)', 'फॉलो-अप (दवा छूटी)', 'फॉलो-अप (औषध चुकले)'), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(state.translate('Encouraged patient to resume Iron/Calcium daily', 'रोगी को दैनिक आयरन/कैल्शियम लेने के लिए प्रेरित किया', 'रुग्णाला दररोज आयर्न/कॅल्शियम घेण्यास प्रोत्साहित केले')),
            onTap: () => _logAndClose(context, 'Medicine adherence follow-up visit. Reminded mother on benefits of daily Iron & Calcium.'),
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: AppColors.dangerContainer,
            leading: const Icon(Icons.emergency, color: AppColors.danger, size: 28),
            title: Text(state.translate('Emergency/HRP Visit', 'आपातकालीन/HRP विजिट', 'तातडीची भेट (HRP)'), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(state.translate('High risk detected, escalation to ANM required', 'उच्च जोखिम की पहचान, एएनएम को रेफरल आवश्यक', 'उच्च धोका आढळला, एएनएमकडे पाठवणे आवश्यक')),
            onTap: () => _logAndClose(context, 'Urgent high-risk checkup. Clinical review initiated.'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _logAndClose(BuildContext context, String notes) async {
    final state = AppState.instance;
    await VisitRepository.instance.logVisit(
      patientId: patientId,
      recordedBy: state.currentUser?.id ?? '',
      recordedByRole: state.currentRole.name,
      visitDate: DateTime.now(),
      notes: notes,
    );

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.translate(
            'Visit logged successfully (Offline Sync Queued)',
            'विजिट सफलतापूर्वक दर्ज की गई (ऑफ़लाइन सिंक कतारबद्ध)',
            'भेट यशस्वीरित्या नोंदवली गेली (ऑफलाइन सिंक रांगेत)',
          )),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
