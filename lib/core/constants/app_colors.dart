import 'dart:ui';

abstract final class AppColors {
  // Primary - K-pop fandom vibe, neon accent on dark
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFF9B8FEF);
  static const Color primaryDark = Color(0xFF4A3FB5);

  // Accent
  static const Color accent = Color(0xFF00D2D3);
  static const Color accentLight = Color(0xFF55E6E6);

  // Background (dark mode default)
  static const Color background = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceLight = Color(0xFF25253D);
  static const Color card = Color(0xFF1E1E32);

  // Text
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFB0B0C3);
  static const Color textHint = Color(0xFF6B6B80);

  // Status
  static const Color success = Color(0xFF00B894);
  static const Color warning = Color(0xFFFDCB6E);
  static const Color error = Color(0xFFE17055);

  // Trust / Escrow
  static const Color escrowSafe = Color(0xFF00CEC9);
  static const Color verified = Color(0xFF55EFC4);

  // Divider
  static const Color divider = Color(0xFF2D2D44);
}
