import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'providers/app_state_provider.dart';
import 'screens/scout_match_screen.dart';
import 'screens/scout_pit_screen.dart';
import 'screens/held_data_screen.dart';
import 'screens/settings_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppStateProvider>().settings;
    final fontFamily =
        settings.useOpenDyslexic ? 'OpenDyslexic' : null;
    final seedColor = Color(settings.themeColor);
    final themeMode = switch (settings.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return MaterialApp(
      title: 'FRC Scouting',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(fontFamily: fontFamily, seedColor: seedColor),
      darkTheme: AppTheme.darkTheme(fontFamily: fontFamily, seedColor: seedColor),
      themeMode: themeMode,
      initialRoute: '/settings',
      routes: {
        '/scout': (context) => const ScoutMatchScreen(),
        '/pit': (context) => const ScoutPitScreen(),
        '/held': (context) => const HeldDataScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
