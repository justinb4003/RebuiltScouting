import 'package:flutter/material.dart';

import '../widgets/team_guess_game.dart';

/// Name That Team: a team number, pick its name out of three.
class NameThatTeamScreen extends StatelessWidget {
  const NameThatTeamScreen({super.key});

  @override
  Widget build(BuildContext context) => TeamGuessGame(
        gameId: 'name-that-team',
        title: 'Name That Team',
        navIndex: 14,
        rules: 'A team number comes up with three team names. Pick the '
            'right one before time runs out.',
        answers: (appState) => appState.teams
            .where((t) => t.nickname.trim().isNotEmpty)
            .toList(),
        optionText: (team) => team.nickname,
        prompt: (context, round) => Text(
          '${round.answer.teamNumber}',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .displayLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      );
}
