import 'package:flutter/material.dart';

/// A look for the whole app (Appearance > Style). Only colors, shapes and
/// fonts change; every screen keeps its usual widgets.
class AppStyle {
  final String id;
  final String label;
  final String description;
  const AppStyle(this.id, this.label, this.description);
}

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

  static const defaultStyle = 'default';

  static const styles = <AppStyle>[
    AppStyle('default', 'Default', 'Material 3, soft tones from your color'),
    AppStyle('vibrant', 'Vibrant', 'Bolder, more saturated colors'),
    AppStyle('fruit_salad', 'Fruit Salad', 'Playful, shifted colors with contrasting accents'),
    AppStyle('monochrome', 'Monochrome', 'Shades of gray only'),
    AppStyle('soft', 'Soft', 'Extra-round corners'),
    AppStyle('brutalist', 'Brutalist', 'Square corners, thick outlines, high contrast'),
    AppStyle('terminal', 'Terminal', 'Green on black, monospace (always dark)'),
  ];

  /// Styles that ignore light/dark and the color choice.
  static bool fixedColors(String style) => style == 'terminal' || style == 'monochrome';
  static bool alwaysDark(String style) => style == 'terminal';

  static ThemeData lightTheme({String? fontFamily, Color? seedColor, String style = defaultStyle}) =>
      _theme(alwaysDark(style) ? Brightness.dark : Brightness.light,
          fontFamily: fontFamily, seedColor: seedColor, style: style);

  static ThemeData darkTheme({String? fontFamily, Color? seedColor, String style = defaultStyle}) =>
      _theme(Brightness.dark, fontFamily: fontFamily, seedColor: seedColor, style: style);

  static ThemeData _theme(Brightness brightness,
      {String? fontFamily, Color? seedColor, required String style}) {
    final seed = seedColor ?? defaultColor;
    ColorScheme scheme(DynamicSchemeVariant variant, {double contrast = 0}) => ColorScheme.fromSeed(
        seedColor: seed, brightness: brightness, dynamicSchemeVariant: variant, contrastLevel: contrast);

    switch (style) {
      case 'vibrant':
        return _base(scheme(DynamicSchemeVariant.vibrant), fontFamily);
      case 'fruit_salad':
        return _base(scheme(DynamicSchemeVariant.fruitSalad), fontFamily);
      case 'monochrome':
        return _base(scheme(DynamicSchemeVariant.monochrome), fontFamily);
      case 'soft':
        return _shaped(_base(scheme(DynamicSchemeVariant.tonalSpot), fontFamily), radius: 28);
      case 'brutalist':
        final s = scheme(DynamicSchemeVariant.fidelity, contrast: 1);
        return _shaped(_base(s, fontFamily), radius: 0, side: BorderSide(color: s.onSurface, width: 2), flat: true);
      case 'terminal':
        return _terminal(fontFamily);
      default:
        return _base(scheme(DynamicSchemeVariant.tonalSpot), fontFamily);
    }
  }

  // Text fields are outlined unless a field asks for an underline; the
  // shaped styles round (or square) the outline.
  static const _inputTheme = InputDecorationThemeData(border: OutlineInputBorder());

  static ThemeData _base(ColorScheme scheme, String? fontFamily) =>
      ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: fontFamily, inputDecorationTheme: _inputTheme);

  static ThemeData _terminal(String? fontFamily) {
    const green = Color(0xFF33FF66);
    const dimGreen = Color(0xFF1FA344);
    const black = Color(0xFF000000);
    const panel = Color(0xFF0A140C);
    final scheme = ColorScheme.fromSeed(seedColor: green, brightness: Brightness.dark).copyWith(
      primary: green,
      onPrimary: black,
      primaryContainer: const Color(0xFF0F3D1A),
      onPrimaryContainer: green,
      secondary: dimGreen,
      onSecondary: black,
      secondaryContainer: const Color(0xFF0F2A16),
      onSecondaryContainer: green,
      tertiary: const Color(0xFFFFC233), // amber, the other terminal color
      onTertiary: black,
      tertiaryContainer: const Color(0xFF3D2E00),
      onTertiaryContainer: const Color(0xFFFFC233),
      surface: black,
      onSurface: green,
      onSurfaceVariant: dimGreen,
      surfaceContainerLowest: black,
      surfaceContainerLow: panel,
      surfaceContainer: panel,
      surfaceContainerHigh: const Color(0xFF0E1C11),
      surfaceContainerHighest: const Color(0xFF132617),
      outline: dimGreen,
      outlineVariant: const Color(0xFF145226),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: fontFamily ?? 'Inconsolata',
        scaffoldBackgroundColor: black, inputDecorationTheme: _inputTheme);
    return _shaped(base, radius: 0, side: const BorderSide(color: dimGreen), flat: true);
  }

  /// Same corner radius (and optional outline) on every common component.
  /// [flat] drops shadows.
  static ThemeData _shaped(ThemeData t, {required double radius, BorderSide? side, bool flat = false}) {
    final r = BorderRadius.circular(radius);
    final shape = RoundedRectangleBorder(borderRadius: r, side: side ?? BorderSide.none);
    final buttonShape = WidgetStatePropertyAll<OutlinedBorder>(RoundedRectangleBorder(borderRadius: r));
    final outlinedButtonShape = WidgetStatePropertyAll<OutlinedBorder>(RoundedRectangleBorder(borderRadius: r));
    final elevation = flat ? const WidgetStatePropertyAll<double>(0) : null;
    final inputBorder = OutlineInputBorder(borderRadius: r);
    return t.copyWith(
      cardTheme: CardThemeData(shape: shape, elevation: flat ? 0 : null),
      dialogTheme: DialogThemeData(shape: shape),
      bottomSheetTheme: BottomSheetThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(radius)))),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: r, side: side ?? BorderSide.none)),
      filledButtonTheme: FilledButtonThemeData(style: ButtonStyle(shape: buttonShape, elevation: elevation)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ButtonStyle(shape: buttonShape, elevation: elevation)),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
              shape: outlinedButtonShape,
              side: side == null ? null : WidgetStatePropertyAll(side))),
      textButtonTheme: TextButtonThemeData(style: ButtonStyle(shape: buttonShape)),
      segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
              shape: outlinedButtonShape,
              side: side == null ? null : WidgetStatePropertyAll(side))),
      floatingActionButtonTheme:
          FloatingActionButtonThemeData(shape: shape, elevation: flat ? 0 : null, highlightElevation: flat ? 0 : null),
      inputDecorationTheme: InputDecorationThemeData(
          border: inputBorder,
          enabledBorder: side == null ? null : inputBorder.copyWith(borderSide: side)),
      navigationDrawerTheme: NavigationDrawerThemeData(indicatorShape: RoundedRectangleBorder(borderRadius: r)),
      drawerTheme: radius == 0 ? const DrawerThemeData(shape: RoundedRectangleBorder()) : null,
      snackBarTheme: SnackBarThemeData(shape: shape, behavior: SnackBarBehavior.floating),
      appBarTheme: flat
          ? AppBarTheme(
              scrolledUnderElevation: 0,
              shape: side == null ? null : Border(bottom: side),
            )
          : null,
      popupMenuTheme: PopupMenuThemeData(shape: shape),
    );
  }

  // Section colors for scouting phases
  static const autoColor = Color(0xFF1565C0); // Blue
  static const teleopColor = Color(0xFF2E7D32); // Green
  static const teleopInactiveColor = Color(0xFFE65100); // Orange
  static const endgameColor = Color(0xFFC62828); // Red
}
