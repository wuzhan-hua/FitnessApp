import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppPalette {
  const AppPalette({
    required this.background,
    required this.panel,
    required this.panelAlt,
    required this.textPrimary,
    required this.textMuted,
    required this.accent,
    required this.warning,
    required this.success,
  });

  final Color background;
  final Color panel;
  final Color panelAlt;
  final Color textPrimary;
  final Color textMuted;
  final Color accent;
  final Color warning;
  final Color success;

  static const light = AppPalette(
    background: Color(0xFFF4F8FF),
    panel: Color(0xFFFFFFFF),
    panelAlt: Color(0xFFEAF2FF),
    textPrimary: Color(0xFF10203A),
    textMuted: Color(0xFF5B6B86),
    accent: Color(0xFF1D72FF),
    warning: Color(0xFFF59E0B),
    success: Color(0xFF16A34A),
  );

  static const dark = AppPalette(
    background: Color(0xFF0D111A),
    panel: Color(0xFF131B2A),
    panelAlt: Color(0xFF1B2436),
    textPrimary: Color(0xFFF2F5FC),
    textMuted: Color(0xFF9AA4BA),
    accent: Color(0xFF2DD4BF),
    warning: Color(0xFFF59E0B),
    success: Color(0xFF34D399),
  );
}

class AppColors {
  static AppPalette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
  }
}

class AppSpacing {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
}

class AppRadius {
  static const BorderRadius card = BorderRadius.all(Radius.circular(16));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(999));
}

class AppTheme {
  static ThemeData get light => _buildTheme(AppPalette.light, Brightness.light);

  static ThemeData get dark => _buildTheme(AppPalette.dark, Brightness.dark);

  static ThemeData _buildTheme(AppPalette palette, Brightness brightness) {
    final baseText = GoogleFonts.spaceGroteskTextTheme().apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    );

    final display = GoogleFonts.barlowCondensedTextTheme().copyWith(
      headlineSmall: GoogleFonts.barlowCondensed(
        fontWeight: FontWeight.w700,
        fontSize: 28,
      ),
      headlineMedium: GoogleFonts.barlowCondensed(
        fontWeight: FontWeight.w700,
        fontSize: 32,
      ),
    );

    final mergedText = baseText.copyWith(
      headlineSmall: display.headlineSmall,
      headlineMedium: display.headlineMedium,
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: brightness,
      surface: palette.panel,
      primary: palette.accent,
      onPrimary: brightness == Brightness.dark
          ? palette.background
          : Colors.white,
      onSurface: palette.textPrimary,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      textTheme: mergedText,
      appBarTheme: AppBarThemeData(
        backgroundColor: palette.background,
        elevation: 0,
        centerTitle: false,
        foregroundColor: palette.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: palette.panel,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.panel,
        indicatorColor: palette.accent.withValues(alpha: 0.2),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600,
            color: palette.textPrimary,
          ),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: palette.textMuted),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.panelAlt,
        selectedColor: palette.accent.withValues(alpha: 0.2),
        shape: const StadiumBorder(),
        labelStyle: GoogleFonts.spaceGrotesk(
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      useMaterial3: true,
    );
  }
}
