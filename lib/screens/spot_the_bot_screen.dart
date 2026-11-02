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

  // The photo host sends no CORS headers, so decode via a plain <img>
  // element on web (same as Team Details).
  ImageProvider _image(String url) => NetworkImage(url,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer);

  @override
  Widget build(BuildContext context) => TeamGuessGame(
        gameId: 'spot-the-bot',
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
        prepare: (context, team) async {
          final urls = _photos(context.read<AppStateProvider>())[team.teamNumber];
          if (urls == null || urls.isEmpty) return null;
          final url = urls[_rng.nextInt(urls.length)];
          var failed = false;
          // Load it before the clock starts.
          await precacheImage(_image(url), context,
              onError: (_, _) => failed = true);
          return failed ? null : url;
        },
        prompt: (context, round) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image(
            image: _image(round.extra!),
            semanticLabel: 'Robot photo from pit scouting',
            // Leave room for the three choices without scrolling.
            height: (MediaQuery.sizeOf(context).height - 460).clamp(160, 400),
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
      );
}
