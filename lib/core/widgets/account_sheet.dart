import 'package:flutter/material.dart';
import '../../app_state.dart';
import '../theme/app_theme.dart';

/// Bottom sheet with language switch and sign-out, shared by staff screens.
Future<void> showAccountSheet(BuildContext context) async {
  final state = AppState.instance;
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final l in const [('english', 'English'), ('hindi', 'हिंदी'), ('marathi', 'मराठी')])
            ListTile(
              leading: const Icon(Icons.translate_rounded),
              title: Text(l.$2),
              trailing: state.language.name == l.$1 ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
              onTap: () => Navigator.pop(ctx, l.$1),
            ),
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
    if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/selection', (_) => false);
  } else {
    state.setLanguage(AppLanguage.values.byName(choice));
  }
}

/// Avatar button that opens the account sheet (top-right of dashboards).
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Material(
        color: AppColors.muted,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: AppState.instance.translate('Account', 'खाता', 'खाते'),
          icon: const Icon(Icons.more_horiz_rounded),
          onPressed: () => showAccountSheet(context),
        ),
      ),
    );
  }
}
