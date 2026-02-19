import 'package:flutter/material.dart';

class AppTheme {
  static const defaultColor = Color(0xFF1565C0); // Blue 800

  static const themeColors = <String, Color>{
    'Red': Colors.red,
    'Pink': Colors.pink,
    'Purple': Colors.purple,
    'Deep Purple': Colors.deepPurple,
    'Indigo': Colors.indigo,
    'Blue': Color(0xFF1565C0),
    'Light Blue': Colors.lightBlue,
    'Teal': Colors.teal,
    'Green': Colors.green,
    'Lime': Colors.lime,
    'Amber': Colors.amber,
    'Orange': Colors.orange,
    'Deep Orange': Colors.deepOrange,
  };

  static ThemeData lightTheme({String? fontFamily, Color? seedColor}) =>
      ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seedColor ?? defaultColor,
        brightness: Brightness.light,
        fontFamily: fontFamily,
      );

  static ThemeData darkTheme({String? fontFamily, Color? seedColor}) =>
      ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seedColor ?? defaultColor,
        brightness: Brightness.dark,
        fontFamily: fontFamily,
      );

  // Section colors for scouting phases
  static const autoColor = Color(0xFF1565C0); // Blue
  static const teleopColor = Color(0xFF2E7D32); // Green
  static const teleopInactiveColor = Color(0xFFE65100); // Orange
  static const endgameColor = Color(0xFFC62828); // Red
}
