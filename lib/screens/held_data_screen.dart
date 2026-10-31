import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/scout_result.dart';
import '../models/pit_result.dart';
import '../models/robot_note.dart';
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
  List<RobotNote> _heldNotes = [];
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final scout = await _storage.loadHeldScoutData();
    final pit = await _storage.loadHeldPitData();
    final notes = await _storage.loadHeldRobotNotes();
    if (!mounted) return;
    setState(() {
      _heldScout = scout;
      _heldPit = pit;
      _heldNotes = notes;
    });
  }

  int _uploaded = 0, _failed = 0;
  bool _offline = false;

  // Stops at the first item that can't reach the server: on bad Wi-Fi the
  // rest would each just wait out their own timeout.
  Future<void> _uploadItems<T>(
    List<T> items,
    Future<void> Function(T) post,
    Future<void> Function(String) remove,
    String Function(T) getId,
  ) async {
    for (final item in List.of(items)) {
      if (_offline) return;
      try {
        await post(item);
        await remove(getId(item));
        _uploaded++;
      } on ApiStatusException catch (e) {
        _failed++;
        if (e.transient) _offline = true;
      } catch (e) {
        debugPrint('Held upload failed: $e');
        _failed++;
        _offline = true;
      }
    }
  }

  Future<void> _uploadAll() async {
    setState(() => _uploading = true);
    _uploaded = _failed = 0;
    _offline = false;

    await _uploadItems(
      _heldScout, _api.postResults, _storage.removeHeldScoutResult, (r) => r.id);
    await _uploadItems(
      _heldPit, _api.postPitResults, _storage.removeHeldPitResult, (r) => r.id);
    await _uploadItems(
      _heldNotes, _api.postRobotNote, _storage.removeHeldRobotNote, (n) => n.id);

    final successCount = _uploaded;
    final failCount = _failed;

    await _loadData();
    if (mounted) {
      setState(() => _uploading = false);
      context.read<AppStateProvider>().refreshHeldDataCount();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Uploaded: $successCount, Failed: $failCount'
              '${_offline ? '. Stopped: no connection to the server.' : ''}'),
          backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  Future<void> _deleteResult(
      Future<void> Function(String) removeFn, String id, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Unsent Data?'),
        content: Text('$label has not been uploaded. Deleting it here '
            'removes it for good.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
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
    final totalHeld = _heldScout.length + _heldPit.length + _heldNotes.length;

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
                      '${_heldScout.length} match, ${_heldPit.length} pit, ${_heldNotes.length} notes'),
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
                      onPressed: () => _deleteResult(_storage.removeHeldScoutResult, r.id,
                          'Match ${r.matchNumber}, team ${r.teamNumber}'),
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
                      onPressed: () => _deleteResult(_storage.removeHeldPitResult, r.id,
                          'Pit data for team ${r.teamNumber}'),
                    ),
                  ),
                )),
            const SizedBox(height: 16),
          ],

          // Robot note entries
          if (_heldNotes.isNotEmpty) ...[
            Text('Robot Notes', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._heldNotes.map((n) => Card(
                  child: ListTile(
                    title: Text('Team ${n.teamNumber}'),
                    subtitle: Text(n.notes, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteResult(_storage.removeHeldRobotNote, n.id,
                          'This note for team ${n.teamNumber}'),
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
