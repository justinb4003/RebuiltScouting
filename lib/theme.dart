import 'package:flutter/material.dart';

class AppTheme {
  static const _seedColor = Color(0xFF1565C0); // Blue 800

  static ThemeData lightTheme({String? fontFamily}) => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: _seedColor,
    brightness: Brightness.light,
    fontFamily: fontFamily,
  );

  static ThemeData darkTheme({String? fontFamily}) => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: _seedColor,
    brightness: Brightness.dark,
    fontFamily: fontFamily,
  );

  // Section colors for scouting phases
  static const autoColor = Color(0xFF1565C0); // Blue
  static const teleopColor = Color(0xFF2E7D32); // Green
  static const endgameColor = Color(0xFFE65100); // Orange
}
