import 'package:flutter/material.dart';

class AppTheme {
  static const _seedColor = Color(0xFF1565C0); // Blue 800

  static final lightTheme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: _seedColor,
    brightness: Brightness.light,
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: _seedColor,
    brightness: Brightness.dark,
  );

  // Section colors for scouting phases
  static const autoColor = Color(0xFF1565C0); // Blue
  static const teleopColor = Color(0xFF2E7D32); // Green
  static const endgameColor = Color(0xFFE65100); // Orange
}
