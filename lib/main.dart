import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/app_state_provider.dart';
import 'providers/scouting_provider.dart';
import 'providers/pit_provider.dart';

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
      ],
      child: const App(),
    ),
  );
}
