import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/scout_result.dart';
import '../models/pit_result.dart';
import '../providers/app_state_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../build_info.dart';
import '../widgets/nav_drawer.dart';

class HeldDataScreen extends StatefulWidget {
  const HeldDataScreen({super.key});

  @override
  State<HeldDataScreen> createState() => _HeldDataScreenState();
}

class _HeldDataScreenState extends State<HeldDataScreen> {
  final StorageService _storage = StorageService.instance;
  final ApiService _api = ApiService.instance;

  List<ScoutResult> _heldScout = [];
  List<PitResult> _heldPit = [];
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final scout = await _storage.loadHeldScoutData();
    final pit = await _storage.loadHeldPitData();
    setState(() {
      _heldScout = scout;
      _heldPit = pit;
    });
  }

  Future<(int, int)> _uploadItems<T>(
    List<T> items,
    Future<bool> Function(T) post,
    Future<void> Function(String) remove,
    String Function(T) getId,
  ) async {
    int success = 0, fail = 0;
    for (final item in List.of(items)) {
      try {
        if (await post(item)) {
          await remove(getId(item));
          success++;
        } else {
          fail++;
        }
      } catch (_) {
        fail++;
      }
    }
    return (success, fail);
  }

  Future<void> _uploadAll() async {
    setState(() => _uploading = true);

    final (s1, f1) = await _uploadItems(
      _heldScout, _api.postResults, _storage.removeHeldScoutResult, (r) => r.id);
    final (s2, f2) = await _uploadItems(
      _heldPit, _api.postPitResults, _storage.removeHeldPitResult, (r) => r.id);

    final successCount = s1 + s2;
    final failCount = f1 + f2;

    await _loadData();
    setState(() => _uploading = false);
    if (mounted) {
      context.read<AppStateProvider>().refreshHeldDataCount();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Uploaded: $successCount, Failed: $failCount'),
          backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  Future<void> _deleteResult(Future<void> Function(String) removeFn, String id) async {
    await removeFn(id);
    await _loadData();
    if (mounted) {
      context.read<AppStateProvider>().refreshHeldDataCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppStateProvider>();
    final totalHeld = _heldScout.length + _heldPit.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(appState.settings.selectedEventName ?? 'Configure Event to Continue...'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              'Updated $buildTimestamp',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
      drawer: const NavDrawer(selectedIndex: 2),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '$totalHeld items queued',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                      '${_heldScout.length} match results, ${_heldPit.length} pit results'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed:
                        _uploading || totalHeld == 0 ? null : _uploadAll,
                    icon: _uploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_upload),
                    label: const Text('Upload All'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Match scouting entries
          if (_heldScout.isNotEmpty) ...[
            Text('Match Scouting', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._heldScout.map((r) => Card(
                  child: ListTile(
                    title: Text('Match ${r.matchNumber} - Team ${r.teamNumber}'),
                    subtitle: Text(
                        'Auto: ${r.autoFuelScored} scored | Teleop: ${r.teleopFuelScored} scored'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteResult(_storage.removeHeldScoutResult, r.id),
                    ),
                  ),
                )),
            const SizedBox(height: 16),
          ],

          // Pit scouting entries
          if (_heldPit.isNotEmpty) ...[
            Text('Pit Scouting', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._heldPit.map((r) => Card(
                  child: ListTile(
                    title: Text('Team ${r.teamNumber}'),
                    subtitle: Text('${r.driveTrain} drive'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteResult(_storage.removeHeldPitResult, r.id),
                    ),
                  ),
                )),
          ],

          if (totalHeld == 0)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No held data. All submissions are up to date!',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
