import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pick_board.dart';
import '../models/pick_list.dart';
import '../models/rankings.dart';
import '../providers/app_state_provider.dart';
import '../providers/pick_board_provider.dart';
import '../providers/pick_list_provider.dart' show PickListSync;
import '../providers/rankings_provider.dart';
import '../services/storage_service.dart';
import '../widgets/flip_list.dart';
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
      // Event rank on My List's unranked teams.
      final eventKey = settings.selectedEventKey;
      if (eventKey != null) context.read<RankingsProvider>().load(eventKey);
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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pick List'),
          actions: [if (message == null) _syncIndicator(p)],
          bottom: message != null
              ? null
              : const TabBar(tabs: [
                  Tab(text: 'Board'),
                  Tab(text: 'My List'),
                  Tab(text: 'Other Lists'),
                ]),
        ),
        drawer: const NavDrawer(selectedIndex: 13),
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
                    child: TabBarView(children: [
                      _BoardView(),
                      _MyListView(),
                      _OtherListsView(),
                    ]),
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
  // Persisted per event so they survive a reload.
  int _minVotes = 1;
  Set<String> _excluded = {};
  late final String _eventKey;

  @override
  void initState() {
    super.initState();
    _eventKey =
        context.read<AppStateProvider>().settings.selectedEventKey ?? '';
    StorageService.instance.loadBoardFilters(_eventKey).then((f) {
      if (!mounted) return;
      setState(() {
        _minVotes = f.minVotes.clamp(1, 10);
        _excluded = f.excluded;
      });
    });
  }

  void _saveFilters() =>
      StorageService.instance.saveBoardFilters(_eventKey, _minVotes, _excluded);

  /// Who counts on the board. Edits a draft; OK applies it, Cancel drops it.
  Future<void> _pickPeople(List<Ballot> all) async {
    var draft = {..._excluded};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final included = all.where((b) => !draft.contains(b.key)).length;
          return AlertDialog(
            title: const Text('Participants'),
            contentPadding: const EdgeInsets.only(top: 12),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    tristate: true,
                    title: Text('Everyone ($included/${all.length})'),
                    value: included == all.length
                        ? true
                        : included == 0
                            ? false
                            : null,
                    onChanged: (_) => setDialog(() => draft = included == all.length
                        ? {for (final b in all) b.key}
                        : {}),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final b in all)
                          CheckboxListTile(
                            title: Text(b.voter),
                            value: !draft.contains(b.key),
                            onChanged: (v) => setDialog(() => v == true
                                ? draft.remove(b.key)
                                : draft.add(b.key)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, draft),
                  child: const Text('OK')),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _excluded = result);
    _saveFilters();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PickBoardProvider>();
    final board = p.board;
    final allVoters = board.voters;
    final voters =
        allVoters.where((b) => !_excluded.contains(b.key)).toList();
    final rows = board.rows(_eventTeamCount(context),
        minVotes: _minVotes, excluded: _excluded);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    if (allVoters.isEmpty) {
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
      // Not a lazy ListView: rows glide to new spots (FlipScope), which
      // needs them all laid out. A board is at most one row per team.
      // Shade by spot, not by row, so tied teams (two #2s) share a band.
      // Teams without a spot each get their own.
      final shaded = <bool>[];
      for (final (i, row) in rows.indexed) {
        final sameSpot = i > 0 &&
            row.agreedRank != null &&
            row.agreedRank == rows[i - 1].agreedRank;
        shaded.add(i == 0 ? false : (sameSpot ? shaded[i - 1] : !shaded[i - 1]));
      }
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(sidePad, 0, sidePad, 32),
        child: FlipScope(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Text('Min votes', style: theme.textTheme.bodyMedium),
                const SizedBox(width: 6),
                DropdownButton<int>(
                  value: _minVotes,
                  isDense: true,
                  items: [
                    for (var i = 1; i <= 10; i++)
                      DropdownMenuItem(value: i, child: Text('$i')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _minVotes = v);
                    _saveFilters();
                  },
                ),
                const Spacer(),
                ActionChip(
                  avatar: const Icon(Icons.people_outline, size: 18),
                  label: Text(
                      'Participants: ${voters.length}/${allVoters.length}'),
                  onPressed: () => _pickPeople(allVoters),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (voters.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Everyone is excluded. Pick participants with the Participants button.',
                textAlign: TextAlign.center,
                style: muted,
              ),
            )
          else
            _BoardHeader(voters: shownVoters, myKey: p.myKey),
          for (final (i, row) in rows.indexed)
            FlipItem(
              key: ValueKey(row.teamNumber),
              child: _BoardRowTile(
                row: row,
                shownVoters: shownVoters,
                shaded: shaded[i],
              ),
            ),
        ],
          ),
        ),
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
          SizedBox(width: 36, child: Text('#', style: style)),
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
              width: 36,
              child: row.agreedRank == null
                  ? null
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: _SpotDisc(row.agreedRank!),
                    ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                                text: '$tn',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            if (nickname.isNotEmpty)
                              TextSpan(text: '  $nickname'),
                          ]),
                          style: strike,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TeamInfoButton(tn),
                    ],
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
                width: _agreementWidth, child: _AgreementBar(row)),
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

/// The board spot on a colored disc; four colors cycle by spot so tied rows
/// (two #2s) read as one group and neighboring spots always differ.
class _SpotDisc extends StatelessWidget {
  final int spot;

  const _SpotDisc(this.spot);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Translucent so it works on light and dark surfaces.
    const hues = [Colors.blue, Colors.amber, Colors.green, Colors.purple];
    final bg = hues[(spot - 1) % hues.length].withValues(alpha: 0.3);
    final fg = scheme.onSurface;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text('$spot',
          style: theme.textTheme.bodyMedium?.copyWith(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

/// Agreement as a bar on a full-width track, votes / people beside it.
class _AgreementBar extends StatelessWidget {
  final BoardRow row;

  const _AgreementBar(this.row);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final v = row.agreement;
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
            v == null ? '—' : '${row.agreeVotes}/${row.voterCount}',
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
  _Header(this.section);
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
        _Header(s),
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
      Map<int, RankingRow> eventRanks,
      {int? dragIndex}) {
    final scheme = Theme.of(context).colorScheme;
    final isTaken = taken.contains(row.teamNumber);
    final notes = row.entry?.notes ?? '';
    final pos = boardPos[row.teamNumber];
    // Unranked teams need more to go on: event rank and record.
    final eventRank = row.section == PickStatus.unranked
        ? eventRanks[row.teamNumber]
        : null;
    final facts = [
      if (eventRank != null) 'Rank #${eventRank.rank} · ${eventRank.record}',
      if (pos != null) 'Board #$pos',
    ].join(' · ');
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
      title: Row(
        children: [
          Flexible(
            child: Text(
              teamLabel(context, row.teamNumber),
              style: isTaken
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
          ),
          TeamInfoButton(row.teamNumber),
        ],
      ),
      subtitle: notes.isNotEmpty
          ? Text(notes, maxLines: 1, overflow: TextOverflow.ellipsis)
          : facts.isNotEmpty
              ? Text(facts)
              : null,
      onTap: () => showPickBoardTeamSheet(context, row.teamNumber),
      trailing: row.section == PickStatus.ranked
          ? IconButton(
              tooltip: isTaken ? 'Mark available' : 'Mark taken',
              icon: Icon(
                  isTaken ? Icons.check_box : Icons.check_box_outline_blank),
              onPressed: () => _setTaken(context, row.teamNumber, !isTaken),
            )
          : null,
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

  Widget _buildRow(_Row row, int index, Set<int> taken,
      Map<int, int> boardPos, Map<int, RankingRow> eventRanks) {
    final theme = Theme.of(context);
    return switch (row) {
      _Header(:final section) => Padding(
          key: row.key,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Text(_sectionTitles[section]!,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
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
      _TeamRow() =>
          _teamTile(row, taken, boardPos, eventRanks, dragIndex: index),
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
    final eventRanks = {
      for (final r in context.watch<RankingsProvider>().data?.rows ??
          const <RankingRow>[])
        r.teamNumber: r,
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
        for (final r in matches) _teamTile(r, taken, boardPos, eventRanks),
      ]);
    } else {
      list = ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: rows.length,
        onReorderStart: (_) => p.holdUpdates(true),
        onReorderEnd: (_) => p.holdUpdates(false),
        onReorderItem: (o, n) => _onReorder(rows, o, n),
        itemBuilder: (context, i) =>
            _buildRow(rows[i], i, taken, boardPos, eventRanks),
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
// Other Lists tab: everyone else's ballot, side by side.

class _OtherListsView extends StatefulWidget {
  const _OtherListsView();

  @override
  State<_OtherListsView> createState() => _OtherListsViewState();
}

class _OtherListsViewState extends State<_OtherListsView>
    with AutomaticKeepAliveClientMixin {
  final _hScroll = ScrollController();
  // One vertical controller per ballot; kept here so offsets survive tab
  // switches (the state itself is kept alive below).
  final _vScrolls = <String, ScrollController>{};
  double _colWidth = 360;
  int _page = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _hScroll.addListener(() {
      final i = (_hScroll.offset / _colWidth).round();
      if (i != _page) setState(() => _page = i);
    });
  }

  @override
  void dispose() {
    _hScroll.dispose();
    for (final c in _vScrolls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.watch<PickBoardProvider>();
    final others = p.board.voters.where((b) => b.key != p.myKey).toList();
    final taken = p.board.taken;
    final theme = Theme.of(context);

    if (others.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nobody else has a list yet.', textAlign: TextAlign.center),
        ),
      );
    }
    final page = _page.clamp(0, others.length - 1);

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      // ~360px columns; on a phone one column plus a peek at the next.
      _colWidth = math.min(360.0, width * 0.9);
      return Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final (i, b) in others.indexed)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(b.voter),
                      selected: i == page,
                      onSelected: (_) => _hScroll.animateTo(
                          math.min(i * _colWidth,
                              _hScroll.position.maxScrollExtent),
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            // Let a mouse drag the columns sideways too, not just touch.
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {...PointerDeviceKind.values},
              ),
              child: SingleChildScrollView(
                controller: _hScroll,
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final b in others)
                      SizedBox(
                        width: _colWidth,
                        child: _BallotColumn(
                          ballot: b,
                          taken: taken,
                          controller:
                              _vScrolls.putIfAbsent(b.key, ScrollController.new),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              '${others.length} other ${others.length == 1 ? 'list' : 'lists'} · '
              'swipe or tap a name',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      );
    });
  }
}

/// One person's ballot, read-only: their pick order, then their DNPs.
class _BallotColumn extends StatelessWidget {
  final Ballot ballot;
  final Set<int> taken;
  final ScrollController controller;

  const _BallotColumn(
      {required this.ballot, required this.taken, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final list = ballot.list;
    final ranked = list.ranked;
    final dnp = list.teams.where((t) => t.dnp).toList()
      ..sort((a, b) => a.teamNumber.compareTo(b.teamNumber));
    final updated = list.updatedAt == null
        ? ''
        : 'Updated ${TimeOfDay.fromDateTime(list.updatedAt!.toLocal()).format(context)}';

    Widget tile(PickListEntry e, Widget leading) {
      final isTaken = taken.contains(e.teamNumber);
      final t = ListTile(
        dense: true,
        leading: leading,
        title: Row(
          children: [
            Flexible(
              child: Text(
                teamLabel(context, e.teamNumber),
                style: isTaken
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null,
              ),
            ),
            TeamInfoButton(e.teamNumber),
          ],
        ),
        subtitle: e.notes.isEmpty
            ? null
            : Text(e.notes, maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () => showPickBoardTeamSheet(context, e.teamNumber),
      );
      return FlipItem(
        key: ValueKey(e.teamNumber),
        child: isTaken ? Opacity(opacity: 0.5, child: t) : t,
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 4, 4),
      clipBehavior: Clip.antiAlias,
      // Header sits outside the ListView so it stays put while the list scrolls.
      child: Column(
        children: [
          ListTile(
            title: Text(ballot.voter,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            subtitle: updated.isEmpty ? null : Text(updated),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.only(bottom: 16),
              child: FlipScope(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          for (final e in ranked)
            tile(
              e,
              CircleAvatar(
                radius: 14,
                backgroundColor: scheme.primaryContainer,
                child: Text('${e.ranking}',
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          if (dnp.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Do Not Pick',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            for (final e in dnp) tile(e, Icon(Icons.block, color: scheme.error)),
          ],
              ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Team sheet: edit your own notes on a team (shown under it on the lists).

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
    _savedNotes = context.read<PickBoardProvider>().myList.entryFor(widget.teamNumber)?.notes ?? '';
    _notes = TextEditingController(text: _savedNotes);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    _savedNotes = _notes.text.trim();
    _vote(context, PickListUpdate(widget.teamNumber, notes: _savedNotes));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(teamLabel(context, widget.teamNumber), style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'My notes', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _notes.text.trim() == _savedNotes ? null : _save,
                child: const Text('Save notes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
