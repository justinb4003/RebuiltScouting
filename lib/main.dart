import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/app_state_provider.dart';
import 'providers/scouting_provider.dart';
import 'providers/pit_provider.dart';
import 'providers/pick_list_provider.dart';
import 'providers/pick_board_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/rankings_provider.dart';
import 'providers/event_data_provider.dart';
import 'providers/cluster_provider.dart';
import 'services/browser.dart';
import 'services/storage_service.dart';
import 'services/upload_queue.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Held scouting data lives in localStorage; ask the browser to keep it.
  requestPersistentStorage().then((granted) {
    debugPrint('Persistent storage ${granted ? 'granted' : 'not granted'}');
  });

  // Before anything else touches held data (the queue starts below).
  await StorageService.instance.migrateHeldPhotos();

  final appState = AppStateProvider();
  await appState.init();
  // Upload anything held from last time, then keep watching (see UploadQueue).
  UploadQueue.instance.start();
  // Pick up the team's published cluster settings early (no clustering yet).
  final clusters = ClusterProvider();
  clusters.ensureLoaded(
    eventKey: appState.settings.selectedEventKey,
    secretKey: appState.settings.secretTeamKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: UploadQueue.instance),
        ChangeNotifierProvider(create: (_) => ScoutingProvider()),
        ChangeNotifierProvider(create: (_) => PitProvider()),
        ChangeNotifierProvider(create: (_) => PickListProvider()),
        ChangeNotifierProvider(create: (_) => PickBoardProvider()),
        ChangeNotifierProvider(create: (_) => RankingsProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProvider(create: (_) => EventDataProvider()),
        ChangeNotifierProvider.value(value: clusters),
      ],
      child: const App(),
    ),
  );
}
