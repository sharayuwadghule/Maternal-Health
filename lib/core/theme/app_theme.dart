import 'package:flutter/material.dart';

/// Janani design tokens. Use these instead of hard-coded colours/sizes so the
/// whole app stays visually consistent.
class AppColors {
  AppColors._();

  // Brand – warm, calm, premium
  static const Color primary = Color(0xFF2B2440); // ink plum (buttons, nav)
  static const Color primaryContainer = Color(0xFFECE8F6);
  static const Color accent = Color(0xFFF2994A); // warm orange (highlights)
  static const Color accentContainer = Color(0xFFFFE6D3);

  // Neutrals
  static const Color background = Colors.white; // clean white
  static const Color muted = Color(0xFFF4F4F7); // fills inside white areas
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1F1B24);
  static const Color textSecondary = Color(0xFF77717F);
  static const Color border = Color(0xFFEDEBF0);

  // Pastel card fills (reference: journal / routine apps)
  static const Color butter = Color(0xFFFFCD5C);
  static const Color peach = Color(0xFFFFE1CC);
  static const Color blush = Color(0xFFF8DCDC);
  static const Color lavender = Color(0xFFE5DEFB);
  static const Color mint = Color(0xFFDDF0E2);
  static const Color sky = Color(0xFFDCEAFB);
  static const Color cocoa = Color(0xFF6B3A1E); // dark pill buttons on peach

  // Clinical status (always pair with an icon or label – never colour alone)
  static const Color danger = Color(0xFFD64545);
  static const Color dangerContainer = Color(0xFFFCE6E6);
  static const Color warning = Color(0xFFB8690C);
  static const Color warningContainer = Color(0xFFFFF1DC);
  static const Color success = Color(0xFF2F8F55);
  static const Color successContainer = Color(0xFFE2F4E8);
  static const Color info = Color(0xFF3A6FD8);
  static const Color infoContainer = Color(0xFFE3ECFC);
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppRadius {
  AppRadius._();
  static const double sm = 14;
  static const double md = 22;
  static const double lg = 28;
  static const double pill = 100;
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      primaryContainer: AppColors.primaryContainer,
      secondary: AppColors.accent,
      secondaryContainer: AppColors.accentContainer,
      tertiary: AppColors.primaryContainer,
      error: AppColors.danger,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      outline: AppColors.border,
    );

    const textTheme = TextTheme(
      displaySmall: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.2),
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.2),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.25),
      headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      bodyLarge: TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.45),
      bodyMedium: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
      bodySmall: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4),
    );

    final roundedMd = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill));
    OutlineInputBorder inputBorder(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      // Devanagari fallback keeps Hindi/Marathi glyphs consistent on Android.
      fontFamily: 'Poppins',
      fontFamilyFallback: const ['Noto Sans Devanagari', 'Noto Sans'],
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          minimumSize: const Size.fromHeight(56),
          shape: roundedMd,
          elevation: 0,
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(64, 48), shape: roundedMd, textStyle: textTheme.labelLarge),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: AppColors.border),
          shape: roundedMd,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary, minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: inputBorder(Colors.transparent),
        enabledBorder: inputBorder(Colors.transparent),
        focusedBorder: inputBorder(AppColors.primary, 2),
        errorBorder: inputBorder(AppColors.danger),
        focusedErrorBorder: inputBorder(AppColors.danger, 2),
        hintStyle: const TextStyle(color: Color(0xFF9AA3B2)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelStyle: textTheme.labelMedium,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
      checkboxTheme: CheckboxThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
    );
  }
}

/// A small coloured status label with an icon (never colour alone).
class StatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color background;

  const StatusPill({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
  });

  factory StatusPill.danger(String label) =>
      StatusPill(label: label, icon: Icons.error_rounded, color: AppColors.danger, background: AppColors.dangerContainer);
  factory StatusPill.warning(String label) =>
      StatusPill(label: label, icon: Icons.warning_amber_rounded, color: AppColors.warning, background: AppColors.warningContainer);
  factory StatusPill.success(String label) =>
      StatusPill(label: label, icon: Icons.check_circle_rounded, color: AppColors.success, background: AppColors.successContainer);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Persistent "DEMO" label so judges and testers can never confuse demo data
/// with real patient data.
class DemoBanner extends StatelessWidget {
  final Widget child;
  final bool enabled;
  const DemoBanner({super.key, required this.child, required this.enabled});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Banner(
      message: 'DEMO',
      location: BannerLocation.topEnd,
      color: AppColors.accent,
      child: child,
    );
  }
}
