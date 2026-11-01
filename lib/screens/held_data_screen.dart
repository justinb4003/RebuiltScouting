import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/scout_result.dart';
import '../models/pit_result.dart';
import '../models/robot_note.dart';
import '../models/upload_status.dart';
import '../providers/app_state_provider.dart';
import '../services/storage_service.dart';
import '../services/upload_queue.dart';
import '../build_info.dart';
import '../widgets/nav_drawer.dart';

class HeldDataScreen extends StatefulWidget {
  const HeldDataScreen({super.key});

  @override
  State<HeldDataScreen> createState() => _HeldDataScreenState();
}

class _HeldDataScreenState extends State<HeldDataScreen> {
  final StorageService _storage = StorageService.instance;
  final UploadQueue _queue = UploadQueue.instance;

  List<ScoutResult> _heldScout = [];
  List<PitResult> _heldPit = [];
  List<RobotNote> _heldNotes = [];
  Map<String, UploadStatus> _status = {};

  @override
  void initState() {
    super.initState();
    // Background passes change the list; reload when one starts or ends.
    _queue.addListener(_loadData);
    _loadData();
  }

  @override
  void dispose() {
    _queue.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    final scout = await _storage.loadHeldScoutData();
    final pit = await _storage.loadHeldPitData();
    final notes = await _storage.loadHeldRobotNotes();
    final status = await _storage.loadUploadStatus();
    if (!mounted) return;
    setState(() {
      _heldScout = scout;
      _heldPit = pit;
      _heldNotes = notes;
      _status = status;
    });
  }

  // Same queue as the automatic uploads, so the two never run at once; if a
  // pass is already going this waits for it and runs one more.
  Future<void> _uploadNow() async {
    final result = await _queue.run();
    await _loadData();
    if (!mounted) return;
    final failed = result.rejected.length;
    final parts = [
      'Uploaded: ${result.uploaded.length}',
      if (failed > 0) 'Failed: $failed',
      if (result.offline) 'Stopped: no connection to the server',
    ];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(parts.join(', ')),
        backgroundColor: result.failed ? Colors.orange : Colors.green,
      ),
    );
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

  // The form doesn't count fuel (those fields are always 0), so summarize
  // what it does record.
  String _matchSummary(ScoutResult r) {
    if (r.robotNoShow) return 'No show | ${r.scouterName}';
    final volleys = r.volleyAccuracyList.length;
    final climb =
        r.endgameTowerLevel == 0 ? 'no climb' : 'climb L${r.endgameTowerLevel}';
    return '$volleys ${volleys == 1 ? 'volley' : 'volleys'} | $climb | '
        '${r.scouterName}';
  }

  /// [summary] plus, once an upload has failed, how often and why.
  Widget _subtitle(String id, String summary, {int maxLines = 1}) {
    final status = _status[id];
    final summaryText =
        Text(summary, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    if (status == null) return summaryText;
    final tries = status.attempts == 1 ? '1 try' : '${status.attempts} tries';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        summaryText,
        Text(
          'Not uploaded after $tries: ${status.lastError}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppStateProvider>();
    final uploading = context.watch<UploadQueue>().running;
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
      drawer: const NavDrawer(selectedIndex: 3),
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
                  if (totalHeld > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      uploading
                          ? 'Uploading…'
                          : 'These upload automatically when there is a connection.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed:
                        uploading || totalHeld == 0 ? null : _uploadNow,
                    icon: uploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_upload),
                    label: const Text('Upload now'),
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
                    subtitle: _subtitle(r.id, _matchSummary(r)),
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
                    subtitle: _subtitle(r.id,
                        '${r.driveTrain} drive${r.photoBase64 != null || r.photoInStore ? ' | photo' : ''}'),
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
                    subtitle: _subtitle(n.id, n.notes, maxLines: 2),
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
