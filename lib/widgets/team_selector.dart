import 'package:flutter/material.dart';
import '../models/tba_team.dart';

class TeamSelector extends StatelessWidget {
  final List<TbaTeam> teams;
  final int? selectedTeamNumber;
  final ValueChanged<int?> onChanged;

  const TeamSelector({
    super.key,
    required this.teams,
    required this.selectedTeamNumber,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) {
      return const Text('No teams loaded. Go to Settings to load teams.');
    }

    return DropdownMenu<int>(
      label: const Text('Team'),
      expandedInsets: EdgeInsets.zero,
      enableFilter: true,
      enableSearch: true,
      initialSelection: selectedTeamNumber,
      onSelected: onChanged,
      dropdownMenuEntries: teams
          .map((t) => DropdownMenuEntry<int>(
                value: t.teamNumber,
                label: '${t.teamNumber} - ${t.nickname}',
              ))
          .toList(),
    );
  }
}
