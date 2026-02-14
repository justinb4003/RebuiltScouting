import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/scout_match_screen.dart';
import 'screens/scout_pit_screen.dart';
import 'screens/held_data_screen.dart';
import 'screens/settings_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FRC Scouting',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: '/scout',
      routes: {
        '/scout': (context) => const ScoutMatchScreen(),
        '/pit': (context) => const ScoutPitScreen(),
        '/held': (context) => const HeldDataScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
