import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../analytics/cluster_similarity.dart';
import '../analytics/match_stats.dart';
import '../build_info.dart';
import '../models/cluster_result.dart';
import '../models/match_result.dart';
import '../models/pit_result.dart';
import '../providers/app_state_provider.dart';
import '../providers/cluster_provider.dart';
import '../providers/event_data_provider.dart';
import '../widgets/match_card.dart';
import '../services/storage_service.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/range_strip.dart';
import '../widgets/team_details.dart';
import '../widgets/team_selector.dart';

const _maxTeams = 6;

// One color per compared team, kept clear of the red/blue alliance colors
// on the match cards. Validated for colorblind separation; every mark also
// carries the team number.
const _teamColors = [
  Color(0xFF7E57C2), // purple
  Color(0xFFD98C1F), // amber
  Color(0xFF2A9DAE), // teal
  Color(0xFFA0522D), // brown
  Color(0xFF5E9E2E), // green
  Color(0xFFC2457F), // magenta
];

/// `/head-to-head`: pick two or more teams and compare official results and
/// pit data (collapsible) and the clustering dimensions, each drawn over the
/// event's range like the Clusters screen.
class HeadToHeadScreen extends StatefulWidget {
  const HeadToHeadScreen({super.key});

  @override
  State<HeadToHeadScreen> createState() => _HeadToHeadScreenState();
}

/// The page's sections, in their default order.
const _sectionIds = ['official', 'pit', 'dimensions'];

class _HeadToHeadScreenState extends State<HeadToHeadScreen> {
  // Kept for the app session so leaving and coming back finds the page as it
  // was: same teams, layout and scroll position. Teams, order and open
  // sections are also saved, so they survive a reload.
  static String? _event;
  static List<int> _teams = [];
  static List<String>? _order;
  static Set<String>? _open;
  static double _offset = 0;

  late final ScrollController _scroll = ScrollController(initialScrollOffset: _offset);
  // Content (matches, clusters) can arrive after the first frame; keep
  // trying to reach the saved spot until it fits or the user scrolls.
  bool _restoring = _offset > 0;
  int _pickerKey = 0; // rebuilds the picker so it clears after each add

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_restoring) _offset = _scroll.offset;
    });
    final storage = StorageService.instance;
    if (_order == null) {
      storage.loadHeadToHeadLayout().then((v) {
        final (order, open) = v;
        if (!mounted) return;
        setState(() {
          _order = [
            for (final id in order)
              if (_sectionIds.contains(id)) id,
            for (final id in _sectionIds)
              if (!order.contains(id)) id,
          ];
          _open = open ?? {'dimensions'};
        });
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.ensureEventData();
      context.ensureClusters();
      final event = context.read<AppStateProvider>().settings.selectedEventKey ?? '';
      if (event != _event) {
        _event = event;
        _teams = [];
        _offset = 0;
        _restoring = false;
        storage.loadHeadToHeadTeams(event).then((t) {
          if (mounted && _event == event) setState(() => _teams = t);
        });
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _restoreScroll() {
    if (!_restoring) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || !_restoring) return;
      final max = _scroll.position.maxScrollExtent;
      _scroll.jumpTo(_offset.clamp(0, max));
      if (max >= _offset) _restoring = false;
    });
  }

  void _setTeams(List<int> teams) {
    setState(() => _teams = teams);
    if (_event != null) StorageService.instance.saveHeadToHeadTeams(_event!, teams);
  }

  void _add(int? team) {
    if (team == null || _teams.contains(team) || _teams.length >= _maxTeams) return;
    _pickerKey++;
    _setTeams([..._teams, team]);
  }

  void _saveLayout() => StorageService.instance.saveHeadToHeadLayout(_order!, _open!);

  void _toggle(String id) {
    setState(() {
      final open = {..._open!};
      if (!open.remove(id)) open.add(id);
      _open = open;
    });
    _saveLayout();
  }

  void _move(String id, int by) {
    final i = _order!.indexOf(id);
    final j = i + by;
    if (j < 0 || j >= _order!.length) return;
    setState(() {
      _order = [..._order!]
        ..removeAt(i)
        ..insert(j, id);
    });
    _saveLayout();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final data = context.watch<EventDataProvider>();
    final theme = Theme.of(context);
    final names = {for (final t in appState.teams) t.teamNumber: t.nickname};
    _restoreScroll();

    return Scaffold(
      appBar: AppBar(
        title: Text(appState.settings.selectedEventName ?? 'Configure Event to Continue...'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              'Updated $buildTimestamp',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
      drawer: const NavDrawer(selectedIndex: 10),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: NotificationListener<UserScrollNotification>(
            // The user took over; stop steering back to the saved spot.
            onNotification: (_) {
              _restoring = false;
              return false;
            },
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              children: [
                if (_teams.length < _maxTeams)
                  TeamSelector(
                    key: ValueKey(_pickerKey),
                    teams: appState.teams.where((t) => !_teams.contains(t.teamNumber)).toList(),
                    selectedTeamNumber: null,
                    onChanged: _add,
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < _teams.length; i++)
                      InputChip(
                        avatar: CircleAvatar(backgroundColor: _teamColors[i], radius: 6),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [Text('${_teams[i]} ${names[_teams[i]] ?? ''}'), TeamInfoButton(_teams[i])],
                        ),
                        onPressed: () => showTeamDetailsDialog(context, _teams[i]),
                        onDeleted: () => _setTeams([..._teams]..removeAt(i)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_teams.length < 2)
                  const Text('Pick at least two teams to compare (up to 6).')
                else if (_order != null)
                  _Comparison(
                    teams: _teams,
                    data: data,
                    pit: appState,
                    order: _order!,
                    open: _open!,
                    onToggle: _toggle,
                    onMove: _move,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row {
  final String label;
  final List<double?> values; // numeric, used for bars and best-highlighting
  final List<String> text;
  final bool bar;
  const _Row(this.label, this.values, this.text, {this.bar = true});
}

class _Comparison extends StatelessWidget {
  final List<int> teams;
  final EventDataProvider data;
  final AppStateProvider pit;
  final List<String> order;
  final Set<String> open;
  final ValueChanged<String> onToggle;
  final void Function(String id, int by) onMove;
  const _Comparison({
    required this.teams,
    required this.data,
    required this.pit,
    required this.order,
    required this.open,
    required this.onToggle,
    required this.onMove,
  });

  PitResult? _pit(int team) {
    final full = pit.getAllPitResultsForTeam(team).where((r) => r.hasFullData).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return full.isEmpty ? null : full.first;
  }

  @override
  Widget build(BuildContext context) {
    final records = [for (final t in teams) teamRecord(data.matches, t, qualsOnly: true)];
    final pits = [for (final t in teams) _pit(t)];

    String f1(double? v) => v == null ? '–' : v.toStringAsFixed(1);
    List<String> fmt(List<double?> v) => [for (final x in v) f1(x)];

    final official = [
      _Row(
        'Record',
        [for (final r in records) r.played == 0 ? null : r.wins / r.played],
        [for (final r in records) r.played == 0 ? '–' : r.label],
        bar: false,
      ),
      _Row('Avg RP / match', [for (final r in records) r.avgRp], fmt([for (final r in records) r.avgRp])),
      _Row('Avg alliance score', [for (final r in records) r.avgScore], fmt([for (final r in records) r.avgScore])),
      _Row('Avg hub fuel (alliance)', [for (final r in records) r.avgFuel], fmt([for (final r in records) r.avgFuel])),
    ];
    final pitRows = [
      _Row(
        'Drive train',
        [for (final _ in teams) null],
        [for (final p in pits) p == null ? '–' : p.driveTrain],
        bar: false,
      ),
      _Row(
        'Fuel capacity',
        [for (final p in pits) p?.fuelCapacity.toDouble()],
        [for (final p in pits) p == null ? '–' : '${p.fuelCapacity}'],
      ),
      _Row(
        'Hang level',
        [for (final p in pits) p == null ? null : (p.hangingWorks ? p.hangingLevel.toDouble() : 0)],
        [for (final p in pits) p == null ? '–' : (p.hangingWorks ? 'L${p.hangingLevel}' : 'No')],
      ),
      _Row(
        'Ground pickup',
        [for (final p in pits) p == null ? null : (p.groundPickup ? 1 : 0)],
        [for (final p in pits) p == null ? '–' : (p.groundPickup ? 'Yes' : 'No')],
        bar: false,
      ),
      _Row(
        'Shoot on move',
        [for (final p in pits) p == null ? null : (p.shootOnMove ? 1 : 0)],
        [for (final p in pits) p == null ? '–' : (p.shootOnMove ? 'Yes' : 'No')],
        bar: false,
      ),
    ];

    final sections = {
      'official': (
        'Official results',
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Table(teams: teams, rows: official, note: 'Qualification matches only. Bold = best of the group.'),
            const SizedBox(height: 16),
            _Matches(teams: teams, matches: data.matches),
          ],
        ),
      ),
      'pit': ('Pit scouting', _Table(teams: teams, rows: pitRows)),
      'dimensions': ('Dimensions', _Dimensions(teams: teams, data: data)),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < order.length; i++)
          _Accordion(
            title: sections[order[i]]!.$1,
            open: open.contains(order[i]),
            canMoveUp: i > 0,
            canMoveDown: i < order.length - 1,
            onToggle: () => onToggle(order[i]),
            onMove: (by) => onMove(order[i], by),
            child: sections[order[i]]!.$2,
          ),
      ],
    );
  }
}

/// Every match the compared teams played (or will play), on the shared
/// MatchCard. Each compared team's chip carries its color dot, so partners
/// and opponents among them stand out.
///
/// Wide enough: one column per team, row k = each team's k-th match, so
/// their events line up. Narrower: one list in match order, each match once
/// (focused on the first compared team in it).
class _Matches extends StatelessWidget {
  final List<int> teams;
  final List<MatchResult> matches;
  const _Matches({required this.teams, required this.matches});

  // Narrowest a MatchCard column reads well, without and with team names.
  static const _minColumn = 340.0;
  static const _namesColumn = 470.0;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final markers = {for (var i = 0; i < teams.length; i++) teams[i]: _teamColors[i]};
    final perTeam = [for (final t in teams) matchesForTeam(matches, t)];
    if (perTeam.every((m) => m.isEmpty)) {
      return const Text('No matches found for these teams yet.');
    }

    return LayoutBuilder(
      builder: (context, c) {
        final col = (c.maxWidth - _gap * (teams.length - 1)) / teams.length;
        final title = Text('Matches', style: theme.textTheme.titleSmall);

        if (col >= _minColumn) {
          final rows = perTeam.map((m) => m.length).reduce((a, b) => a > b ? a : b);
          final names = col >= _namesColumn;
          Widget spaced(List<Widget> cells) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cells.length; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                Expanded(child: cells[i]),
              ],
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 6),
              spaced([
                for (var i = 0; i < teams.length; i++)
                  Column(
                    children: [
                      Container(height: 4, color: _teamColors[i]),
                      const SizedBox(height: 4),
                      Text('${teams[i]} · ${perTeam[i].length} matches', style: theme.textTheme.labelLarge),
                    ],
                  ),
              ]),
              for (var k = 0; k < rows; k++)
                spaced([
                  for (var i = 0; i < teams.length; i++)
                    k < perTeam[i].length
                        ? MatchCard(
                            key: ValueKey('${teams[i]}-${perTeam[i][k].key}'),
                            match: perTeam[i][k],
                            focusTeam: teams[i],
                            showNames: names,
                            markers: markers,
                          )
                        : const SizedBox.shrink(),
                ]),
            ],
          );
        }

        final all = {for (final m in perTeam) ...m}.toList()..sort((a, b) => a.sortKey.compareTo(b.sortKey));
        final together = all.where((m) => teams.where(m.hasTeam).length > 1).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            title,
            Text(
              '${all.length} matches in order'
              '${together > 0 ? ', $together with more than one of these teams' : ''}. '
              'Dots mark the teams being compared.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            for (final m in all)
              MatchCard(
                key: ValueKey(m.key),
                match: m,
                focusTeam: teams.firstWhere(m.hasTeam),
                showNames: c.maxWidth >= _namesColumn,
                markers: markers,
              ),
          ],
        );
      },
    );
  }
}

/// A collapsible card that can move up or down the page (like Team
/// Details' sections). The screen keeps which are open and their order.
class _Accordion extends StatelessWidget {
  final String title;
  final bool open;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onToggle;
  final ValueChanged<int> onMove;
  final Widget child;
  const _Accordion({
    required this.title,
    required this.open,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onToggle,
    required this.onMove,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
                  PopupMenuButton<int>(
                    tooltip: 'Move section',
                    icon: const Icon(Icons.swap_vert),
                    onSelected: onMove,
                    itemBuilder: (_) => [
                      PopupMenuItem(value: -1, enabled: canMoveUp, child: const Text('Move up')),
                      PopupMenuItem(value: 1, enabled: canMoveDown, child: const Text('Move down')),
                    ],
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.expand_more)),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(alignment: Alignment.centerLeft, child: child),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Rows of values, one column per team, bold = best.
class _Table extends StatelessWidget {
  final List<int> teams;
  final List<_Row> rows;
  final String note;
  const _Table({required this.teams, required this.rows, this.note = 'Bold = best of the group.'});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const labelWidth = 120.0;
    const colWidth = 84.0;
    return LayoutBuilder(
      builder: (context, c) {
        // Use the full width when there's room, otherwise scroll sideways.
        final col = ((c.maxWidth - labelWidth) / teams.length).clamp(colWidth, 200.0);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: labelWidth + col * teams.length,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(width: labelWidth),
                    for (var i = 0; i < teams.length; i++)
                      SizedBox(
                        width: col,
                        child: Column(
                          children: [
                            Container(
                              height: 4,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              color: _teamColors[i],
                            ),
                            const SizedBox(height: 4),
                            Text('${teams[i]}', style: theme.textTheme.titleSmall),
                          ],
                        ),
                      ),
                  ],
                ),
                for (final r in rows) _CompareRow(row: r, labelWidth: labelWidth, colWidth: col),
                const SizedBox(height: 6),
                Text(note, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The clustering dimensions (the same ones Clusters and Team Details use),
/// each drawn in real units over the event's range with one dot per team.
/// Biggest differences between these teams first.
class _Dimensions extends StatefulWidget {
  final List<int> teams;
  final EventDataProvider data;
  const _Dimensions({required this.teams, required this.data});

  @override
  State<_Dimensions> createState() => _DimensionsState();
}

class _DimensionsState extends State<_Dimensions> {
  static final Expando<ClusterSpace> _spaces = Expando();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final p = context.watch<ClusterProvider>();
    final r = p.result;
    final teams = widget.teams;

    Widget body;
    if (r == null) {
      body = p.error != null
          ? Text(p.error!, style: TextStyle(color: scheme.error))
          : !p.configured
          ? const Text('Set a secret team key and event in Settings.')
          : const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
    } else {
      final space = _spaces[r] ??= ClusterSpace(r);
      final rows = <(String, int, double)>[];
      var flat = 0;
      for (var j = 0; j < space.features.length; j++) {
        // Every team the same: nothing to compare.
        final range = r.rangeOf(space.features[j]);
        if (range == null || range.$2 - range.$1 <= 0) {
          flat++;
          continue;
        }
        final vs = [for (final t in teams) r.team(t)?.values[space.features[j]]].whereType<double>().toList();
        final spread = vs.length < 2 ? 0.0 : (vs.reduce((a, b) => a > b ? a : b) - vs.reduce((a, b) => a < b ? a : b));
        rows.add((space.features[j], j, space.std[j] > 0 ? spread / space.std[j] : 0));
      }
      rows.sort((a, b) => b.$3.compareTo(a.$3));
      final source = p.isCustom
          ? 'your custom settings'
          : (p.teamDefault != null ? 'team default settings' : 'built-in settings');
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${r.features.length} dimensions from $source, biggest differences first'
            '${flat > 0 ? ' ($flat where every team is the same left out)' : ''}. '
            'Each line runs from the lowest to the highest team at the event.',
            style: muted,
          ),
          const SizedBox(height: 6),
          StripLegend([
            for (var i = 0; i < teams.length; i++)
              (
                StripLegend.dot(_teamColors[i], 10),
                [
                  '${teams[i]}',
                  if (r.team(teams[i]) != null) 'G${r.team(teams[i])!.group}',
                  '${widget.data.statsFor(teams[i])?.matchesScouted ?? 0} scouted',
                ].join(' · '),
              ),
            (StripLegend.line(scheme.outline, 1), 'Event avg'),
          ]),
          const SizedBox(height: 4),
          for (final (f, j, _) in rows) _DimensionRow(result: r, feature: f, mean: space.mean[j], teams: teams),
        ],
      );
    }

    return body;
  }
}

class _DimensionRow extends StatelessWidget {
  final ClusterResult result;
  final String feature;
  final double mean;
  final List<int> teams;
  const _DimensionRow({required this.result, required this.feature, required this.mean, required this.teams});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final values = [for (final t in teams) result.team(t)?.values[feature]];
    final (lo, hi) = result.rangeOf(feature) ?? (mean, mean);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final label = Text(
                result.labelFor(feature),
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
              final valueStyle = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
              final narrow = c.maxWidth < 560;
              final vals = Wrap(
                alignment: narrow ? WrapAlignment.start : WrapAlignment.end,
                spacing: 10,
                children: [
                  for (var i = 0; i < teams.length; i++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StripLegend.dot(_teamColors[i], 7),
                        const SizedBox(width: 3),
                        Text(formatValue(values[i]), style: valueStyle),
                      ],
                    ),
                  Text('avg ${formatValue(mean)}', style: valueStyle),
                ],
              );
              // Phones: values under the name so the name isn't cut short.
              if (narrow) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [label, vals]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: label),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: vals),
                ],
              );
            },
          ),
          const SizedBox(height: 3),
          RangeStrip(
            min: lo,
            max: hi,
            eventAvg: mean,
            dots: [
              for (var i = teams.length - 1; i >= 0; i--)
                if (values[i] != null) StripDot(values[i]!, 11, _teamColors[i]),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final _Row row;
  final double labelWidth;
  final double colWidth;
  const _CompareRow({required this.row, required this.labelWidth, required this.colWidth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final present = row.values.whereType<double>().toList();
    final hi = present.isEmpty ? 0.0 : present.reduce((a, b) => a > b ? a : b);
    final lo = present.isEmpty ? 0.0 : present.reduce((a, b) => a < b ? a : b);
    final differs = present.length > 1 && hi != lo;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(row.label, style: theme.textTheme.bodySmall),
          ),
          for (var i = 0; i < row.values.length; i++)
            SizedBox(
              width: colWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.text[i],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: differs && row.values[i] == hi ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (row.bar && row.values[i] != null && hi > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: (row.values[i]! / hi).clamp(0.0, 1.0),
                            minHeight: 4,
                            color: _teamColors[i],
                            backgroundColor: _teamColors[i].withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
