import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/scouting_provider.dart';
import '../theme.dart';
import '../widgets/counter_button.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/team_selector.dart';

class ScoutMatchScreen extends StatefulWidget {
  const ScoutMatchScreen({super.key});

  @override
  State<ScoutMatchScreen> createState() => _ScoutMatchScreenState();
}

class _ScoutMatchScreenState extends State<ScoutMatchScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _fireConfetti() {
    _confettiController.stop();
    _confettiController.play();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final scouting = context.watch<ScoutingProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Scout Match')),
      drawer: const NavDrawer(selectedIndex: 0),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Match & Team Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Match Setup',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Match #',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              controller: TextEditingController(
                                  text: '${scouting.matchNumber}'),
                              onChanged: (v) {
                                final n = int.tryParse(v);
                                if (n != null) {
                                  scouting.updateField(
                                      () => scouting.matchNumber = n);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TeamSelector(
                        teams: appState.teams,
                        selectedTeamNumber: scouting.selectedTeamNumber,
                        onChanged: (v) => scouting.updateField(
                            () => scouting.selectedTeamNumber = v),
                      ),
                      const SizedBox(height: 12),
                      if (!scouting.scoutingActive)
                        FilledButton.icon(
                          onPressed: scouting.selectedTeamNumber != null
                              ? () => scouting.beginScouting()
                              : null,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Begin Scouting'),
                        ),
                    ],
                  ),
                ),
              ),

              if (scouting.scoutingActive) ...[
                const SizedBox(height: 16),

                // Auto Section
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: AppTheme.autoColor.withValues(alpha: 0.5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('Autonomous',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: AppTheme.autoColor)),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('Did nothing'),
                          value: scouting.autoLeave,
                          onChanged: (v) => scouting
                              .updateField(() => scouting.autoLeave = v),
                        ),
                        CounterButton(
                          label: 'Fuel Scored',
                          value: scouting.autoFuelScored,
                          showBulkButtons: true,
                          onTap: _fireConfetti,
                          onChanged: (v) => scouting.updateField(
                              () => scouting.autoFuelScored = v),
                        ),
                        const SizedBox(height: 8),
                        CounterButton(
                          label: 'Fuel Missed',
                          value: scouting.autoFuelMissed,
                          showBulkButtons: true,
                          onTap: _fireConfetti,
                          onChanged: (v) => scouting.updateField(
                              () => scouting.autoFuelMissed = v),
                        ),
                        SwitchListTile(
                          title: const Text('Tower L1 (15 pts)'),
                          value: scouting.autoTowerLevel1,
                          onChanged: (v) => scouting.updateField(
                              () => scouting.autoTowerLevel1 = v),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Teleop Section
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color:
                            AppTheme.teleopColor.withValues(alpha: 0.5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('Teleop',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: AppTheme.teleopColor)),
                        const SizedBox(height: 12),
                        CounterButton(
                          label: 'Fuel Scored',
                          value: scouting.teleopFuelScored,
                          showBulkButtons: true,
                          onTap: _fireConfetti,
                          onChanged: (v) => scouting.updateField(
                              () => scouting.teleopFuelScored = v),
                        ),
                        const SizedBox(height: 8),
                        CounterButton(
                          label: 'Fuel Missed',
                          value: scouting.teleopFuelMissed,
                          showBulkButtons: true,
                          onTap: _fireConfetti,
                          onChanged: (v) => scouting.updateField(
                              () => scouting.teleopFuelMissed = v),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Endgame Section
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color:
                            AppTheme.endgameColor.withValues(alpha: 0.5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('Endgame',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: AppTheme.endgameColor)),
                        const SizedBox(height: 12),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 0, label: Text('None')),
                            ButtonSegment(value: 1, label: Text('L1')),
                            ButtonSegment(value: 2, label: Text('L2')),
                            ButtonSegment(value: 3, label: Text('L3')),
                          ],
                          selected: {scouting.endgameTowerLevel},
                          onSelectionChanged: (v) => scouting.updateField(
                              () => scouting.endgameTowerLevel = v.first),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Pickup & Defense
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('Capabilities',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        SwitchListTile(
                          title: const Text('Ground Pickup'),
                          dense: true,
                          value: scouting.fuelGroundPickup,
                          onChanged: (v) => scouting.updateField(
                              () => scouting.fuelGroundPickup = v),
                        ),
                        SwitchListTile(
                          title: const Text('Human Player Pickup'),
                          dense: true,
                          value: scouting.fuelHumanPickup,
                          onChanged: (v) => scouting.updateField(
                              () => scouting.fuelHumanPickup = v),
                        ),
                        const SizedBox(height: 4),
                        Text(
                            'Defense Rating: ${scouting.defenseRating}',
                            style: theme.textTheme.bodyLarge),
                        Slider(
                          value: scouting.defenseRating.toDouble(),
                          min: 0,
                          max: 5,
                          divisions: 5,
                          label: '${scouting.defenseRating}',
                          onChanged: (v) => scouting.updateField(
                              () => scouting.defenseRating = v.round()),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Match Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onChanged: (v) =>
                      scouting.updateField(() => scouting.matchNotes = v),
                ),
                const SizedBox(height: 16),

                // Submit
                FilledButton.icon(
                  onPressed: scouting.submitting
                      ? null
                      : () async {
                          final result = await scouting.submit(
                            scouterName: appState.settings.scouterName,
                            secretTeamKey:
                                appState.settings.secretTeamKey,
                            eventKey:
                                appState.settings.selectedEventKey ?? '',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result.message),
                                backgroundColor: result.success
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            );
                            if (result.success) {
                              scouting.resetForm();
                            }
                          }
                        },
                  icon: scouting.submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: const Text('Submit'),
                ),
                const SizedBox(height: 32),
              ],
            ],
          ),
          // Confetti overlay
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 15,
              maxBlastForce: 20,
              minBlastForce: 5,
              gravity: 0.3,
              colors: const [
                Colors.blue,
                Colors.green,
                Colors.orange,
                Colors.red,
                Colors.purple,
                Colors.yellow,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
