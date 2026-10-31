import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/robot_note.dart';
import '../models/submit_result.dart';
import '../providers/app_state_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../build_info.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/team_selector.dart';

class RobotNoteScreen extends StatefulWidget {
  const RobotNoteScreen({super.key});

  @override
  State<RobotNoteScreen> createState() => _RobotNoteScreenState();
}

class _RobotNoteScreenState extends State<RobotNoteScreen> {
  final _notesController = TextEditingController();
  int? _selectedTeamNumber;
  bool _submitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<SubmitResult> _submit(AppStateProvider appState) async {
    if (_selectedTeamNumber == null) {
      return SubmitResult(success: false, message: 'No team selected');
    }
    if (_notesController.text.trim().isEmpty) {
      return SubmitResult(success: false, message: 'Please enter a note');
    }

    setState(() => _submitting = true);

    final api = ApiService.instance;
    final storage = StorageService.instance;

    final note = RobotNote(
      scouterName: appState.settings.scouterName,
      secretTeamKey: appState.settings.secretTeamKey,
      eventKey: appState.settings.selectedEventKey ?? '',
      teamNumber: _selectedTeamNumber!,
      notes: _notesController.text.trim(),
    );

    try {
      var saved = true;
      try {
        await storage.addHeldRobotNote(note);
      } catch (e) {
        debugPrint('Saving robot note locally failed: $e');
        saved = false;
      }

      try {
        await api.postRobotNote(note);
        if (saved) {
          await storage.removeHeldRobotNote(note.id).catchError((Object e) {
            debugPrint('Removing held robot note failed: $e');
          });
        }
        return SubmitResult(
            success: true, uploaded: true, message: uploadedMessage);
      } catch (e) {
        debugPrint('Robot note submit error: $e');
      }
      return SubmitResult(
          success: saved,
          message: saved ? savedLocallyMessage : notSavedMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(appState.settings.selectedEventName ??
            'Configure Event to Continue...'),
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
      drawer: const NavDrawer(selectedIndex: 6),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TeamSelector(
            teams: appState.teams,
            selectedTeamNumber: _selectedTeamNumber,
            onChanged: (v) => setState(() => _selectedTeamNumber = v),
          ),
          if (_selectedTeamNumber != null) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'What did you notice about this robot?',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: OutlineInputBorder(),
              ),
              maxLines: 6,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _submitting
                  ? null
                  : () async {
                      final result = await _submit(appState);
                      if (context.mounted) {
                        appState.refreshHeldDataCount();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result.message),
                            backgroundColor:
                                result.uploaded
                                ? Colors.green
                                : result.success
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        );
                        if (result.success) {
                          _notesController.clear();
                          setState(() => _selectedTeamNumber = null);
                        }
                      }
                    },
              icon: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: const Text('Submit'),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }
}
