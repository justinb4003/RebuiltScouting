import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../models/pit_result.dart';
import '../services/api_service.dart';
import '../build_info.dart';
import '../widgets/nav_drawer.dart';

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

  void _showScouters(BuildContext context, int teamNumber, List<PitResult> results) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Team $teamNumber'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${results.length} result${results.length == 1 ? '' : 's'}:',
                style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...results.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 16),
                      const SizedBox(width: 8),
                      Text(r.scouterName.isEmpty ? 'Unknown' : r.scouterName),
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
      drawer: const NavDrawer(selectedIndex: 5),
      body: Column(
        children: [
          _refreshButton(),
          if (teams.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('$scoutedCount / ${teams.length} teams scouted',
                  style: theme.textTheme.titleMedium),
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
                    itemCount: teams.length,
                    itemBuilder: (context, index) {
                      final team = teams[index];
                      final results = _resultsForTeam(team.teamNumber);
                      final scouted = results.isNotEmpty;

                      return ListTile(
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
                        title: Text('${team.teamNumber}'),
                        subtitle: Text(team.nickname),
                        onTap: scouted
                            ? () => _showScouters(
                                context, team.teamNumber, results)
                            : null,
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
