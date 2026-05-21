import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary - Terracotta
  static const Color primary = Color(0xFFC4654A);
  static const Color primaryLight = Color(0xFFE8A090);
  static const Color primaryDark = Color(0xFF8B3E28);

  // Secondary - Sage Green
  static const Color secondary = Color(0xFF7A9E7E);
  static const Color secondaryLight = Color(0xFFB5D4B8);
  static const Color secondaryDark = Color(0xFF4A7050);

  // Trust Blue
  static const Color trust = Color(0xFF5B8DB8);
  static const Color trustLight = Color(0xFF9BBEDD);

  // Backgrounds - Light
  static const Color background = Color(0xFFFBF7F4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF4EDE8);
  static const Color divider = Color(0xFFEDE5E0);
  static const Color border = Color(0xFFE0D4CC);

  // Backgrounds - Dark
  static const Color darkBackground = Color(0xFF1A1512);
  static const Color darkSurface = Color(0xFF2C2420);
  static const Color darkSurfaceVariant = Color(0xFF3D3028);
  static const Color darkBorder = Color(0xFF4A3C34);

  // Text - Light mode
  static const Color textPrimary = Color(0xFF2C1810);
  static const Color textSecondary = Color(0xFF7A6055);
  static const Color textMuted = Color(0xFFB0968C);
  static const Color textLight = Color(0xFFF4EDE8);

  // Text - Dark mode
  static const Color textMutedDark = Color(0xFF8A7068);

  // Semantic
  static const Color success = Color(0xFF4CAF79);
  static const Color successLight = Color(0xFFB8EDCC);
  static const Color warning = Color(0xFFE8A030);
  static const Color warningLight = Color(0xFFFADFA8);
  static const Color error = Color(0xFFD65745);
  static const Color errorLight = Color(0xFFFF8A7A);
  static const Color info = Color(0xFF5B8DB8);

  // Special
  static const Color shadow = Color(0x1AC4654A);
  static const Color overlay = Color(0x80000000);
  static const Color gold = Color(0xFFD4AF37);
  static const Color platinum = Color(0xFF8E9EAE);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFFD4806A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFFBF7F4), Color(0xFFF4EDE8)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1A1512), Color(0xFF2C2420)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient trustGradient = LinearGradient(
    colors: [trust, Color(0xFF7AAECC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
