import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color bgPrimary = Color(0xFF0B0C0F);
  static const Color bgSecondary = Color(0xFF14161B);
  static const Color bgTertiary = Color(0xFF1E2128);
  static const Color textPrimary = Color(0xFFF0F2F5);
  static const Color textSecondary = Color(0xFF8B919D);
  static const Color textMuted = Color(0xFF5A6270);
  static const Color accentTemp = Color(0xFFFF9F43);
  static const Color accentHumidity = Color(0xFF4DABF7);
  static const Color accentSuccess = Color(0xFF51CF66);
  static const Color accentWarning = Color(0xFFFFD43B);
  static const Color accentDanger = Color(0xFFFF6B6B);
  static const Color border = Color(0xFF2A2E37);
  static const Color gridLine = Color(0xFF1E2128);

  static ThemeData darkTheme() {
    final base = ThemeData.dark();
    const colorScheme = ColorScheme.dark(
      surface: bgPrimary,
      surfaceContainerHighest: bgSecondary,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: border,
      primary: accentHumidity,
      secondary: accentTemp,
      error: accentDanger,
    );

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
          color: textPrimary,
        ),
        displayMedium: GoogleFonts.jetBrainsMono(
          fontSize: 48,
          fontWeight: FontWeight.w300,
          letterSpacing: -1,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        labelSmall: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: textSecondary,
        ),
      ),
      cardTheme: CardTheme(
        color: bgSecondary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: accentTemp,
        inactiveTrackColor: bgTertiary,
        thumbColor: textPrimary,
        overlayColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return textPrimary;
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentHumidity;
          return bgTertiary;
        }),
      ),
    );
  }
}
