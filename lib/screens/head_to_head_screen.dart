import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../analytics/match_stats.dart';
import '../analytics/scout_stats.dart';
import '../build_info.dart';
import '../models/pit_result.dart';
import '../providers/app_state_provider.dart';
import '../providers/event_data_provider.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/team_details.dart';
import '../widgets/team_selector.dart';

const _maxTeams = 6;

// Stats where a lower value is the better one.
const _lowerIsBetter = {
  'auto_did_nothing',
  'teleop_active_defense_penalties',
  'teleop_inactive_defense_penalties',
};

// Bar colours per compared team, matching the Clusters palette family.
const _teamColors = [
  Color(0xFF2A78D6),
  Color(0xFFE34948),
  Color(0xFF3FA66B),
  Color(0xFFE0A030),
  Color(0xFF8E5BD0),
  Color(0xFF2FA7B8),
];

/// `/head-to-head`: pick two or more teams and compare official results,
/// pit data and scouted averages side by side.
class HeadToHeadScreen extends StatefulWidget {
  const HeadToHeadScreen({super.key});

  @override
  State<HeadToHeadScreen> createState() => _HeadToHeadScreenState();
}

class _HeadToHeadScreenState extends State<HeadToHeadScreen> {
  final List<int> _teams = [];
  int _pickerKey = 0; // rebuilds the picker so it clears after each add

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.ensureEventData();
    });
  }

  void _add(int? team) {
    if (team == null || _teams.contains(team) || _teams.length >= _maxTeams) return;
    setState(() {
      _teams.add(team);
      _pickerKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final data = context.watch<EventDataProvider>();
    final theme = Theme.of(context);
    final names = {for (final t in appState.teams) t.teamNumber: t.nickname};

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
      drawer: const NavDrawer(selectedIndex: 13),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
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
                      label: Text('${_teams[i]} ${names[_teams[i]] ?? ''}'),
                      onPressed: () => openTeamDetails(context, _teams[i]),
                      onDeleted: () => setState(() => _teams.removeAt(i)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_teams.length < 2)
                const Text('Pick at least two teams to compare (up to 6).')
              else
                _Comparison(
                  teams: _teams,
                  data: data,
                  pit: appState,
                ),
            ],
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
  final bool lowerBetter;
  final bool bar;
  const _Row(this.label, this.values, this.text, {this.lowerBetter = false, this.bar = true});
}

class _Comparison extends StatelessWidget {
  final List<int> teams;
  final EventDataProvider data;
  final AppStateProvider pit;
  const _Comparison({required this.teams, required this.data, required this.pit});

  PitResult? _pit(int team) {
    final full = pit.getAllPitResultsForTeam(team).where((r) => r.hasFullData).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return full.isEmpty ? null : full.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final records = [for (final t in teams) teamRecord(data.matches, t, qualsOnly: true)];
    final pits = [for (final t in teams) _pit(t)];

    String f1(double? v) => v == null ? '–' : v.toStringAsFixed(1);
    List<String> fmt(List<double?> v) => [for (final x in v) f1(x)];

    final sections = <(String, List<_Row>)>[
      (
        'Official (qualifications)',
        [
          _Row('Record', [for (final r in records) r.played == 0 ? null : r.wins / r.played],
              [for (final r in records) r.played == 0 ? '–' : r.label], bar: false),
          _Row('Avg RP / match', [for (final r in records) r.avgRp], fmt([for (final r in records) r.avgRp])),
          _Row('Avg alliance score', [for (final r in records) r.avgScore],
              fmt([for (final r in records) r.avgScore])),
          _Row('Avg hub fuel (alliance)', [for (final r in records) r.avgFuel],
              fmt([for (final r in records) r.avgFuel])),
        ]
      ),
      (
        'Pit scouting',
        [
          _Row('Drive train', [for (final _ in teams) null],
              [for (final p in pits) p == null ? '–' : p.driveTrain], bar: false),
          _Row('Fuel capacity', [for (final p in pits) p?.fuelCapacity.toDouble()],
              [for (final p in pits) p == null ? '–' : '${p.fuelCapacity}']),
          _Row('Hang level', [for (final p in pits) p == null ? null : (p.hangingWorks ? p.hangingLevel.toDouble() : 0)],
              [for (final p in pits) p == null ? '–' : (p.hangingWorks ? 'L${p.hangingLevel}' : 'No')]),
          _Row('Ground pickup', [for (final p in pits) p == null ? null : (p.groundPickup ? 1 : 0)],
              [for (final p in pits) p == null ? '–' : (p.groundPickup ? 'Yes' : 'No')], bar: false),
          _Row('Shoot on move', [for (final p in pits) p == null ? null : (p.shootOnMove ? 1 : 0)],
              [for (final p in pits) p == null ? '–' : (p.shootOnMove ? 'Yes' : 'No')], bar: false),
        ]
      ),
      (
        'Scouting',
        [
          _Row('Matches scouted', [for (final t in teams) data.statsFor(t)?.matchesScouted.toDouble() ?? 0],
              [for (final t in teams) '${data.statsFor(t)?.matchesScouted ?? 0}'], bar: false),
        ]
      ),
      for (final section in ScoutStats.sections)
        (
          section,
          [
            for (final d in ScoutStats.inSection(section))
              if (teams.any((t) => data.statsFor(t)?.mean(d.key) != null))
                _Row(
                  d.label,
                  [for (final t in teams) data.statsFor(t)?.mean(d.key)],
                  [for (final t in teams) formatStat(d, data.statsFor(t)?.mean(d.key))],
                  lowerBetter: _lowerIsBetter.contains(d.key),
                ),
          ]
        ),
    ];

    const labelWidth = 120.0;
    const colWidth = 84.0;
    return LayoutBuilder(builder: (context, c) {
      // Use the full width when there's room, otherwise scroll sideways.
      final col = ((c.maxWidth - labelWidth) / teams.length).clamp(colWidth, 200.0);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: labelWidth + col * teams.length,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const SizedBox(width: labelWidth),
                for (var i = 0; i < teams.length; i++)
                  SizedBox(
                    width: col,
                    child: Column(children: [
                      Container(height: 4, margin: const EdgeInsets.symmetric(horizontal: 8), color: _teamColors[i]),
                      const SizedBox(height: 4),
                      Text('${teams[i]}', style: theme.textTheme.titleMedium),
                    ]),
                  ),
              ]),
              for (final (title, rows) in sections)
                if (rows.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 4),
                    child: Text(title, style: theme.textTheme.titleSmall),
                  ),
                  for (final r in rows) _CompareRow(row: r, labelWidth: labelWidth, colWidth: col),
                ],
              const SizedBox(height: 8),
              Text('Bold = best of the group. Scouted values are averages per scouted match.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    });
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
    final best = row.lowerBetter ? lo : hi;
    final differs = present.length > 1 && hi != lo;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: labelWidth, child: Text(row.label, style: theme.textTheme.bodySmall)),
          for (var i = 0; i < row.values.length; i++)
            SizedBox(
              width: colWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.text[i],
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: differs && row.values[i] == best ? FontWeight.bold : FontWeight.normal)),
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
