import 'package:flutter/material.dart';
import '../models/tba_team.dart';

class TeamSelector extends StatefulWidget {
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
  State<TeamSelector> createState() => _TeamSelectorState();
}

class _TeamSelectorState extends State<TeamSelector> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _labelForTeam(widget.selectedTeamNumber));
  }

  @override
  void didUpdateWidget(TeamSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync controller when selection changes externally (e.g. form reset)
    if (widget.selectedTeamNumber != oldWidget.selectedTeamNumber) {
      _controller.text = _labelForTeam(widget.selectedTeamNumber);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _labelForTeam(int? teamNumber) {
    if (teamNumber == null) return '';
    final match = widget.teams.where((t) => t.teamNumber == teamNumber);
    if (match.isNotEmpty) {
      return '${match.first.teamNumber} - ${match.first.nickname}';
    }
    return '$teamNumber';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.teams.isEmpty) {
      return const Text('No teams loaded. Go to Settings to load teams.');
    }

    return RawAutocomplete<TbaTeam>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return widget.teams;
        return widget.teams.where((t) =>
            t.teamNumber.toString().contains(query) ||
            t.nickname.toLowerCase().contains(query));
      },
      displayStringForOption: (t) => '${t.teamNumber} - ${t.nickname}',
      onSelected: (team) {
        widget.onChanged(team.teamNumber);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Team',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.groups),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      widget.onChanged(null);
                    },
                  )
                : null,
          ),
          onChanged: (v) {
            // If user clears the field, deselect
            if (v.trim().isEmpty) {
              widget.onChanged(null);
            }
          },
          onTap: () {
            // Select all text on tap so typing replaces it
            if (controller.text.isNotEmpty) {
              controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: controller.text.length,
              );
            }
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final team = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text('${team.teamNumber} - ${team.nickname}'),
                    onTap: () => onSelected(team),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
