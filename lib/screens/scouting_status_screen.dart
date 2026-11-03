import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/event_data_provider.dart';
import '../build_info.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/team_details.dart';

class ScoutingStatusScreen extends StatefulWidget {
  const ScoutingStatusScreen({super.key});

  @override
  State<ScoutingStatusScreen> createState() => _ScoutingStatusScreenState();
}

class _ScoutingStatusScreenState extends State<ScoutingStatusScreen> {
  @override
  void initState() {
    super.initState();
    // Scouted rows come from EventDataProvider: cached per event, filtered to
    // our secret key, fetched at most once per session unless refreshed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.ensureEventData();
    });
  }

  /// Scouter names by qual match number, then team, built in one pass.
  static Map<int, Map<int, List<String>>> _index(EventDataProvider data) {
    final out = <int, Map<int, List<String>>>{};
    for (final r in data.scouted) {
      (out.putIfAbsent(r.matchNumber, () => {})[r.teamNumber] ??= [])
          .add(r.scouterName.isEmpty ? 'Unknown' : r.scouterName);
    }
    return out;
  }

  void _showScouters(
      BuildContext context, String matchKey, int teamNumber, List<String> scouters) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Flexible(child: Text('$matchKey - Team $teamNumber')),
            TeamInfoButton(teamNumber),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${scouters.length} result${scouters.length == 1 ? '' : 's'}:',
                style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...scouters.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 16),
                      const SizedBox(width: 8),
                      Text(s),
                    ],
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              showTeamDetailsDialog(context, teamNumber);
            },
            child: const Text('Team details'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(String matchKey, List<String> scouters, int teamNumber) {
    final count = scouters.length;
    if (count == 0) {
      return const Icon(Icons.cancel,
          color: Colors.red, size: 20, semanticLabel: 'Not scouted');
    }
    return GestureDetector(
      onTap: () => _showScouters(context, matchKey, teamNumber, scouters),
      child: count == 1
          ? const Icon(Icons.check_circle,
              color: Colors.green, size: 20, semanticLabel: 'Scouted')
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                semanticsLabel: '$count scouters',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
    );
  }

  static const _matchWidth = 88.0;
  static const _cellWidth = 40.0;

  /// One grid line: match label, then six fixed-width team cells.
  Widget _row(Widget label, List<Widget> cells, {Color? color}) => Container(
        height: 36,
        color: color,
        child: Row(
          children: [
            SizedBox(width: _matchWidth, child: Center(child: label)),
            for (final c in cells)
              SizedBox(width: _cellWidth, child: Center(child: c)),
          ],
        ),
      );

  Widget _refreshButton(EventDataProvider data) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: FilledButton.icon(
          onPressed: data.loading ? null : data.refresh,
          icon: data.loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final data = context.watch<EventDataProvider>();
    final scouted = _index(data);
    final matches = appState.matches
        .where((m) => m.compLevel == 'qm')
        .toList()
      ..sort((a, b) => a.matchNumber.compareTo(b.matchNumber));
    final theme = Theme.of(context);

    const columnLabels = ['B1', 'B2', 'B3', 'R1', 'R2', 'R3'];
    const blueColor = Color(0xFF1565C0);
    const redColor = Color(0xFFC62828);

    return Scaffold(
      appBar: AppBar(
        title: Text(appState.settings.selectedEventName ??
            'Configure Event to Continue...'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              'Updated $buildTimestamp',
              style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
      drawer: const NavDrawer(selectedIndex: 6),
      body: Column(
        children: [
          for (final e in [data.error, appState.error])
            if (e != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(e,
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
          Expanded(
            child: matches.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No matches loaded'),
                        const SizedBox(height: 12),
                        // The schedule normally loads when the event is picked.
                        OutlinedButton.icon(
                          onPressed:
                              appState.loading ? null : appState.loadMatches,
                          icon: const Icon(Icons.event_note),
                          label: const Text('Load match schedule'),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: SizedBox(
                      width: _matchWidth + 6 * _cellWidth,
                      child: Column(
                        children: [
                          _row(
                            Text('Match', style: theme.textTheme.titleSmall),
                            [
                              for (final (i, label) in columnLabels.indexed)
                                Text(label,
                                    style: TextStyle(
                                      color: i < 3 ? blueColor : redColor,
                                      fontWeight: FontWeight.bold,
                                    )),
                            ],
                          ),
                          const Divider(height: 1),
                          // Lazy: only the rows on screen get built.
                          Expanded(
                            child: ListView.builder(
                              itemCount: matches.length,
                              itemBuilder: (context, i) {
                                final match = matches[i];
                                final matchKey =
                                    '${match.compLevel}${match.matchNumber}';
                                final teams = [
                                  ...match.blueTeams
                                      .map((t) => int.tryParse(t) ?? 0),
                                  ...match.redTeams
                                      .map((t) => int.tryParse(t) ?? 0),
                                ];
                                while (teams.length < 6) {
                                  teams.add(0);
                                }
                                final byTeam = scouted[match.matchNumber];
                                return _row(
                                  color: i.isOdd
                                      ? theme.colorScheme.surfaceContainerHigh
                                      : null,
                                  Text(match.displayName),
                                  [
                                    for (final t in teams.take(6))
                                      _buildCell(matchKey,
                                          byTeam?[t] ?? const [], t),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          _refreshButton(data),
        ],
      ),
    );
  }
}
