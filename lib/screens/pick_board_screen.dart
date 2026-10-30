import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pick_board.dart';
import '../models/pick_list.dart';
import '../providers/app_state_provider.dart';
import '../providers/pick_board_provider.dart';
import '../providers/pick_list_provider.dart' show PickListSync;
import '../widgets/nav_drawer.dart';
import '../widgets/pick_list_team_sheet.dart' show teamLabel;
import '../widgets/team_details.dart';

// Same focus blue as the cluster charts: the agreement bar fill.
const _focusLight = Color(0xFF2A78D6);
const _focusDark = Color(0xFF3987E5);

/// Width of each person's rank column on wide screens.
const _voterColumnWidth = 64.0;
const _agreementWidth = 160.0;

class PickBoardScreen extends StatefulWidget {
  const PickBoardScreen({super.key});

  @override
  State<PickBoardScreen> createState() => _PickBoardScreenState();
}

class _PickBoardScreenState extends State<PickBoardScreen> {
  late final PickBoardProvider _board;

  @override
  void initState() {
    super.initState();
    _board = context.read<PickBoardProvider>();
    _board.watch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<AppStateProvider>().settings;
      _board.configure(
        secretKey: settings.secretTeamKey,
        eventKey: settings.selectedEventKey ?? '',
        voter: settings.scouterName,
      );
    });
  }

  @override
  void dispose() {
    _board.unwatch();
    super.dispose();
  }

  Widget _syncIndicator(PickBoardProvider p) {
    final theme = Theme.of(context);
    final (IconData icon, String label, Color color) = p.hasPending
        ? (Icons.cloud_upload_outlined, 'Saving', theme.colorScheme.onSurfaceVariant)
        : switch (p.sync) {
            PickListSync.live when !p.pushLive =>
              (Icons.cloud_sync_outlined, 'Syncing', theme.colorScheme.onSurfaceVariant),
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppStateProvider>().settings;
    final p = context.watch<PickBoardProvider>();
    final hasEvent = settings.secretTeamKey.trim().isNotEmpty &&
        (settings.selectedEventKey ?? '').isNotEmpty;
    final hasName = voterKey(settings.scouterName).isNotEmpty;

    final message = !hasEvent
        ? 'Set a secret team key and event in Settings to use the pick board.'
        : !hasName
            ? 'Set your name in Settings. Your pick list is saved under it.'
            : null;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pick Board'),
          actions: [if (message == null) _syncIndicator(p)],
          bottom: message != null
              ? null
              : const TabBar(tabs: [Tab(text: 'Board'), Tab(text: 'My List')]),
        ),
        drawer: const NavDrawer(selectedIndex: 7),
        body: message != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(message, textAlign: TextAlign.center),
                ),
              )
            : Column(
                children: [
                  if (!p.loaded) const LinearProgressIndicator(),
                  const Expanded(
                    child: TabBarView(children: [_BoardView(), _MyListView()]),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Send one change to your own list; tell the user if it didn't stick.
Future<void> _vote(BuildContext context, PickListUpdate u) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await context.read<PickBoardProvider>().vote(u);
  if (!ok) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Pick list change not saved — check your connection')));
  }
}

Future<void> _setTaken(BuildContext context, int tn, bool taken) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await context.read<PickBoardProvider>().setTaken(tn, taken);
  if (!ok) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Taken flag not saved — check your connection')));
  }
}

int _eventTeamCount(BuildContext context) =>
    context.read<AppStateProvider>().teams.length;

// ---------------------------------------------------------------------------
// Board tab

class _BoardView extends StatefulWidget {
  const _BoardView();

  @override
  State<_BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<_BoardView> {
  // Session-sticky like the cluster controls.
  static bool _hideTaken = false;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PickBoardProvider>();
    final board = p.board;
    final voters = board.voters;
    final allRows = board.rows(_eventTeamCount(context));
    final rows =
        _hideTaken ? allRows.where((r) => !r.taken).toList() : allRows;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    if (voters.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            p.loaded
                ? 'Nobody has ranked anyone yet. Build your list in My List '
                    'and it shows up here for everyone.'
                : 'Loading…',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;
      final shownVoters = wide ? voters : const <Ballot>[];
      // Keep the agreement bar near the team names on big screens.
      final sidePad = math.max(0.0,
          (constraints.maxWidth - 700 - shownVoters.length * _voterColumnWidth) / 2);
      return ListView(
        padding: EdgeInsets.fromLTRB(sidePad, 0, sidePad, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${voters.length} ${voters.length == 1 ? 'person' : 'people'}: '
                  '${voters.map((b) => b.voter).join(', ')}',
                  style: theme.textTheme.bodyMedium,
                ),
                FilterChip(
                  label: Text('Hide taken (${board.taken.length})'),
                  selected: _hideTaken,
                  onSelected: (v) => setState(() => _hideTaken = v),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Text(
              'Row #1 is the team the most people put at #1 on their list, '
              '#2 the team the most put at #2, and so on; ties show every '
              'tied team. Agreement is the '
              'share of people who have it at that spot. Full bar: everyone '
              'agrees, move on to the next team.',
              style: muted,
            ),
          ),
          _BoardHeader(voters: shownVoters, myKey: p.myKey),
          for (final (i, row) in rows.indexed)
            _BoardRowTile(
              row: row,
              shownVoters: shownVoters,
              shaded: i.isOdd,
            ),
        ],
      );
    });
  }
}

class _BoardHeader extends StatelessWidget {
  final List<Ballot> voters;
  final String myKey;

  const _BoardHeader({required this.voters, required this.myKey});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text('#', style: style)),
          Expanded(child: Text('Team', style: style)),
          SizedBox(
              width: _agreementWidth,
              child: Text('Agreement', style: style, textAlign: TextAlign.center)),
          for (final b in voters)
            SizedBox(
              width: _voterColumnWidth,
              child: Text(
                b.voter,
                style: b.key == myKey
                    ? style?.copyWith(fontWeight: FontWeight.bold)
                    : style,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _BoardRowTile extends StatelessWidget {
  final BoardRow row;
  final List<Ballot> shownVoters;
  final bool shaded;

  const _BoardRowTile({
    required this.row,
    required this.shownVoters,
    required this.shaded,
  });

  String _rankText(Ballot b) {
    final r = row.ranks[b.key];
    if (r != null) return '#$r';
    return row.dnpBy.contains(b.key) ? 'DNP' : '—';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tn = row.teamNumber;
    final label = teamLabel(context, tn);
    final nickname = label.contains(' · ') ? label.split(' · ').last : '';
    final strike = row.taken
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;

    final badges = <Widget>[
      if (row.taken) _Badge(icon: Icons.check_box, label: 'Taken'),
      if (row.dnpBy.isNotEmpty)
        _Badge(
            icon: Icons.block,
            label: '${row.dnpBy.length} DNP',
            color: scheme.error),
    ];

    final tile = InkWell(
      onTap: () => showPickBoardTeamSheet(context, tn),
      child: Container(
        color: shaded ? scheme.surfaceContainerLow : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(row.agreedRank == null ? '' : '${row.agreedRank}',
                  style: theme.textTheme.bodyMedium),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: '$tn',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (nickname.isNotEmpty) TextSpan(text: '  $nickname'),
                    ]),
                    style: strike,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (badges.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Wrap(spacing: 8, runSpacing: 2, children: badges),
                    ),
                ],
              ),
            ),
            SizedBox(
                width: _agreementWidth, child: _AgreementBar(row.agreement)),
            for (final b in shownVoters)
              SizedBox(
                width: _voterColumnWidth,
                child: Text(
                  _rankText(b),
                  textAlign: TextAlign.end,
                  style: row.dnpBy.contains(b.key)
                      ? TextStyle(color: scheme.error)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
    return row.taken ? Opacity(opacity: 0.5, child: tile) : tile;
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _Badge({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 3),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: c)),
      ],
    );
  }
}

/// 0–100 agreement as a bar on a full-width track, value beside it.
class _AgreementBar extends StatelessWidget {
  final double? value;

  const _AgreementBar(this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final v = value;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.centerLeft,
            child: v == null
                ? null
                : FractionallySizedBox(
                    widthFactor: v / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: dark ? _focusDark : _focusLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            v == null ? '—' : '${v.round()}%',
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// My List tab: your own drag-and-drop order.

const _mySections = [PickStatus.ranked, PickStatus.unranked, PickStatus.dnp];

const _sectionTitles = {
  PickStatus.ranked: 'My Pick Order',
  PickStatus.unranked: 'Unranked',
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

class _MyListView extends StatefulWidget {
  const _MyListView();

  @override
  State<_MyListView> createState() => _MyListViewState();
}

class _MyListViewState extends State<_MyListView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_Row> _buildRows(PickList list, List<int> eventTeams) {
    final bySection = {for (final s in _mySections) s: <_TeamRow>[]};
    final seen = <int>{};
    for (final e in list.ranked) {
      bySection[PickStatus.ranked]!
          .add(_TeamRow(e.teamNumber, e, PickStatus.ranked));
      seen.add(e.teamNumber);
    }
    final others = {...eventTeams, ...list.teams.map((t) => t.teamNumber)}
        .where((t) => !seen.contains(t))
        .toList()
      ..sort();
    for (final tn in others) {
      final entry = list.entryFor(tn);
      final status = entry?.dnp == true ? PickStatus.dnp : PickStatus.unranked;
      bySection[status]!.add(_TeamRow(tn, entry, status));
    }
    return [
      for (final s in _mySections) ...[
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
      _vote(context, PickListUpdate(tn, position: position));
    } else if (section != moved.section) {
      _vote(context, PickListUpdate(tn, status: section));
    }
  }

  Widget _teamTile(_TeamRow row, Set<int> taken, Map<int, int> boardPos,
      {int? dragIndex}) {
    final scheme = Theme.of(context).colorScheme;
    final isTaken = taken.contains(row.teamNumber);
    final notes = row.entry?.notes ?? '';
    final pos = boardPos[row.teamNumber];
    final tile = ListTile(
      dense: true,
      leading: switch (row.section) {
        PickStatus.ranked => CircleAvatar(
            radius: 16,
            backgroundColor: scheme.primaryContainer,
            child: Text('${row.entry!.ranking}',
                style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold)),
          ),
        PickStatus.dnp => Icon(Icons.block, color: scheme.error),
        _ => const SizedBox(width: 32),
      },
      title: Text(
        teamLabel(context, row.teamNumber),
        style: isTaken
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: notes.isNotEmpty
          ? Text(notes, maxLines: 1, overflow: TextOverflow.ellipsis)
          : pos != null
              ? Text('Board #$pos')
              : null,
      onTap: () => showPickBoardTeamSheet(context, row.teamNumber),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (row.section == PickStatus.ranked)
            IconButton(
              tooltip: isTaken ? 'Mark available' : 'Mark taken',
              icon: Icon(
                  isTaken ? Icons.check_box : Icons.check_box_outline_blank),
              onPressed: () => _setTaken(context, row.teamNumber, !isTaken),
            ),
          if (dragIndex != null)
            ReorderableDragStartListener(
              index: dragIndex,
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.drag_handle),
              ),
            ),
        ],
      ),
    );
    final shown = isTaken ? Opacity(opacity: 0.5, child: tile) : tile;
    // The whole row drags: right away with a mouse, after a long press on
    // phones and tablets so a swipe still scrolls. A click still opens the
    // team sheet.
    final touch = switch (Theme.of(context).platform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
    return KeyedSubtree(
      key: row.key,
      child: dragIndex == null
          ? shown
          : touch
              ? ReorderableDelayedDragStartListener(
                  index: dragIndex, child: shown)
              : ReorderableDragStartListener(index: dragIndex, child: shown),
    );
  }

  Widget _buildRow(
      _Row row, int index, Set<int> taken, Map<int, int> boardPos) {
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
      _Placeholder(:final section) => Padding(
          key: row.key,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Text(
              section == PickStatus.ranked
                  ? 'Drag teams here, or tap a team and choose Pick'
                  : 'Drag teams here',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
      _TeamRow() => _teamTile(row, taken, boardPos, dragIndex: index),
    };
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final p = context.watch<PickBoardProvider>();
    final rows = _buildRows(
        p.myList, appState.teams.map((t) => t.teamNumber).toList());
    final boardPos = {
      for (final r in p.board.rows(appState.teams.length))
        if (r.agreedRank != null) r.teamNumber: r.agreedRank!,
    };
    final taken = p.board.taken;
    final query = _search.text.trim().toLowerCase();

    final Widget list;
    if (query.isNotEmpty) {
      final matches = rows
          .whereType<_TeamRow>()
          .where((r) =>
              teamLabel(context, r.teamNumber).toLowerCase().contains(query))
          .toList();
      list = ListView(children: [
        for (final r in matches) _teamTile(r, taken, boardPos),
      ]);
    } else {
      list = ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: rows.length,
        onReorderStart: (_) => p.holdUpdates(true),
        onReorderEnd: (_) => p.holdUpdates(false),
        onReorderItem: (o, n) => _onReorder(rows, o, n),
        itemBuilder: (context, i) => _buildRow(rows[i], i, taken, boardPos),
      );
    }

    return Column(
      children: [
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
        Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            'Saved as ${p.voter}. Everyone sees this list on the Board.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(child: list),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Team sheet: everyone's take on one team, plus your own controls.

Future<void> showPickBoardTeamSheet(BuildContext context, int teamNumber) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TeamSheet(teamNumber: teamNumber),
  );
}

class _TeamSheet extends StatefulWidget {
  final int teamNumber;

  const _TeamSheet({required this.teamNumber});

  @override
  State<_TeamSheet> createState() => _TeamSheetState();
}

class _TeamSheetState extends State<_TeamSheet> {
  late final TextEditingController _notes;
  late String _savedNotes;

  @override
  void initState() {
    super.initState();
    _savedNotes = context
            .read<PickBoardProvider>()
            .myList
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

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PickBoardProvider>();
    final tn = widget.teamNumber;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mine = p.myList;
    final entry = mine.entryFor(tn);
    final status = entry?.isRanked == true
        ? PickStatus.ranked
        : entry?.dnp == true
            ? PickStatus.dnp
            : PickStatus.unranked;
    final rankedCount = mine.ranked.length;
    final rank = entry?.isRanked == true ? entry!.ranking! : null;
    final rows = p.board.rows(_eventTeamCount(context));
    final row = rows.where((r) => r.teamNumber == tn).firstOrNull;
    final taken = p.board.taken.contains(tn);
    void vote(PickListUpdate u) => _vote(context, u);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(teamLabel(context, tn),
                      style: theme.textTheme.titleLarge),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('Details'),
                  onPressed: () {
                    Navigator.pop(context);
                    openTeamDetails(context, tn);
                  },
                ),
              ],
            ),
            Text(
              row == null
                  ? 'Not on anyone\'s list yet'
                  : row.agreedRank == null
                      ? 'On ${row.ranks.length} ${row.ranks.length == 1 ? 'list' : 'lists'}, no board spot yet'
                      : 'Board #${row.agreedRank}'
                          '${row.agreement == null ? '' : ' · ${row.agreement!.round()}% have it at #${row.agreedRank}'}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            for (final b in p.board.voters)
              Builder(builder: (context) {
                final e = b.list.entryFor(tn);
                final text = e?.isRanked == true
                    ? '#${e!.ranking}'
                    : e?.dnp == true
                        ? 'DNP'
                        : '—';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(b.voter,
                            overflow: TextOverflow.ellipsis,
                            style: b.key == p.myKey
                                ? const TextStyle(fontWeight: FontWeight.bold)
                                : null),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(text,
                            style: e?.dnp == true
                                ? TextStyle(color: scheme.error)
                                : null),
                      ),
                      Expanded(
                        child: Text(e?.notes ?? '',
                            style: theme.textTheme.bodySmall),
                      ),
                    ],
                  ),
                );
              }),
            const Divider(height: 24),
            Text('Your pick', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<PickStatus>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: PickStatus.ranked, label: Text('Pick')),
                ButtonSegment(value: PickStatus.unranked, label: Text('Unranked')),
                ButtonSegment(value: PickStatus.dnp, label: Text('DNP')),
              ],
              selected: {status},
              onSelectionChanged: (s) {
                final next = s.first;
                vote(next == PickStatus.ranked
                    ? PickListUpdate(tn, position: rankedCount + 1)
                    : PickListUpdate(tn, status: next));
              },
            ),
            if (rank != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('My #$rank of $rankedCount',
                      style: theme.textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Move to top',
                    icon: const Icon(Icons.vertical_align_top),
                    onPressed: rank > 1
                        ? () => vote(PickListUpdate(tn, position: 1))
                        : null,
                  ),
                  IconButton(
                    tooltip: 'Move up',
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: rank > 1
                        ? () => vote(PickListUpdate(tn, position: rank - 1))
                        : null,
                  ),
                  IconButton(
                    tooltip: 'Move down',
                    icon: const Icon(Icons.arrow_downward),
                    onPressed: rank < rankedCount
                        ? () => vote(PickListUpdate(tn, position: rank + 1))
                        : null,
                  ),
                  IconButton(
                    tooltip: 'Move to bottom',
                    icon: const Icon(Icons.vertical_align_bottom),
                    onPressed: rank < rankedCount
                        ? () => vote(PickListUpdate(tn, position: rankedCount))
                        : null,
                  ),
                ],
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Taken by another alliance'),
              subtitle: const Text('Shared with everyone'),
              value: taken,
              onChanged: (v) => _setTaken(context, tn, v),
            ),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'My notes',
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
                        vote(PickListUpdate(tn, notes: _savedNotes));
                        setState(() {});
                      },
                child: const Text('Save notes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
