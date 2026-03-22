import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../services/api_service.dart';
import '../build_info.dart';
import '../widgets/nav_drawer.dart';

class ScoutingStatusScreen extends StatefulWidget {
  const ScoutingStatusScreen({super.key});

  @override
  State<ScoutingStatusScreen> createState() => _ScoutingStatusScreenState();
}

class _ScoutingStatusScreenState extends State<ScoutingStatusScreen> {
  final _api = ApiService.instance;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final eventKey =
        context.read<AppStateProvider>().settings.selectedEventKey;
    if (eventKey == null || eventKey.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _api.getResults(eventKey);
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Returns list of scouter names for a given match key and team number.
  List<String> _scoutersFor(String matchKey, int matchNumber, int teamNumber) {
    return _results
        .where((r) {
          final team = r['scouting_team'] ?? r['team_number'];
          final mk = r['match_key'] ?? 'qm${r['match_number']}';
          return mk == matchKey && team == teamNumber;
        })
        .map((r) => (r['scouter_name'] ?? 'Unknown') as String)
        .toList();
  }

  void _showScouters(
      BuildContext context, String matchKey, int teamNumber, List<String> scouters) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$matchKey - Team $teamNumber'),
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(String matchKey, int matchNumber, int teamNumber) {
    final scouters = _scoutersFor(matchKey, matchNumber, teamNumber);
    final count = scouters.length;

    if (count == 0) {
      return const Center(
        child: Tooltip(
          message: 'Not scouted',
          child: Icon(Icons.cancel, color: Colors.red, size: 20,
              semanticLabel: 'Not scouted'),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showScouters(context, matchKey, teamNumber, scouters),
      child: Center(
        child: Tooltip(
          message: '$count scouter${count == 1 ? '' : 's'} — tap for details',
          child: count == 1
              ? const Icon(Icons.check_circle, color: Colors.green, size: 20,
                  semanticLabel: 'Scouted')
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
        ),
      ),
    );
  }

  Widget _refreshButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: FilledButton.icon(
          onPressed: _loading ? null : _refresh,
          icon: _loading
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
      drawer: const NavDrawer(selectedIndex: 4),
      body: Column(
        children: [
          _refreshButton(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_error!,
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
          Expanded(
            child: matches.isEmpty
                ? const Center(child: Text('No matches loaded'))
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 12,
                        headingRowHeight: 40,
                        dataRowMinHeight: 36,
                        dataRowMaxHeight: 36,
                        columns: [
                          const DataColumn(label: Text('Match')),
                          ...columnLabels.asMap().entries.map((e) => DataColumn(
                                label: Text(
                                  e.value,
                                  style: TextStyle(
                                    color: e.key < 3 ? blueColor : redColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )),
                        ],
                        rows: matches.map((match) {
                          final matchKey = '${match.compLevel}${match.matchNumber}';
                          final teams = [
                            ...match.blueTeams
                                .map((t) => int.tryParse(t) ?? 0),
                            ...match.redTeams
                                .map((t) => int.tryParse(t) ?? 0),
                          ];
                          // Pad to 6 if needed
                          while (teams.length < 6) {
                            teams.add(0);
                          }

                          return DataRow(cells: [
                            DataCell(Text(match.displayName)),
                            ...teams.take(6).map(
                                (t) => DataCell(_buildCell(matchKey, match.matchNumber, t))),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
          ),
          _refreshButton(),
        ],
      ),
    );
  }
}
