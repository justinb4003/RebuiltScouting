import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../models/pit_result.dart';
import '../services/api_service.dart';
import '../build_info.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/team_details.dart';

class PitStatusScreen extends StatefulWidget {
  const PitStatusScreen({super.key});

  @override
  State<PitStatusScreen> createState() => _PitStatusScreenState();
}

class _PitStatusScreenState extends State<PitStatusScreen> {
  final _api = ApiService.instance;
  List<PitResult> _pitResults = [];
  bool _loading = false;
  String? _error;
  // null = all teams; kept across visits within a session.
  static bool? _showScouted;

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
      final results = await _api.getPitResults(eventKey);
      setState(() {
        _pitResults = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<PitResult> _resultsForTeam(int teamNumber) {
    return _pitResults.where((r) => r.teamNumber == teamNumber).toList();
  }

  /// Who scouted the team, e.g. "tess, caleb ×2".
  String _scouters(List<PitResult> results) {
    final counts = <String, int>{};
    for (final r in results) {
      final name = r.scouterName.isEmpty ? 'Unknown' : r.scouterName;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return counts.entries
        .map((e) => e.value > 1 ? '${e.key} ×${e.value}' : e.key)
        .join(', ');
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
    final teams = appState.teams;
    final theme = Theme.of(context);

    final scoutedCount =
        teams.where((t) => _resultsForTeam(t.teamNumber).isNotEmpty).length;
    final shown = _showScouted == null
        ? teams
        : teams
            .where((t) =>
                _resultsForTeam(t.teamNumber).isNotEmpty == _showScouted)
            .toList();

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
      drawer: const NavDrawer(selectedIndex: 7),
      body: Column(
        children: [
          if (teams.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('$scoutedCount / ${teams.length} teams scouted',
                  style: theme.textTheme.titleMedium),
            ),
          if (teams.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SegmentedButton<bool?>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: null, label: Text('All')),
                  ButtonSegment(value: true, label: Text('Scouted')),
                  ButtonSegment(value: false, label: Text('Unscouted')),
                ],
                selected: {_showScouted},
                onSelectionChanged: (v) =>
                    setState(() => _showScouted = v.first),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_error!,
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
          Expanded(
            child: teams.isEmpty
                ? const Center(child: Text('No teams loaded'))
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, index) {
                      final team = shown[index];
                      final results = _resultsForTeam(team.teamNumber);
                      final scouted = results.isNotEmpty;

                      // Material per row: ListTile.tileColor paints past
                      // the list's clip.
                      return Material(
                        color: index.isOdd
                            ? theme.colorScheme.surfaceContainerHigh
                            : Colors.transparent,
                        child: ListTile(
                        leading: Tooltip(
                          message: scouted
                              ? '${results.length} result${results.length == 1 ? '' : 's'}'
                              : 'Not scouted',
                          child: scouted
                              ? results.length > 1
                                  ? CircleAvatar(
                                      backgroundColor: Colors.green,
                                      radius: 14,
                                      child: Text('${results.length}',
                                          semanticsLabel: '${results.length} results',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)),
                                    )
                                  : const Icon(Icons.check_circle,
                                      color: Colors.green,
                                      semanticLabel: 'Scouted')
                              : const Icon(Icons.cancel, color: Colors.red,
                                  semanticLabel: 'Not scouted'),
                        ),
                        title: Row(
                          children: [
                            Text('${team.teamNumber}'),
                            TeamInfoButton(team.teamNumber),
                          ],
                        ),
                        subtitle: Text(team.nickname),
                        trailing: scouted
                            ? ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 180),
                                child: Text(
                                  _scouters(results),
                                  textAlign: TextAlign.end,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                ),
                              )
                            : null,
                        onTap: () =>
                            showTeamDetailsDialog(context, team.teamNumber),
                      ),
                      );
                    },
                  ),
          ),
          _refreshButton(),
        ],
      ),
    );
  }
}
