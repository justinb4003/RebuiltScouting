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
        title: const Text('Scout Pit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Load scouted teams',
            onPressed: appState.settings.selectedEventKey != null
                ? () =>
                    pit.loadScoutedTeams(appState.settings.selectedEventKey!)
                : null,
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
                        pit.updateField(() => pit.driveTrain = v.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Wheel Types
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Wheel Types', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: PitProvider.wheelTypeOptions.map((wt) {
                      final selected = pit.wheelTypes.contains(wt);
                      return FilterChip(
                        label: Text(wt),
                        selected: selected,
                        onSelected: (_) => pit.toggleWheelType(wt),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Robot Rating
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Robot Rating: ${pit.robotRating}',
                      style: theme.textTheme.titleMedium),
                  Slider(
                    value: pit.robotRating.toDouble(),
                    min: -10,
                    max: 10,
                    divisions: 20,
                    label: '${pit.robotRating}',
                    onChanged: (v) =>
                        pit.updateField(() => pit.robotRating = v.round()),
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text('-10'), Text('0'), Text('+10')],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Capabilities
          SwitchListTile(
            title: const Text('Can Cross Bump'),
            value: pit.canCrossBump,
            onChanged: (v) =>
                pit.updateField(() => pit.canCrossBump = v),
          ),
          SwitchListTile(
            title: const Text('Can Enter Trench'),
            value: pit.canEnterTrench,
            onChanged: (v) =>
                pit.updateField(() => pit.canEnterTrench = v),
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
          const SizedBox(height: 24),

          // Already scouted teams
          if (pit.scoutedTeams.isNotEmpty) ...[
            Text('Already Scouted', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: pit.scoutedTeams
                  .map((r) => Chip(label: Text('${r.teamNumber}')))
                  .toList(),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
