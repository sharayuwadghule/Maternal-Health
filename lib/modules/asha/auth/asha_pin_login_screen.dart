import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../app_state.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/app_user.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/theme/app_theme.dart';

enum _PinMode { unlock, setup, confirm, needsSignIn }

/// Staff device PIN.
///
/// * unlock – a signed-in health worker re-opens the app (shared phones).
/// * setup/confirm – first sign-in on this device.
/// * needsSignIn – live mode with no session: phone OTP is required first.
///
/// The PIN is checked against a salted hash stored on the device only; it
/// never replaces server authentication.
class AshaPinLoginScreen extends StatefulWidget {
  const AshaPinLoginScreen({super.key});

  @override
  State<AshaPinLoginScreen> createState() => _AshaPinLoginScreenState();
}

class _AshaPinLoginScreenState extends State<AshaPinLoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  late _PinMode _mode;
  String? _firstPin;
  String? _error;
  bool _busy = false;

  AuthRepository get _auth => AuthRepository.instance;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user != null && user.role.isStaff) {
      _mode = _auth.hasOfflinePin ? _PinMode.unlock : _PinMode.setup;
    } else {
      _mode = AppConfig.demoMode ? _PinMode.setup : _PinMode.needsSignIn;
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _goHome() {
    final user = _auth.currentUser!;
    context.read<AppState>().setUser(user);
    Navigator.pushNamedAndRemoveUntil(context, user.role.homeRoute, (_) => false);
  }

  Future<void> _submit() async {
    final state = context.read<AppState>();
    final pin = _pinController.text;
    if (pin.length != 4 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      switch (_mode) {
        case _PinMode.unlock:
          if (await _auth.verifyOfflinePin(pin)) {
            if (mounted) _goHome();
          } else {
            final locked = _auth.pinLockedUntil;
            setState(() => _error = locked != null
                ? state.translate(
                    'Too many attempts. Try again in a few minutes.',
                    'बहुत अधिक प्रयास। कुछ मिनट बाद पुनः प्रयास करें।',
                    'खूप प्रयत्न झाले. काही मिनिटांनी पुन्हा प्रयत्न करा.')
                : state.translate('Incorrect PIN', 'गलत पिन', 'चुकीचा पिन'));
          }
          break;
        case _PinMode.setup:
          setState(() {
            _firstPin = pin;
            _mode = _PinMode.confirm;
          });
          break;
        case _PinMode.confirm:
          if (pin != _firstPin) {
            setState(() {
              _mode = _PinMode.setup;
              _firstPin = null;
              _error = state.translate('PINs did not match. Try again.', 'पिन मेल नहीं खाए। फिर से प्रयास करें।', 'पिन जुळले नाहीत. पुन्हा प्रयत्न करा.');
            });
            break;
          }
          if (_auth.currentUser == null && AppConfig.demoMode) {
            await _auth.loginAsDemoRole(UserRole.asha);
          }
          await _auth.setOfflinePin(pin);
          if (mounted) _goHome();
          break;
        case _PinMode.needsSignIn:
          break;
      }
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } finally {
      _pinController.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await context.read<AppState>().logout();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/selection', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final user = _auth.currentUser;

    final title = switch (_mode) {
      _PinMode.unlock => state.translate('Enter your PIN', 'अपना पिन दर्ज करें', 'तुमचा पिन टाका'),
      _PinMode.setup => state.translate('Create a 4-digit PIN', '4 अंकों का पिन बनाएं', '४ अंकी पिन तयार करा'),
      _PinMode.confirm => state.translate('Confirm your PIN', 'पिन की पुष्टि करें', 'पिनची पुष्टी करा'),
      _PinMode.needsSignIn => state.translate('Sign in required', 'लॉगिन आवश्यक', 'लॉगिन आवश्यक'),
    };
    final subtitle = switch (_mode) {
      _PinMode.unlock => user?.name ?? '',
      _PinMode.setup || _PinMode.confirm => state.translate(
          'You will use this PIN to open the app on this phone, even offline.',
          'इस फोन पर ऐप खोलने के लिए इस पिन का उपयोग करें, ऑफ़लाइन भी।',
          'या फोनवर अ‍ॅप उघडण्यासाठी हा पिन वापरा, ऑफलाइन सुद्धा.'),
      _PinMode.needsSignIn => state.translate(
          'Verify your mobile number once. After that you can use a PIN on this phone.',
          'एक बार अपना मोबाइल नंबर सत्यापित करें। उसके बाद इस फोन पर पिन का उपयोग करें।',
          'एकदा तुमचा मोबाईल नंबर सत्यापित करा. त्यानंतर या फोनवर पिन वापरा.'),
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: _mode != _PinMode.unlock,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          children: [
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(Icons.lock_rounded, size: 36, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(subtitle, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xl),
            if (_mode == _PinMode.needsSignIn)
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login', arguments: UserRole.asha),
                child: Text(state.translate('Sign in with mobile number', 'मोबाइल नंबर से लॉगिन करें', 'मोबाईल नंबरने लॉगिन करा')),
              )
            else ...[
              Center(
                child: SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _pinController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    obscuringCharacter: '●',
                    textAlign: TextAlign.center,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    style: const TextStyle(fontSize: 28, letterSpacing: 18, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(errorText: _error, errorMaxLines: 2),
                    onChanged: (v) {
                      if (v.length == 4) _submit();
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: Text(_mode == _PinMode.unlock
                    ? state.translate('Unlock', 'खोलें', 'उघडा')
                    : state.translate('Continue', 'आगे बढ़ें', 'पुढे जा')),
              ),
              if (_mode == _PinMode.unlock) ...[
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: TextButton(
                    onPressed: _signOut,
                    child: Text(state.translate('Not you? Sign out', 'आप नहीं? लॉग आउट करें', 'तुम्ही नाही? लॉग आउट करा')),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
