import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'providers/app_state_provider.dart';
import 'screens/scout_match_screen.dart';
import 'screens/scout_pit_screen.dart';
import 'screens/held_data_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/scouting_status_screen.dart';
import 'screens/pit_status_screen.dart';
import 'screens/robot_note_screen.dart';
import 'screens/pick_list_screen.dart';
import 'screens/pick_board_screen.dart';
import 'screens/clusters_screen.dart';
import 'screens/rankings_screen.dart';
import 'screens/team_details_screen.dart';
import 'screens/match_breakdowns_screen.dart';
import 'screens/head_to_head_screen.dart';

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
      home: const SettingsScreen(),
      routes: {
        '/scout': (context) => const ScoutMatchScreen(),
        '/pit': (context) => const ScoutPitScreen(),
        '/held': (context) => const HeldDataScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/scouting-status': (context) => const ScoutingStatusScreen(),
        '/pit-status': (context) => const PitStatusScreen(),
        '/robot-note': (context) => const RobotNoteScreen(),
        '/pick-board': (context) => const PickBoardScreen(),
        '/pick-list': (context) => const PickListScreen(),
        '/clusters': (context) => const ClustersScreen(),
        '/rankings': (context) => const RankingsScreen(),
        '/team-details': (context) => const TeamDetailsScreen(),
        '/match-breakdowns': (context) => const MatchBreakdownsScreen(),
        '/head-to-head': (context) => const HeadToHeadScreen(),
      },
    );
  }
}
