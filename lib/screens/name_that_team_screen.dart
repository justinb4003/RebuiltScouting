import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tba_team.dart';
import '../providers/app_state_provider.dart';
import '../widgets/game_scope.dart';
import '../widgets/team_guess_game.dart';

/// Name That Team: a team number, pick its name out of three. Plays with
/// the event's teams or every team in your team's state.
const _nothingToPlay = 'Pick an event in Settings, or add your team '
    'number there to play with every team in your state.';

class NameThatTeamScreen extends StatefulWidget {
  const NameThatTeamScreen({super.key});

  @override
  State<NameThatTeamScreen> createState() => _NameThatTeamScreenState();
}

class _NameThatTeamScreenState extends State<NameThatTeamScreen> {
  // The last scope picked, for this app session.
  static GameScope? _picked;
  final _stateTeams = StateTeamsLoader(locations: false);

  @override
  void initState() {
    super.initState();
    _stateTeams.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _stateTeams.removeListener(_changed);
    _stateTeams.dispose();
    super.dispose();
  }

  static List<TbaTeam> _named(Iterable<TbaTeam> teams) =>
      teams.where((t) => t.nickname.trim().isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppStateProvider>().settings;
    final eventAvailable = settings.selectedEventKey != null;
    final teamNumber = settings.teamNumber;
    final stateAvailable = teamNumber != null;
    final scope = !stateAvailable
        ? GameScope.event
        : !eventAvailable
            ? GameScope.state
            : (_picked ?? GameScope.event);
    final statewide = scope == GameScope.state;
    if (statewide) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _stateTeams.ensure(teamNumber!, settings.eventYear));
    }
    final data = statewide ? _stateTeams.data : null;
    final stateTeams = _named(data?.teams ?? const []);

    return TeamGuessGame(
      gameId: statewide ? 'name-that-team-state' : 'name-that-team',
      title: 'Name That Team',
      navIndex: 17,
      rules: 'A team number comes up with three team names. Pick the '
          'right one before time runs out, then press Next.',
      nextButton: true,
      lobbyHeader: GameScopePicker(
        scope: scope,
        eventAvailable: eventAvailable,
        stateAvailable: stateAvailable,
        state: _stateTeams.data?.state,
        onChanged: (s) => setState(() => _picked = s),
      ),
      needsEvent: !statewide && eventAvailable,
      scoreLabel: statewide ? data?.state : null,
      blocker: (_) {
        if (!eventAvailable && !stateAvailable) return _nothingToPlay;
        if (!statewide) return null;
        if (data == null) {
          return _stateTeams.error ??
              'Loading the teams in your team\'s state…';
        }
        if (stateTeams.length < 3) {
          return 'There aren\'t enough teams in ${data.state} for '
              'the ${data.year} season.';
        }
        return null;
      },
      answers: (appState) =>
          statewide ? stateTeams : _named(appState.teams),
      decoys: statewide ? (_) => stateTeams : null,
      optionText: (team) => team.nickname,
      prompt: (context, round) => Center(
        child: Text(
          '${round.answer.teamNumber}',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .displayLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
