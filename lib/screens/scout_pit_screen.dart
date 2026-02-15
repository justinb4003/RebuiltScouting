import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/pit_provider.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/team_selector.dart';

class ScoutPitScreen extends StatelessWidget {
  const ScoutPitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final pit = context.watch<PitProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(appState.settings.selectedEventName ?? 'Configure Event to Continue...'),
        // TODO: Re-enable once scouted teams feature is ready
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.refresh),
        //     tooltip: 'Load scouted teams',
        //     onPressed: appState.settings.selectedEventKey != null
        //         ? () =>
        //             pit.loadScoutedTeams(appState.settings.selectedEventKey!)
        //         : null,
        //   ),
        // ],
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
                    SegmentedButton<String>(
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
            Container(
              decoration: BoxDecoration(
                color: pit.canCrossRamp
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SwitchListTile(
                title: const Text('Can Cross Ramp'),
                value: pit.canCrossRamp,
                onChanged: (v) =>
                    pit.updateField(() => pit.canCrossRamp = v),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: pit.canEnterTrench
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SwitchListTile(
                title: const Text('Can Enter Trench'),
                value: pit.canEnterTrench,
                onChanged: (v) =>
                    pit.updateField(() => pit.canEnterTrench = v),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: pit.groundPickup
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SwitchListTile(
                title: const Text('Ground Pickup'),
                value: pit.groundPickup,
                onChanged: (v) =>
                    pit.updateField(() => pit.groundPickup = v),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: pit.humanPlayerPickup
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SwitchListTile(
                title: const Text('Human Player Pickup'),
                value: pit.humanPlayerPickup,
                onChanged: (v) =>
                    pit.updateField(() => pit.humanPlayerPickup = v),
              ),
            ),
            const SizedBox(height: 16),

            // Fuel capacity
            TextField(
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

            // Notes
            TextField(
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (v) => pit.updateField(() => pit.notes = v),
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
