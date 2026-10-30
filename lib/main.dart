import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/app_state_provider.dart';
import 'providers/scouting_provider.dart';
import 'providers/pit_provider.dart';
import 'providers/pick_list_provider.dart';
import 'providers/pick_board_provider.dart';
import 'providers/rankings_provider.dart';
import 'providers/event_data_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appState = AppStateProvider();
  await appState.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider(create: (_) => ScoutingProvider()),
        ChangeNotifierProvider(create: (_) => PitProvider()),
        ChangeNotifierProvider(create: (_) => PickListProvider()),
        ChangeNotifierProvider(create: (_) => PickBoardProvider()),
        ChangeNotifierProvider(create: (_) => RankingsProvider()),
        ChangeNotifierProvider(create: (_) => EventDataProvider()),
      ],
      child: const App(),
    ),
  );
}
