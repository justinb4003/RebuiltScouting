import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pick_list.dart';
import '../providers/app_state_provider.dart';
import '../providers/pick_list_provider.dart';

String teamLabel(BuildContext context, int teamNumber) {
  final teams = context.read<AppStateProvider>().teams;
  for (final t in teams) {
    if (t.teamNumber == teamNumber && t.nickname.isNotEmpty) {
      return '$teamNumber · ${t.nickname}';
    }
  }
  return '$teamNumber';
}

/// Send a pick list change and tell the user if it didn't stick.
Future<void> sendPickListUpdate(BuildContext context, PickListUpdate u) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await context.read<PickListProvider>().update(u);
  if (!ok) {
    messenger.showSnackBar(const SnackBar(
      content: Text('Pick list change not saved — check your connection'),
    ));
  }
}

Future<void> showPickListTeamSheet(BuildContext context, int teamNumber) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PickListTeamSheet(teamNumber: teamNumber),
  );
}

class _PickListTeamSheet extends StatefulWidget {
  final int teamNumber;

  const _PickListTeamSheet({required this.teamNumber});

  @override
  State<_PickListTeamSheet> createState() => _PickListTeamSheetState();
}

class _PickListTeamSheetState extends State<_PickListTeamSheet> {
  late final TextEditingController _notes;
  late String _savedNotes;

  @override
  void initState() {
    super.initState();
    _savedNotes = context
            .read<PickListProvider>()
            .list
            .entryFor(widget.teamNumber)
            ?.notes ??
        '';
    _notes = TextEditingController(text: _savedNotes);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _send(PickListUpdate u) => sendPickListUpdate(context, u);

  @override
  Widget build(BuildContext context) {
    final list = context.watch<PickListProvider>().list;
    final entry = list.entryFor(widget.teamNumber);
    final status = entry?.status ?? PickStatus.unranked;
    final rankedCount = list.ranked.length;
    final rank = entry?.isRanked == true ? entry!.ranking! : null;
    final tn = widget.teamNumber;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(teamLabel(context, tn), style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          SegmentedButton<PickStatus>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: PickStatus.ranked, label: Text('Pick')),
              ButtonSegment(value: PickStatus.unranked, label: Text('Unranked')),
              ButtonSegment(value: PickStatus.decline, label: Text('Decline')),
              ButtonSegment(value: PickStatus.dnp, label: Text('DNP')),
            ],
            selected: {status},
            onSelectionChanged: (s) {
              final next = s.first;
              if (next == PickStatus.ranked) {
                _send(PickListUpdate(tn, position: rankedCount + 1));
              } else {
                _send(PickListUpdate(tn, status: next));
              }
            },
          ),
          if (rank != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Pick #$rank of $rankedCount',
                    style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: 'Move to top',
                  icon: const Icon(Icons.vertical_align_top),
                  onPressed: rank > 1
                      ? () => _send(PickListUpdate(tn, position: 1))
                      : null,
                ),
                IconButton(
                  tooltip: 'Move up',
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: rank > 1
                      ? () => _send(PickListUpdate(tn, position: rank - 1))
                      : null,
                ),
                IconButton(
                  tooltip: 'Move down',
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: rank < rankedCount
                      ? () => _send(PickListUpdate(tn, position: rank + 1))
                      : null,
                ),
                IconButton(
                  tooltip: 'Move to bottom',
                  icon: const Icon(Icons.vertical_align_bottom),
                  onPressed: rank < rankedCount
                      ? () => _send(PickListUpdate(tn, position: rankedCount))
                      : null,
                ),
              ],
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Taken by another alliance'),
            value: entry?.picked ?? false,
            onChanged: (v) => _send(PickListUpdate(tn, picked: v)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _notes.text.trim() == _savedNotes
                  ? null
                  : () {
                      _savedNotes = _notes.text.trim();
                      _send(PickListUpdate(tn, notes: _savedNotes));
                      setState(() {});
                    },
              child: const Text('Save notes'),
            ),
          ),
        ],
      ),
    );
  }
}
