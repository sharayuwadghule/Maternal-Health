import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../core/theme/app_theme.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agreedToTerms = false;
  bool _agreedToDataSharing = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final canContinue = _agreedToTerms && _agreedToDataSharing;

    final points = [
      (
        Icons.lock_rounded,
        state.translate('Stored securely', 'सुरक्षित रूप से संग्रहित', 'सुरक्षितपणे साठवलेले'),
        state.translate('Your records are protected under ABDM / DISHA guidelines.', 'आपके रिकॉर्ड ABDM / DISHA दिशानिर्देशों के तहत सुरक्षित हैं।', 'तुमच्या नोंदी ABDM / DISHA मार्गदर्शक तत्त्वांनुसार सुरक्षित आहेत.'),
      ),
      (
        Icons.groups_rounded,
        state.translate('Shared only with your care team', 'केवल आपकी देखभाल टीम के साथ', 'फक्त तुमच्या काळजी टीमसोबत'),
        state.translate('Your ASHA, ANM and PHC doctor – nobody else.', 'आपकी आशा, एएनएम और PHC डॉक्टर – और कोई नहीं।', 'तुमची आशा, एएनएम आणि PHC डॉक्टर – इतर कोणीही नाही.'),
      ),
      (
        Icons.notifications_active_rounded,
        state.translate('Used to keep you safe', 'आपकी सुरक्षा के लिए', 'तुमच्या सुरक्षिततेसाठी'),
        state.translate('Danger signs and missed medicines alert your ASHA early.', 'खतरे के लक्षण और छूटी दवाएं आपकी आशा को जल्दी सूचित करती हैं।', 'धोक्याची लक्षणे आणि चुकलेली औषधे तुमच्या आशाला लवकर कळवली जातात.'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pushReplacementNamed(context, '/language'),
        ),
        title: Text(state.translate('Privacy & consent', 'गोपनीयता और सहमति', 'गोपनीयता आणि संमती')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg - 4),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 40),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    state.translate('Your health data stays private', 'आपका स्वास्थ्य डेटा निजी रहता है', 'तुमचा आरोग्य डेटा खाजगी राहतो'),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < points.length; i++) ...[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.muted,
                      child: Icon(points[i].$1, color: AppColors.primary, size: 20),
                    ),
                    title: Text(points[i].$2, style: theme.textTheme.titleSmall),
                    subtitle: Text(points[i].$3, style: theme.textTheme.bodySmall),
                  ),
                  if (i < points.length - 1) const Divider(indent: 72),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _ConsentCheck(
            value: _agreedToTerms,
            onChanged: (v) => setState(() => _agreedToTerms = v),
            text: state.translate(
              'I agree to the Terms of Service and Privacy Policy.',
              'मैं सेवा की शर्तों और गोपनीयता नीति से सहमत हूँ।',
              'मी सेवा अटी आणि गोपनीयता धोरणाशी सहमत आहे.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ConsentCheck(
            value: _agreedToDataSharing,
            onChanged: (v) => setState(() => _agreedToDataSharing = v),
            text: state.translate(
              'I consent to share my health records with my ASHA worker and local health centre.',
              'मैं अपने स्वास्थ्य रिकॉर्ड अपनी आशा कार्यकर्ता और स्थानीय स्वास्थ्य केंद्र के साथ साझा करने की सहमति देती हूँ।',
              'मी माझे आरोग्य रेकॉर्ड माझ्या आशा कार्यकर्तीसोबत आणि स्थानिक आरोग्य केंद्रासोबत शेअर करण्यास संमती देते.',
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
          child: ElevatedButton(
            onPressed: canContinue
                ? () {
                    state.acceptConsent();
                    Navigator.pushReplacementNamed(context, '/selection');
                  }
                : null,
            child: Text(state.translate('Agree and continue', 'सहमत हूँ और आगे बढ़ें', 'सहमत आहे, पुढे जा')),
          ),
        ),
      ),
    );
  }
}

class _ConsentCheck extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String text;
  const _ConsentCheck({required this.value, required this.onChanged, required this.text});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: BorderSide(color: value ? AppColors.primary : AppColors.border),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        title: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
      ),
    );
  }
}
