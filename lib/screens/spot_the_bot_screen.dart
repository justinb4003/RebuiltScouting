import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tba_team.dart';
import '../providers/app_state_provider.dart';
import '../widgets/team_guess_game.dart';

/// Share of the event's teams that need a pit photo before the game opens.
const _photoShareNeeded = 0.75;

/// Spot The Bot: a pit photo, pick the team out of three.
class SpotTheBotScreen extends StatefulWidget {
  const SpotTheBotScreen({super.key});

  @override
  State<SpotTheBotScreen> createState() => _SpotTheBotScreenState();
}

class _SpotTheBotScreenState extends State<SpotTheBotScreen> {
  final _rng = Random();

  // Photos loaded this session, kept in the image cache so they're never
  // evicted and fetched again mid-game; and photos that wouldn't load.
  static final Map<String, ImageStreamCompleterHandle> _kept = {};
  static final Set<String> _failed = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<AppStateProvider>().ensurePitResultsLoaded());
  }

  /// Photo URLs per team number, from every pit report at the event.
  Map<int, List<String>> _photos(AppStateProvider appState) {
    final photos = <int, List<String>>{};
    for (final r in appState.pitResults) {
      if (r.imageUrls.isEmpty) continue;
      photos.putIfAbsent(r.teamNumber, () => []).addAll(r.imageUrls);
    }
    return photos;
  }

  List<TbaTeam> _withPhotos(AppStateProvider appState) {
    final photos = _photos(appState);
    return appState.teams
        .where((t) => photos.containsKey(t.teamNumber))
        .toList();
  }

  /// Loads every photo before the game starts, a few at a time.
  Future<void> _preload(
      BuildContext context, void Function(int done, int total) progress) async {
    final appState = context.read<AppStateProvider>();
    final teams = {for (final t in _withPhotos(appState)) t.teamNumber};
    final urls = <String>{
      for (final e in _photos(appState).entries)
        if (teams.contains(e.key)) ...e.value,
    }.toList();
    final config = createLocalImageConfiguration(context);
    var done = 0;
    progress(0, urls.length);
    final queue = urls.toList();
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        await _load(queue.removeLast(), config);
        progress(++done, urls.length);
      }
    }

    await Future.wait([for (var i = 0; i < 6; i++) worker()]);
  }

  Future<void> _load(String url, ImageConfiguration config) async {
    if (_kept.containsKey(url) || _failed.contains(url)) return;
    final loaded = Completer<bool>();
    final stream = _image(url).resolve(config);
    final listener = ImageStreamListener(
      (info, _) {
        info.dispose();
        if (!loaded.isCompleted) loaded.complete(true);
      },
      onError: (_, _) {
        if (!loaded.isCompleted) loaded.complete(false);
      },
    );
    stream.addListener(listener);
    final ok = await loaded.future
        .timeout(const Duration(seconds: 20), onTimeout: () => false);
    if (ok && stream.completer != null) {
      _kept[url] = stream.completer!.keepAlive();
    } else {
      _failed.add(url);
    }
    stream.removeListener(listener);
  }

  // The photo host sends no CORS headers, so decode via a plain <img>
  // element on web (same as Team Details).
  ImageProvider _image(String url) => NetworkImage(url,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer);

  @override
  Widget build(BuildContext context) => TeamGuessGame(
        gameId: 'spot-the-bot',
        expandPrompt: true,
        title: 'Spot The Bot',
        navIndex: 15,
        rules: 'A robot photo from pit scouting comes up with three teams. '
            'Pick the right one before time runs out.',
        blocker: (appState) {
          final total = appState.teams.length;
          final have = _withPhotos(appState).length;
          if (total > 0 && have >= (total * _photoShareNeeded).ceil()) {
            return null;
          }
          return 'Spot The Bot opens once '
              '${(_photoShareNeeded * 100).round()}% of the teams here have '
              'a pit report with a photo.\n\n$have of $total so far.';
        },
        answers: _withPhotos,
        optionText: (team) => '${team.teamNumber}  ${team.nickname}',
        preload: _preload,
        preloadLabel: 'robot photos',
        // Only photos the preload got; a team whose photos all failed is
        // skipped.
        prepare: (context, team) async {
          final urls = _photos(context.read<AppStateProvider>())[team.teamNumber]
              ?.where(_kept.containsKey)
              .toList();
          if (urls == null || urls.isEmpty) return null;
          return urls[_rng.nextInt(urls.length)];
        },
        // Fills the height the game leaves for it, keeping the photo's shape.
        prompt: (context, round) => Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image(
              // A new widget per photo: without it the old photo stayed up.
              key: ValueKey(round.extra),
              image: _image(round.extra!),
              semanticLabel: 'Robot photo from pit scouting',
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
}
