import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app_state.dart';
import '../../../core/models/app_user.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/care_team_repository.dart';
import '../../../core/repositories/patient_repository.dart';
import '../../../core/theme/app_theme.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const int _codeLength = 6;

  final TextEditingController _codeController = TextEditingController();
  OtpRequest? _request;
  UserRole _role = UserRole.patient;
  bool _loading = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_request == null) {
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      _request = args?['request'] as OtpRequest?;
      _role = args?['role'] as UserRole? ?? UserRole.patient;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final request = _request;
    if (request == null) return;
    final code = _codeController.text.trim();
    if (code.length != _codeLength) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await AuthRepository.instance.verifyOtp(
        request: request,
        otp: code,
        demoRole: _role,
      );
      AppState.instance.setUser(user);
      if (user.role == UserRole.patient) {
        CareTeamRepository.instance.refresh(PatientRepository.instance.findByProfileId(user.id));
      }
      if (!mounted) return;
      final next = user.role.isStaff && !AuthRepository.instance.hasOfflinePin
          ? '/asha_pin_login' // first sign-in: set a device PIN
          : user.role.homeRoute;
      Navigator.pushNamedAndRemoveUntil(context, next, (_) => false);
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = AppState.instance.translate(
            'Verification failed. Check your network and try again.',
            'सत्यापन विफल। नेटवर्क जांचें और पुनः प्रयास करें।',
            'पडताळणी अयशस्वी. नेटवर्क तपासा आणि पुन्हा प्रयत्न करा.',
          ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    final request = _request;
    if (request == null) return;
    try {
      final fresh = await AuthRepository.instance.requestOtp(request.phone);
      setState(() {
        _request = fresh;
        _codeController.clear();
        _error = null;
      });
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final theme = Theme.of(context);
    final demoCode = _request?.demoCode;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          children: [
            Text(
              state.translate('Enter the code', 'कोड दर्ज करें', 'कोड टाका'),
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              state.translate(
                'We sent a 6-digit code to +91 ${_request?.phone ?? ''}',
                'हमने +91 ${_request?.phone ?? ''} पर 6 अंकों का कोड भेजा है',
                'आम्ही +91 ${_request?.phone ?? ''} वर ६ अंकी कोड पाठवला आहे',
              ),
              style: theme.textTheme.bodyLarge,
            ),
            if (demoCode != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.infoContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.info),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Demo mode – no SMS is sent. Your code is $demoCode',
                        style: const TextStyle(color: AppColors.info, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            TextField(
              controller: _codeController,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_codeLength),
              ],
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 14),
              decoration: InputDecoration(
                hintText: '••••••',
                errorText: _error,
                errorMaxLines: 3,
              ),
              onChanged: (v) {
                if (v.length == _codeLength) _verify();
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _loading ? null : _verify,
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(state.translate('Verify and continue', 'सत्यापित करें और आगे बढ़ें', 'सत्यापित करा आणि पुढे जा')),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: _loading ? null : _resend,
                child: Text(state.translate('Resend code', 'कोड दोबारा भेजें', 'कोड पुन्हा पाठवा')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
