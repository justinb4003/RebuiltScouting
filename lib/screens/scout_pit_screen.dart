import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/pit_provider.dart';
import '../widgets/fixed_segmented_button.dart';
import '../widgets/highlighted_switch.dart';
import '../build_info.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/team_selector.dart';

class ScoutPitScreen extends StatefulWidget {
  const ScoutPitScreen({super.key});

  @override
  State<ScoutPitScreen> createState() => _ScoutPitScreenState();
}

class _ScoutPitScreenState extends State<ScoutPitScreen> {
  final _driveTrainOtherController = TextEditingController();
  final _fuelCapacityController = TextEditingController();
  final _hangingTimeController = TextEditingController();
  final _hangingHowController = TextEditingController();
  final _teleopActiveController = TextEditingController();
  final _teleopInactiveController = TextEditingController();
  final _hopperEmptyTimeController = TextEditingController();
  final _funQuestionController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _driveTrainOtherController.dispose();
    _fuelCapacityController.dispose();
    _hangingTimeController.dispose();
    _hangingHowController.dispose();
    _teleopActiveController.dispose();
    _teleopInactiveController.dispose();
    _hopperEmptyTimeController.dispose();
    _funQuestionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _clearControllers() {
    _driveTrainOtherController.clear();
    _fuelCapacityController.clear();
    _hangingTimeController.clear();
    _hangingHowController.clear();
    _teleopActiveController.clear();
    _teleopInactiveController.clear();
    _hopperEmptyTimeController.clear();
    _funQuestionController.clear();
    _notesController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final pit = context.watch<PitProvider>();
    final theme = Theme.of(context);

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
      drawer: const NavDrawer(selectedIndex: 1),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Team Selection
          TeamSelector(
            teams: appState.teams,
            selectedTeamNumber: pit.selectedTeamNumber,
            onChanged: (v) =>
                pit.updateField(() => pit.selectedTeamNumber = v),
          ),
          if (pit.selectedTeamNumber != null) ...[
            const SizedBox(height: 16),

            // Drive Train
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Drive Train', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    FixedSegmentedButton<String>(
                      segments: PitProvider.driveTrainOptions
                          .map((dt) =>
                              ButtonSegment(value: dt, label: Text(dt)))
                          .toList(),
                      selected: {pit.driveTrain},
                      onSelectionChanged: (v) =>
                          pit.updateField(() {
                            pit.driveTrain = v.first;
                            if (v.first != 'Other') pit.driveTrainOther = '';
                          }),
                    ),
                    if (pit.driveTrain == 'Other') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _driveTrainOtherController,
                        decoration: const InputDecoration(
                          labelText: 'Specify Drive Train',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) =>
                            pit.updateField(() => pit.driveTrainOther = v),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Capabilities
            HighlightedSwitch(
              title: 'Ground Pickup',
              value: pit.groundPickup,
              onChanged: (v) =>
                  pit.updateField(() => pit.groundPickup = v),
            ),
            HighlightedSwitch(
              title: 'Human Player Pickup',
              value: pit.humanPlayerPickup,
              onChanged: (v) =>
                  pit.updateField(() => pit.humanPlayerPickup = v),
            ),
            const SizedBox(height: 16),

            // Fuel capacity
            TextField(
              controller: _fuelCapacityController,
              decoration: const InputDecoration(
                labelText: 'Fuel Cell Capacity',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) => pit.updateField(
                  () => pit.fuelCapacity = int.tryParse(v) ?? 0),
            ),
            const SizedBox(height: 16),

            // Auton
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Auton', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Text('Auton Start Positions', style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 4),
                    HighlightedSwitch(
                      title: 'Left Trench',
                      dense: true,
                      value: pit.autoStartLeftTrench,
                      onChanged: (v) =>
                          pit.updateField(() => pit.autoStartLeftTrench = v),
                    ),
                    if (pit.autoStartLeftTrench)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'The (auton position) accomplishes (objective) because it does (what it does)',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                          onChanged: (v) =>
                              pit.updateField(() => pit.autoNotesLeftTrench = v),
                        ),
                      ),
                    HighlightedSwitch(
                      title: 'Left Bump',
                      dense: true,
                      value: pit.autoStartLeftBump,
                      onChanged: (v) =>
                          pit.updateField(() => pit.autoStartLeftBump = v),
                    ),
                    if (pit.autoStartLeftBump)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'The (auton position) accomplishes (objective) because it does (what it does)',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                          onChanged: (v) =>
                              pit.updateField(() => pit.autoNotesLeftBump = v),
                        ),
                      ),
                    HighlightedSwitch(
                      title: 'Hub',
                      dense: true,
                      value: pit.autoStartHub,
                      onChanged: (v) =>
                          pit.updateField(() => pit.autoStartHub = v),
                    ),
                    if (pit.autoStartHub)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'The (auton position) accomplishes (objective) because it does (what it does)',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                          onChanged: (v) =>
                              pit.updateField(() => pit.autoNotesHub = v),
                        ),
                      ),
                    HighlightedSwitch(
                      title: 'Right Bump',
                      dense: true,
                      value: pit.autoStartRightBump,
                      onChanged: (v) =>
                          pit.updateField(() => pit.autoStartRightBump = v),
                    ),
                    if (pit.autoStartRightBump)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'The (auton position) accomplishes (objective) because it does (what it does)',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                          onChanged: (v) =>
                              pit.updateField(() => pit.autoNotesRightBump = v),
                        ),
                      ),
                    HighlightedSwitch(
                      title: 'Right Trench',
                      dense: true,
                      value: pit.autoStartRightTrench,
                      onChanged: (v) =>
                          pit.updateField(() => pit.autoStartRightTrench = v),
                    ),
                    if (pit.autoStartRightTrench)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'The (auton position) accomplishes (objective) because it does (what it does)',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                          onChanged: (v) =>
                              pit.updateField(() => pit.autoNotesRightTrench = v),
                        ),
                      ),
                    const SizedBox(height: 12),
                    HighlightedSwitch(
                      title: 'Concerned about crashing in auton',
                      value: pit.autoCrashConcern,
                      onChanged: (v) =>
                          pit.updateField(() => pit.autoCrashConcern = v),
                    ),
                    const SizedBox(height: 12),
                    HighlightedSwitch(
                      title: 'Hang in Auto',
                      value: pit.autoHang,
                      onChanged: (v) =>
                          pit.updateField(() => pit.autoHang = v),
                    ),
                    if (pit.autoHang) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'From which start position?',
                            border: OutlineInputBorder(),
                          ),
                          value: pit.autoHangPosition.isEmpty ? null : pit.autoHangPosition,
                          items: const [
                            DropdownMenuItem(value: 'Left Trench', child: Text('Left Trench')),
                            DropdownMenuItem(value: 'Left Bump', child: Text('Left Bump')),
                            DropdownMenuItem(value: 'Hub', child: Text('Hub')),
                            DropdownMenuItem(value: 'Right Bump', child: Text('Right Bump')),
                            DropdownMenuItem(value: 'Right Trench', child: Text('Right Trench')),
                          ],
                          onChanged: (v) =>
                              pit.updateField(() => pit.autoHangPosition = v ?? ''),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Hanging
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hanging', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    HighlightedSwitch(
                      title: 'Does it work?',
                      value: pit.hangingWorks,
                      onChanged: (v) => pit.updateField(() {
                        pit.hangingWorks = v;
                        if (!v) pit.hangingLevel = 1;
                      }),
                    ),
                    if (pit.hangingWorks) ...[
                      const SizedBox(height: 8),
                      FixedSegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 1, label: Text('L1')),
                          ButtonSegment(value: 2, label: Text('L2')),
                          ButtonSegment(value: 3, label: Text('L3')),
                        ],
                        selected: {pit.hangingLevel},
                        onSelectionChanged: (v) =>
                            pit.updateField(() => pit.hangingLevel = v.first),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _hangingTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Hanging Time',
                        hintText: 'How much time does it take?',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) =>
                          pit.updateField(() => pit.hangingTime = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _hangingHowController,
                      decoration: const InputDecoration(
                        labelText: 'Hanging Method',
                        hintText: 'How does it work?',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) =>
                          pit.updateField(() => pit.hangingHow = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Teleop A
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Teleop A', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _teleopActiveController,
                      decoration: const InputDecoration(
                        labelText: 'Teleop Active',
                        hintText: 'Goal/plan',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      onChanged: (v) =>
                          pit.updateField(() => pit.teleopActivePlan = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Teleop I
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Teleop I', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _teleopInactiveController,
                      decoration: const InputDecoration(
                        labelText: 'Teleop Inactive',
                        hintText: 'Goal/plan',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      onChanged: (v) =>
                          pit.updateField(() => pit.teleopInactivePlan = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Defense
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Defense', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    HighlightedSwitch(
                      title: 'Would you be willing to play defense?',
                      value: pit.willingToPlayDefense,
                      onChanged: (v) =>
                          pit.updateField(() => pit.willingToPlayDefense = v),
                    ),
                    HighlightedSwitch(
                      title: 'Would you rather play defense?',
                      value: pit.ratherPlayDefense,
                      onChanged: (v) =>
                          pit.updateField(() => pit.ratherPlayDefense = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Overall
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overall', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    HighlightedSwitch(
                      title: 'Can you shoot on the move?',
                      value: pit.shootOnMove,
                      onChanged: (v) =>
                          pit.updateField(() => pit.shootOnMove = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _hopperEmptyTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Hopper Empty Time',
                        hintText: 'How long does it take for you to empty your hopper? (BPS)',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) =>
                          pit.updateField(() => pit.hopperEmptyTime = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _funQuestionController,
                      decoration: const InputDecoration(
                        labelText: 'Fun Question',
                        hintText: 'Dont be stupid',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) =>
                          pit.updateField(() => pit.funQuestion = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Any additional observations about this robot?',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (v) =>
                  pit.updateField(() => pit.notes = v),
            ),
            const SizedBox(height: 16),

            // Photo
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Photo', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => pit.capturePhoto(),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonalIcon(
                          onPressed: () => pit.pickPhoto(),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                        ),
                      ],
                    ),
                    if (pit.photoBytes != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          pit.photoBytes!,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Submit
            FilledButton.icon(
              onPressed: pit.submitting
                  ? null
                  : () async {
                      final result = await pit.submit(
                        scouterName: appState.settings.scouterName,
                        secretTeamKey: appState.settings.secretTeamKey,
                        eventKey: appState.settings.selectedEventKey ?? '',
                      );
                      if (context.mounted) {
                        appState.refreshHeldDataCount();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result.message),
                            backgroundColor:
                                result.success ? Colors.green : Colors.red,
                          ),
                        );
                        if (result.success) {
                          pit.resetForm();
                          _clearControllers();
                        }
                      }
                    },
              icon: pit.submitting
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
