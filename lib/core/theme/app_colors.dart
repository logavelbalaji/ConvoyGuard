import 'package:flutter/material.dart';

class AppColors {
  // Dark Rider Theme Base Colors
  static const Color background = Color(0xFF0B0F19);
  static const Color surface = Color(0xFF131B2E);
  static const Color surfaceLight = Color(0xFF1C273E);
  static const Color card = Color(0xFF182238);
  static const Color border = Color(0xFF2A3859);

  // Accent Colors
  static const Color primary = Color(0xFF00E5FF); // Electric Cyan
  static const Color primaryDark = Color(0xFF00B8D4);
  static const Color secondary = Color(0xFF7C4DFF); // Deep Accent
  
  // Status & Safety Colors
  static const Color success = Color(0xFF00E676); // Safe Green
  static const Color warning = Color(0xFFFFB300); // Warning Amber
  static const Color danger = Color(0xFFFF3B30); // Alert Red
  static const Color info = Color(0xFF29B6F6);

  // Text Colors
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  
  // Custom Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF0091EA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient alertGradient = LinearGradient(
    colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF182238), Color(0xFF111827)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
