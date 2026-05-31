import 'package:flutter/material.dart';

class AppTheme {
  // Brand Palette
  static const Color primaryEmerald = Color(0xFF0F9D58);
  static const Color primaryLight = Color(0xFFE8F5E9);
  static const Color accentAmber = Color(0xFFFFB300);
  static const Color destructiveRed = Color(0xFFE53935); // Added missing red

  // Gradients & Backgrounds
  static const Color bgGradientStart = Color(0xFFF8FAFC);
  static const Color bgGradientEnd = Color(0xFFF1F5F9);
  static const Color bgLight = Color(0xFFF9FAFB);

  // Typography Colors
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);

  // Global Premium Shadow
  static BoxShadow get premiumShadow => BoxShadow(
    color: Colors.black.withValues(alpha: 0.06), // Using the updated syntax
    blurRadius: 16,
    offset: const Offset(0, 6),
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bgGradientStart,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.light(
        primary: primaryEmerald,
        secondary: accentAmber,
        surface: Colors.white,
        error: destructiveRed,
      ),
    );
  }
}