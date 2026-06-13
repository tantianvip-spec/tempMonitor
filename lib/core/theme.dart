import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Dark theme colors ──────────────────────────────────────────
  static const Color darkBgPrimary = Color(0xFF0B0C0F);
  static const Color darkBgSecondary = Color(0xFF14161B);
  static const Color darkBgTertiary = Color(0xFF1E2128);
  static const Color darkTextPrimary = Color(0xFFF0F2F5);
  static const Color darkTextSecondary = Color(0xFF8B919D);
  static const Color darkTextMuted = Color(0xFF5A6270);
  static const Color darkBorder = Color(0xFF2A2E37);
  static const Color darkGridLine = Color(0xFF1E2128);

  // ── Light theme colors ─────────────────────────────────────────
  static const Color lightBgPrimary = Color(0xFFF5F6F8);
  static const Color lightBgSecondary = Color(0xFFFFFFFF);
  static const Color lightBgTertiary = Color(0xFFEDEEF0);
  static const Color lightTextPrimary = Color(0xFF1A1C20);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightTextMuted = Color(0xFF9CA3AF);
  static const Color lightBorder = Color(0xFFE5E7EB);
  static const Color lightGridLine = Color(0xFFE5E7EB);

  // ── Shared accent colors ───────────────────────────────────────
  static const Color accentTemp = Color(0xFFFF9F43);
  static const Color accentHumidity = Color(0xFF4DABF7);
  static const Color accentSuccess = Color(0xFF51CF66);
  static const Color accentWarning = Color(0xFFFFD43B);
  static const Color accentDanger = Color(0xFFFF6B6B);

  // ── Semantic aliases (resolved by theme) ───────────────────────
  static Color bgPrimary(BuildContext context) =>
      _isDark(context) ? darkBgPrimary : lightBgPrimary;
  static Color bgSecondary(BuildContext context) =>
      _isDark(context) ? darkBgSecondary : lightBgSecondary;
  static Color bgTertiary(BuildContext context) =>
      _isDark(context) ? darkBgTertiary : lightBgTertiary;
  static Color textPrimary(BuildContext context) =>
      _isDark(context) ? darkTextPrimary : lightTextPrimary;
  static Color textSecondary(BuildContext context) =>
      _isDark(context) ? darkTextSecondary : lightTextSecondary;
  static Color textMuted(BuildContext context) =>
      _isDark(context) ? darkTextMuted : lightTextMuted;
  static Color border(BuildContext context) =>
      _isDark(context) ? darkBorder : lightBorder;
  static Color gridLine(BuildContext context) =>
      _isDark(context) ? darkGridLine : lightGridLine;

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static ThemeData darkTheme() {
    const colorScheme = ColorScheme.dark(
      surface: darkBgPrimary,
      surfaceContainerHighest: darkBgSecondary,
      onSurface: darkTextPrimary,
      onSurfaceVariant: darkTextSecondary,
      outline: darkBorder,
      primary: accentHumidity,
      secondary: accentTemp,
      error: accentDanger,
    );

    return _buildTheme(Brightness.dark, colorScheme, darkBgPrimary,
        darkBgSecondary, darkBgTertiary, darkBorder);
  }

  static ThemeData lightTheme() {
    const colorScheme = ColorScheme.light(
      surface: lightBgPrimary,
      surfaceContainerHighest: lightBgSecondary,
      onSurface: lightTextPrimary,
      onSurfaceVariant: lightTextSecondary,
      outline: lightBorder,
      primary: accentHumidity,
      secondary: accentTemp,
      error: accentDanger,
    );

    return _buildTheme(Brightness.light, colorScheme, lightBgPrimary,
        lightBgSecondary, lightBgTertiary, lightBorder);
  }

  static ThemeData _buildTheme(
    Brightness brightness,
    ColorScheme colorScheme,
    Color bgPrimary,
    Color bgSecondary,
    Color bgTertiary,
    Color border,
  ) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark()
        : ThemeData.light();

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgPrimary,
      cardColor: bgSecondary,
      dividerColor: border,
      textTheme: GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.jetBrainsMono(
          fontSize: 72,
          fontWeight: FontWeight.w300,
          letterSpacing: -2,
          color: colorScheme.onSurface,
        ),
        displayMedium: GoogleFonts.jetBrainsMono(
          fontSize: 48,
          fontWeight: FontWeight.w300,
          letterSpacing: -1,
          color: colorScheme.onSurface,
        ),
        titleLarge: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        titleMedium: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        bodyMedium: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
        ),
        labelSmall: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      cardTheme: CardTheme(
        color: bgSecondary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentTemp,
        inactiveTrackColor: bgTertiary,
        thumbColor: colorScheme.onSurface,
        overlayColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.onSurface;
          return colorScheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentHumidity;
          return bgTertiary;
        }),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgPrimary,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgPrimary,
        indicatorColor: bgTertiary,
      ),
    );
  }
}
