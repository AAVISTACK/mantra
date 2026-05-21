import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextTheme get textTheme => TextTheme(
        displayLarge: _base(32, FontWeight.w700, AppColors.textPrimary),
        displayMedium: _base(28, FontWeight.w700, AppColors.textPrimary),
        displaySmall: _base(24, FontWeight.w600, AppColors.textPrimary),
        headlineLarge: _base(22, FontWeight.w600, AppColors.textPrimary),
        headlineMedium: _base(20, FontWeight.w600, AppColors.textPrimary),
        headlineSmall: _base(18, FontWeight.w600, AppColors.textPrimary),
        titleLarge: _base(17, FontWeight.w600, AppColors.textPrimary),
        titleMedium: _base(15, FontWeight.w600, AppColors.textPrimary),
        titleSmall: _base(13, FontWeight.w600, AppColors.textPrimary),
        bodyLarge: _base(16, FontWeight.w400, AppColors.textPrimary),
        bodyMedium: _base(14, FontWeight.w400, AppColors.textPrimary),
        bodySmall: _base(12, FontWeight.w400, AppColors.textSecondary),
        labelLarge: _base(14, FontWeight.w600, AppColors.textPrimary),
        labelMedium: _base(12, FontWeight.w500, AppColors.textSecondary),
        labelSmall: _base(10, FontWeight.w500, AppColors.textMuted),
      );

  static TextTheme get darkTextTheme => TextTheme(
        displayLarge: _base(32, FontWeight.w700, AppColors.textLight),
        displayMedium: _base(28, FontWeight.w700, AppColors.textLight),
        displaySmall: _base(24, FontWeight.w600, AppColors.textLight),
        headlineLarge: _base(22, FontWeight.w600, AppColors.textLight),
        headlineMedium: _base(20, FontWeight.w600, AppColors.textLight),
        headlineSmall: _base(18, FontWeight.w600, AppColors.textLight),
        titleLarge: _base(17, FontWeight.w600, AppColors.textLight),
        titleMedium: _base(15, FontWeight.w600, AppColors.textLight),
        titleSmall: _base(13, FontWeight.w600, AppColors.textLight),
        bodyLarge: _base(16, FontWeight.w400, AppColors.textLight),
        bodyMedium: _base(14, FontWeight.w400, AppColors.textLight),
        bodySmall: _base(12, FontWeight.w400, AppColors.textMutedDark),
        labelLarge: _base(14, FontWeight.w600, AppColors.textLight),
        labelMedium: _base(12, FontWeight.w500, AppColors.textMutedDark),
        labelSmall: _base(10, FontWeight.w500, AppColors.textMutedDark),
      );

  static TextStyle _base(double size, FontWeight weight, Color color) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: size > 20 ? -0.5 : 0.1,
      height: 1.4,
    );
  }

  // Lora serif — for hero/emotional moments
  static TextStyle get heroDisplay => GoogleFonts.lora(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
        height: 1.3,
      );

  static TextStyle get heroDisplayDark => GoogleFonts.lora(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.textLight,
        letterSpacing: -0.5,
        height: 1.3,
      );
}
