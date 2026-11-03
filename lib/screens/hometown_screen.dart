import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tba_team.dart';
import '../models/team_location.dart';
import '../providers/app_state_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/hometown_map.dart';
import '../widgets/team_guess_game.dart';

/// One color per choice, matched by its dot on the map.
const _choiceColors = [
  Color(0xFF1E88E5), // blue
  Color(0xFFF4511E), // orange
  Color(0xFF8E24AA), // purple
];

/// Wrong choices are at least this far from the answer and each other,
/// when the event's teams are spread out enough, so the dots don't overlap.
const _minSpacingKm = 25.0;

double _km(TeamLocation a, TeamLocation b) {
  const r = 6371.0;
  final dLat = (b.lat! - a.lat!) * pi / 180;
  final dLng = (b.lng! - a.lng!) * pi / 180;
  final h = pow(sin(dLat / 2), 2) +
      cos(a.lat! * pi / 180) * cos(b.lat! * pi / 180) * pow(sin(dLng / 2), 2);
  return 2 * r * asin(sqrt(h));
}

/// Hometown: a team, pick where it's from out of three places on a map.
class HometownScreen extends StatefulWidget {
  const HometownScreen({super.key});

  @override
  State<HometownScreen> createState() => _HometownScreenState();
}

class _HometownScreenState extends State<HometownScreen> {
  // Fetched from the API at most once per event per app session.
  static final Set<String> _fetched = {};

  String? _eventKey;
  TeamLocations? _locations;
  bool _loading = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final key = context.watch<AppStateProvider>().settings.selectedEventKey;
    if (key != null && key != _eventKey) {
      _eventKey = key;
      _load(key);
    }
  }

  Future<void> _load(String eventKey) async {
    setState(() {
      _locations = null;
      _error = null;
      _loading = true;
    });
    final cached =
        await StorageService.instance.loadCachedTeamLocations(eventKey);
    if (!mounted || eventKey != _eventKey) return;
    if (cached != null) setState(() => _locations = cached);
    if (cached != null && _fetched.contains(eventKey)) {
      setState(() => _loading = false);
      return;
    }
    try {
      final fresh = await ApiService.instance.getTeamLocations(eventKey);
      _fetched.add(eventKey);
      await StorageService.instance.cacheTeamLocations(eventKey, fresh);
      if (!mounted || eventKey != _eventKey) return;
      setState(() => _locations = fresh);
    } catch (e) {
      if (!mounted || eventKey != _eventKey) return;
      if (cached == null) setState(() => _error = 'Couldn\'t load where the teams are from.');
    }
    if (mounted && eventKey == _eventKey) setState(() => _loading = false);
  }

  Map<int, TeamLocation> get _placed => {
        for (final t in _locations?.teams ?? <TeamLocation>[])
          if (t.placed) t.teamNumber: t,
      };

  @override
  Widget build(BuildContext context) {
    final placed = _placed;
    final places = placed.values.map((t) => t.label).toSet();
    List<TbaTeam> located(AppStateProvider appState) => appState.teams
        .where((t) => placed.containsKey(t.teamNumber))
        .toList();

    return TeamGuessGame(
      gameId: 'hometown',
      title: 'Hometown',
      navIndex: 16,
      rules: 'A team comes up with three places on the map. Pick where '
          'it\'s from before time runs out, then see where it is and '
          'press Next.',
      blocker: (_) {
        if (_locations == null) {
          return _error ?? (_loading ? 'Finding where the teams are from…' : 'Loading…');
        }
        if (places.length < 3) {
          return 'Hometown needs teams from at least three different places '
              '(US and Canada only).';
        }
        return null;
      },
      answers: located,
      decoys: located,
      decoyFilter: (candidate, chosen) => chosen.every((t) =>
          _km(placed[candidate.teamNumber]!, placed[t.teamNumber]!) >=
          _minSpacingKm),
      optionText: (team) => placed[team.teamNumber]?.label ?? '',
      optionLeading: (i) => Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: _choiceColors[i],
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
      nextButton: true,
      prompt: (context, round) {
        final theme = Theme.of(context);
        return Column(
          children: [
            Text(
              '${round.answer.teamNumber}',
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(round.answer.nickname,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: HometownMap(
                homeState: _locations?.eventState,
                points: [
                  for (var i = 0; i < round.options.length; i++)
                    MapPoint(
                      placed[round.options[i].teamNumber]!.lat!,
                      placed[round.options[i].teamNumber]!.lng!,
                      _choiceColors[i],
                      placed[round.options[i].teamNumber]!.label,
                    ),
                ],
                answer: round.options.indexOf(round.answer),
                revealed: round.revealed,
              ),
            ),
          ],
        );
      },
    );
  }
}
