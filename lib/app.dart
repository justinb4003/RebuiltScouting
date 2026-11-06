import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'providers/app_state_provider.dart';
import 'screens/scout_match_screen.dart';
import 'screens/scout_pit_screen.dart';
import 'screens/held_data_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/appearance_screen.dart';
import 'screens/scouting_status_screen.dart';
import 'screens/pit_status_screen.dart';
import 'screens/robot_note_screen.dart';
import 'screens/pick_board_screen.dart';
import 'screens/my_schedule_screen.dart';
import 'screens/schedule_builder_screen.dart';
import 'screens/clusters_screen.dart';
import 'screens/dimensions_screen.dart';
import 'screens/rankings_screen.dart';
import 'screens/team_details_screen.dart';
import 'screens/match_breakdowns_screen.dart';
import 'screens/head_to_head_screen.dart';
import 'screens/name_that_team_screen.dart';
import 'screens/spot_the_bot_screen.dart';
import 'screens/hometown_screen.dart';

/// Tells screens when another page covers them or they're uncovered, so
/// live screens (Pick List) can stop syncing while hidden underneath. On web
/// a URL change (typed URL, Back/Forward) pushes a page on top instead of
/// replacing it. Only page routes count: a dialog or bottom sheet over a
/// screen leaves it live.
final routeObserver = RouteObserver<PageRoute<dynamic>>();

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppStateProvider>().settings;
    final fontFamily =
        settings.useOpenDyslexic ? 'OpenDyslexic' : null;
    final seedColor = Color(settings.themeColor);
    final style = settings.themeStyle;
    final themeMode = switch (settings.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return MaterialApp(
      navigatorObservers: [routeObserver],
      title: 'FRC Scouting',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(fontFamily: fontFamily, seedColor: seedColor, style: style),
      darkTheme: AppTheme.darkTheme(fontFamily: fontFamily, seedColor: seedColor, style: style),
      themeMode: themeMode,
      home: const SettingsScreen(),
      routes: {
        '/scout': (context) => const ScoutMatchScreen(),
        '/pit': (context) => const ScoutPitScreen(),
        '/held': (context) => const HeldDataScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/appearance': (context) => const AppearanceScreen(),
        '/scouting-status': (context) => const ScoutingStatusScreen(),
        '/pit-status': (context) => const PitStatusScreen(),
        '/robot-note': (context) => const RobotNoteScreen(),
        '/my-schedule': (context) => const MyScheduleScreen(),
        '/schedule-builder': (context) => const ScheduleBuilderScreen(),
        '/pick-list': (context) => const PickBoardScreen(),
        '/clusters': (context) => const ClustersScreen(),
        '/dimensions': (context) => const DimensionsScreen(),
        '/rankings': (context) => const RankingsScreen(),
        '/team-details': (context) => const TeamDetailsScreen(),
        '/match-breakdowns': (context) => const MatchBreakdownsScreen(),
        '/head-to-head': (context) => const HeadToHeadScreen(),
        '/name-that-team': (context) => const NameThatTeamScreen(),
        '/spot-the-bot': (context) => const SpotTheBotScreen(),
        '/hometown': (context) => const HometownScreen(),
      },
    );
  }
}
