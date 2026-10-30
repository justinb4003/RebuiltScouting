import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pick_list.dart';
import '../providers/app_state_provider.dart';
import '../providers/pick_list_provider.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/pick_list_team_sheet.dart';

const _sectionOrder = [
  PickStatus.ranked,
  PickStatus.unranked,
  PickStatus.decline,
  PickStatus.dnp,
];

const _sectionTitles = {
  PickStatus.ranked: 'Pick Order',
  PickStatus.unranked: 'Unranked',
  PickStatus.decline: 'Decline',
  PickStatus.dnp: 'Do Not Pick',
};

sealed class _Row {
  Key get key;
}

class _Header extends _Row {
  final PickStatus section;
  final int count;
  _Header(this.section, this.count);
  @override
  Key get key => ValueKey('header-${section.name}');
}

class _Placeholder extends _Row {
  final PickStatus section;
  _Placeholder(this.section);
  @override
  Key get key => ValueKey('empty-${section.name}');
}

class _TeamRow extends _Row {
  final int teamNumber;
  final PickListEntry? entry;
  final PickStatus section;
  _TeamRow(this.teamNumber, this.entry, this.section);
  @override
  Key get key => ValueKey('team-$teamNumber');
}

class PickListScreen extends StatefulWidget {
  const PickListScreen({super.key});

  @override
  State<PickListScreen> createState() => _PickListScreenState();
}

class _PickListScreenState extends State<PickListScreen> {
  late final PickListProvider _pickList;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pickList = context.read<PickListProvider>();
    _pickList.watch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<AppStateProvider>().settings;
      _pickList.configure(
        secretKey: settings.secretTeamKey,
        eventKey: settings.selectedEventKey ?? '',
        scouterName: settings.scouterName,
      );
    });
  }

  @override
  void dispose() {
    _pickList.unwatch();
    _search.dispose();
    super.dispose();
  }

  List<_Row> _buildRows(PickList list, List<int> eventTeams) {
    final bySection = {for (final s in _sectionOrder) s: <_TeamRow>[]};
    final seen = <int>{};
    for (final e in list.ranked) {
      bySection[PickStatus.ranked]!.add(_TeamRow(e.teamNumber, e, PickStatus.ranked));
      seen.add(e.teamNumber);
    }
    final others = {...eventTeams, ...list.teams.map((t) => t.teamNumber)}
        .where((t) => !seen.contains(t))
        .toList()
      ..sort();
    for (final tn in others) {
      final entry = list.entryFor(tn);
      final status = entry?.status ?? PickStatus.unranked;
      bySection[status]!.add(_TeamRow(tn, entry, status));
    }
    return [
      for (final s in _sectionOrder) ...[
        _Header(s, bySection[s]!.length),
        if (bySection[s]!.isEmpty) _Placeholder(s),
        ...bySection[s]!,
      ],
    ];
  }

  /// [newIndex] is the moved row's index after removal (onReorderItem).
  void _onReorder(List<_Row> rows, int oldIndex, int newIndex) {
    final moved = rows[oldIndex];
    if (moved is! _TeamRow) return;
    final next = [...rows]
      ..removeAt(oldIndex)
      ..insert(newIndex, moved);
    // The drop lands in the section of the nearest header above it.
    var section = PickStatus.ranked;
    var position = 1;
    for (var i = newIndex - 1; i >= 0; i--) {
      final r = next[i];
      if (r is _Header) {
        section = r.section;
        break;
      }
      if (r is _TeamRow) position++;
    }
    final tn = moved.teamNumber;
    if (section == PickStatus.ranked) {
      if (moved.entry?.isRanked == true && moved.entry!.ranking == position) {
        return;
      }
      sendPickListUpdate(context, PickListUpdate(tn, position: position));
    } else if (section != moved.section) {
      sendPickListUpdate(context, PickListUpdate(tn, status: section));
    }
  }

  Widget _syncIndicator(PickListProvider p) {
    final theme = Theme.of(context);
    final (IconData icon, String label, Color color) = p.hasPending
        ? (Icons.cloud_upload_outlined, 'Saving', theme.colorScheme.onSurfaceVariant)
        : switch (p.sync) {
            PickListSync.live => (Icons.cloud_done, 'Live', const Color(0xFF0CA30C)),
            PickListSync.offline => (Icons.cloud_off, 'Offline', const Color(0xFFD03B3B)),
            PickListSync.idle => (Icons.cloud_queue, 'Connecting', theme.colorScheme.onSurfaceVariant),
          };
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }

  Widget _lastChange(PickList list) {
    if (list.updatedAt == null) return const SizedBox.shrink();
    final t = TimeOfDay.fromDateTime(list.updatedAt!.toLocal()).format(context);
    final who = list.updatedBy.isEmpty ? '' : ' by ${list.updatedBy}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Text('Last change$who at $t',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }

  Widget _rankBadge(_TeamRow row) {
    final scheme = Theme.of(context).colorScheme;
    return switch (row.section) {
      PickStatus.ranked => CircleAvatar(
          radius: 16,
          backgroundColor: scheme.primaryContainer,
          child: Text('${row.entry!.ranking}',
              style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold)),
        ),
      PickStatus.dnp => Icon(Icons.block, color: scheme.error),
      PickStatus.decline => Icon(Icons.do_not_disturb_on_outlined,
          color: scheme.onSurfaceVariant),
      PickStatus.unranked => const SizedBox(width: 32),
    };
  }

  Widget _teamTile(_TeamRow row, {int? dragIndex}) {
    final picked = row.entry?.picked ?? false;
    final notes = row.entry?.notes ?? '';
    final tile = ListTile(
      dense: true,
      leading: _rankBadge(row),
      title: Text(
        teamLabel(context, row.teamNumber),
        style: picked
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: notes.isEmpty
          ? (dragIndex == null ? Text(_sectionTitles[row.section]!) : null)
          : Text(notes, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => showPickListTeamSheet(context, row.teamNumber),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (row.section == PickStatus.ranked)
            IconButton(
              tooltip: picked ? 'Mark available' : 'Mark taken',
              icon: Icon(picked
                  ? Icons.check_box
                  : Icons.check_box_outline_blank),
              onPressed: () => sendPickListUpdate(
                  context, PickListUpdate(row.teamNumber, picked: !picked)),
            ),
          if (dragIndex != null)
            ReorderableDragStartListener(
              index: dragIndex,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.drag_handle),
              ),
            ),
        ],
      ),
    );
    return KeyedSubtree(
      key: row.key,
      child: picked ? Opacity(opacity: 0.5, child: tile) : tile,
    );
  }

  Widget _buildRow(_Row row, int index) {
    final theme = Theme.of(context);
    return switch (row) {
      _Header(:final section, :final count) => Padding(
          key: row.key,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Text(_sectionTitles[section]!,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text('$count', style: theme.textTheme.bodySmall),
              const SizedBox(width: 8),
              const Expanded(child: Divider()),
            ],
          ),
        ),
      _Placeholder() => Padding(
          key: row.key,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text('Drag teams here',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
      _TeamRow() => _teamTile(row, dragIndex: index),
    };
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final pickList = context.watch<PickListProvider>();
    final settings = appState.settings;
    final configured = settings.secretTeamKey.trim().isNotEmpty &&
        (settings.selectedEventKey ?? '').isNotEmpty;
    final list = pickList.list;
    final rows =
        _buildRows(list, appState.teams.map((t) => t.teamNumber).toList());
    final query = _search.text.trim().toLowerCase();

    Widget body;
    if (!configured) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Set a secret team key and event in Settings to use '
              'the shared pick list.', textAlign: TextAlign.center),
        ),
      );
    } else if (query.isNotEmpty) {
      final matches = rows
          .whereType<_TeamRow>()
          .where((r) =>
              teamLabel(context, r.teamNumber).toLowerCase().contains(query))
          .toList();
      body = ListView(children: [for (final r in matches) _teamTile(r)]);
    } else {
      body = ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: rows.length,
        onReorderStart: (_) => pickList.holdUpdates(true),
        onReorderEnd: (_) => pickList.holdUpdates(false),
        onReorderItem: (o, n) => _onReorder(rows, o, n),
        itemBuilder: (context, i) => _buildRow(rows[i], i),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick List'),
        actions: [if (configured) _syncIndicator(pickList)],
      ),
      drawer: const NavDrawer(selectedIndex: 8),
      body: Column(
        children: [
          if (configured && !pickList.loaded) const LinearProgressIndicator(),
          if (configured) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Find team',
                  border: const OutlineInputBorder(),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(_search.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            _lastChange(list),
          ],
          Expanded(child: body),
        ],
      ),
    );
  }
}
