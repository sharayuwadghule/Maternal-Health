import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app_state.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/app_user.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/theme/app_theme.dart';

/// Phone-number entry. Used by every role in live mode (Supabase phone OTP)
/// and by mothers in demo mode.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  UserRole get _role =>
      (ModalRoute.of(context)?.settings.arguments as UserRole?) ?? UserRole.patient;

  Future<void> _submit() async {
    final state = AppState.instance;
    final phone = _phoneController.text.trim();
    if (!AuthRepository.isValidIndianMobile(phone)) {
      setState(() => _error = state.translate(
            'Enter a valid 10-digit mobile number',
            'कृपया सही 10 अंकों का मोबाइल नंबर दर्ज करें',
            'कृपया वैध १० अंकी मोबाईल नंबर टाका',
          ));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final request = await AuthRepository.instance.requestOtp(phone);
      if (!mounted) return;
      Navigator.pushNamed(context, '/otp', arguments: {'request': request, 'role': _role});
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = state.translate(
            'Could not send the code. Check your network and try again.',
            'कोड नहीं भेजा जा सका। नेटवर्क जांचें और पुनः प्रयास करें।',
            'कोड पाठवता आला नाही. नेटवर्क तपासा आणि पुन्हा प्रयत्न करा.',
          ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final theme = Theme.of(context);
    final isPatient = _role == UserRole.patient;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          children: [
            Text(
              isPatient
                  ? state.translate('Welcome to ${AppConfig.appName}', '${AppConfig.appName} में आपका स्वागत है', '${AppConfig.appName} मध्ये आपले स्वागत आहे')
                  : state.translate('Health worker sign in', 'स्वास्थ्य कार्यकर्ता लॉगिन', 'आरोग्य कर्मचारी लॉगिन'),
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              state.translate(
                'Enter your mobile number. We will send you a one-time code.',
                'अपना मोबाइल नंबर दर्ज करें। हम आपको एक कोड भेजेंगे।',
                'तुमचा मोबाईल नंबर टाका. आम्ही तुम्हाला एक कोड पाठवू.',
              ),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              state.translate('Mobile number', 'मोबाइल नंबर', 'मोबाईल नंबर'),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              style: theme.textTheme.titleMedium?.copyWith(letterSpacing: 1.5),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 16, right: 8),
                  child: Text(AppConfig.phoneCountryCode, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                hintText: '98XXXXXXXX',
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(state.translate('Get code', 'कोड प्राप्त करें', 'कोड मिळवा')),
            ),
            if (isPatient) ...[
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/asha_pin_login'),
                  child: Text(state.translate(
                    'Are you an ASHA worker? Sign in here',
                    'क्या आप आशा कार्यकर्ता हैं? यहाँ लॉगिन करें',
                    'तुम्ही आशा कार्यकर्ती आहात का? येथे लॉगिन करा',
                  )),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
