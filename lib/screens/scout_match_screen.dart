import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tba_match.dart';
import '../providers/app_state_provider.dart';
import '../providers/scouting_provider.dart';
import '../theme.dart';
import '../widgets/counter_button.dart';
import '../widgets/nav_drawer.dart';

class ScoutMatchScreen extends StatefulWidget {
  const ScoutMatchScreen({super.key});

  @override
  State<ScoutMatchScreen> createState() => _ScoutMatchScreenState();
}

class _ScoutMatchScreenState extends State<ScoutMatchScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late TabController _tabController;
  final TextEditingController _matchController =
      TextEditingController(text: '1');
  final TextEditingController _notesController = TextEditingController();
  TbaMatch? _selectedMatch;
  int? _selectedRobotIndex; // 0-2 red, 3-5 blue

  static const _tabColors = [
    AppTheme.autoColor,
    AppTheme.teleopColor,
    AppTheme.endgameColor,
  ];

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 400));
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _matchController.dispose();
    _notesController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _fireConfetti() {
    final settings = context.read<AppStateProvider>().settings;
    if (!settings.confettiEnabled) return;
    _confettiController.stop();
    _confettiController.play();
  }

  TbaMatch? _findMatch(List<TbaMatch> matches, int matchNumber) {
    final results = matches.where(
        (m) => m.matchNumber == matchNumber && m.compLevel == 'qm');
    return results.isNotEmpty ? results.first : null;
  }

  String _robotLabel(int index, TbaMatch match, List teams) {
    final isRed = index < 3;
    final alliancePos = isRed ? index : index - 3;
    final teamList = isRed ? match.redTeams : match.blueTeams;
    if (alliancePos >= teamList.length) return '???';
    final teamNum = teamList[alliancePos];
    final teamData = teams.where((t) => t.teamNumber.toString() == teamNum);
    final name = teamData.isNotEmpty ? teamData.first.nickname : '';
    final alliance =
        isRed ? 'Red ${alliancePos + 1}' : 'Blue ${alliancePos + 1}';
    return '$alliance — $teamNum${name.isNotEmpty ? ' $name' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final scouting = context.watch<ScoutingProvider>();
    final theme = Theme.of(context);
    final matches = appState.matches;
    final hasMatches = matches.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Scout Match')),
      drawer: const NavDrawer(selectedIndex: 0),
      body: Stack(
        children: [
          if (!scouting.scoutingActive)
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // State 1: No matches available
                if (!hasMatches && !scouting.practiceMode) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.schedule,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'Match Schedule Not Available',
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          _buildEventCountdown(appState, theme),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: appState.loading
                                ? null
                                : () => appState.loadMatches(),
                            icon: appState.loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.download),
                            label: const Text('Load Match Schedule'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'The match list for this event hasn\'t been published yet. '
                            'You can try practice scouting to get familiar with the form.',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () {
                              scouting.updateField(() {
                                scouting.practiceMode = true;
                                scouting.scoutingActive = true;
                              });
                            },
                            icon: const Icon(Icons.science),
                            label: const Text('Practice Scouting'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // State 2: Normal mode (matches loaded)
                if (hasMatches) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Match Setup',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 12),
                          // Match number input
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
                                  controller: _matchController,
                                  onChanged: (v) {
                                    final n = int.tryParse(v);
                                    if (n != null) {
                                      scouting.updateField(
                                          () => scouting.matchNumber = n);
                                      setState(() {
                                        _selectedMatch =
                                            _findMatch(matches, n);
                                        _selectedRobotIndex = null;
                                        scouting.selectedTeamNumber = null;
                                      });
                                    } else {
                                      setState(() {
                                        _selectedMatch = null;
                                        _selectedRobotIndex = null;
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (_selectedMatch != null)
                                Text(_selectedMatch!.displayName,
                                    style: theme.textTheme.titleSmall),
                              if (_selectedMatch == null &&
                                  _matchController.text.isNotEmpty)
                                Text('No match found',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: Colors.grey)),
                            ],
                          ),
                          // 6-robot selector
                          if (_selectedMatch != null) ...[
                            const SizedBox(height: 16),
                            Text('Select Robot',
                                style: theme.textTheme.titleSmall),
                            const SizedBox(height: 8),
                            _buildRobotSelector(
                                _selectedMatch!, appState, scouting),
                          ],
                          const SizedBox(height: 12),
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
                ],
              ],
            )
          else
            Column(
              children: [
                // Header
                if (scouting.practiceMode)
                  Card(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.science, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Practice Mode — data will not be submitted',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Colors.orange.shade900),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _notesController.clear();
                              scouting.resetForm();
                            },
                            child: const Text('Exit'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.sports_score,
                            size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Match ${scouting.matchNumber} • Team ${scouting.selectedTeamNumber ?? "???"}',
                          style: theme.textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                // TabBar
                TabBar(
                  controller: _tabController,
                  indicatorColor: _tabColors[_tabController.index],
                  tabs: List.generate(
                    3,
                    (i) => Tab(
                      child: Text(
                        const ['Auto', 'Teleop', 'Endgame'][i],
                        style: TextStyle(
                          color: _tabColors[i],
                          fontWeight: _tabController.index == i
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _KeepAliveTab(
                          child: _buildAutoTab(scouting, appState, theme)),
                      _KeepAliveTab(
                          child: _buildTeleopTab(scouting, appState, theme)),
                      _KeepAliveTab(
                          child: _buildEndgameTab(scouting, appState, theme)),
                    ],
                  ),
                ),
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

  Widget _buildEventCountdown(AppStateProvider appState, ThemeData theme) {
    final eventKey = appState.settings.selectedEventKey;
    if (eventKey == null) return const SizedBox.shrink();

    final matchingEvents =
        appState.events.where((e) => e.key == eventKey);
    if (matchingEvents.isEmpty) return const SizedBox.shrink();

    final event = matchingEvents.first;
    if (event.startDate == null) return const SizedBox.shrink();

    final start = DateTime.tryParse(event.startDate!);
    if (start == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(start.year, start.month, start.day);

    String? message;

    if (startDay.isAfter(today)) {
      final days = startDay.difference(today).inDays;
      if (days == 1) {
        message = 'Event starts tomorrow';
      } else {
        message = 'Event starts in $days days';
      }
    } else {
      // Start date is today or in the past — check end date
      final end = event.endDate != null
          ? DateTime.tryParse(event.endDate!)
          : null;
      final endDay = end != null
          ? DateTime(end.year, end.month, end.day)
          : null;

      if (startDay == today) {
        message = 'Event starts today';
      } else if (endDay != null && !today.isAfter(endDay)) {
        message = 'Event is underway — schedule may be available soon';
      }
    }

    if (message == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildRobotSelector(
      TbaMatch match, AppStateProvider appState, ScoutingProvider scouting) {
    void selectRobot(int index) {
      final isRed = index < 3;
      final pos = isRed ? index : index - 3;
      final teamList = isRed ? match.redTeams : match.blueTeams;
      if (pos < teamList.length) {
        final teamNum = int.tryParse(teamList[pos]);
        setState(() => _selectedRobotIndex = index);
        scouting.updateField(() => scouting.selectedTeamNumber = teamNum);
      }
    }

    Widget robotTile(int index, Color color) {
      final label = _robotLabel(index, match, appState.teams);
      final selected = _selectedRobotIndex == index;
      return ListTile(
        dense: true,
        leading: Icon(
          selected
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          color: selected ? color : null,
        ),
        title: Text(label, style: TextStyle(color: color)),
        onTap: () => selectRobot(index),
      );
    }

    return Column(
      children: [
        ...List.generate(3, (i) => robotTile(i, Colors.red)),
        const Divider(height: 4),
        ...List.generate(3, (i) => robotTile(i + 3, Colors.blue)),
      ],
    );
  }

  Widget _buildAutoTab(
      ScoutingProvider scouting, AppStateProvider appState, ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
                  onChanged: (v) =>
                      scouting.updateField(() => scouting.autoLeave = v),
                ),
                CounterButton(
                  label: 'Fuel Scored',
                  value: scouting.autoFuelScored,
                  showBulkButtons: true,
                  onTap: _fireConfetti,
                  enableHaptic: appState.settings.hapticEnabled,
                  onChanged: (v) => scouting
                      .updateField(() => scouting.autoFuelScored = v),
                ),
                const SizedBox(height: 8),
                CounterButton(
                  label: 'Fuel Missed',
                  value: scouting.autoFuelMissed,
                  showBulkButtons: true,
                  onTap: _fireConfetti,
                  enableHaptic: appState.settings.hapticEnabled,
                  onChanged: (v) => scouting
                      .updateField(() => scouting.autoFuelMissed = v),
                ),
                SwitchListTile(
                  title: const Text('Tower L1 (15 pts)'),
                  value: scouting.autoTowerLevel1,
                  onChanged: (v) => scouting
                      .updateField(() => scouting.autoTowerLevel1 = v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeleopTab(
      ScoutingProvider scouting, AppStateProvider appState, ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: AppTheme.teleopColor.withValues(alpha: 0.5)),
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
                  enableHaptic: appState.settings.hapticEnabled,
                  onChanged: (v) => scouting
                      .updateField(() => scouting.teleopFuelScored = v),
                ),
                const SizedBox(height: 8),
                CounterButton(
                  label: 'Fuel Missed',
                  value: scouting.teleopFuelMissed,
                  showBulkButtons: true,
                  onTap: _fireConfetti,
                  enableHaptic: appState.settings.hapticEnabled,
                  onChanged: (v) => scouting
                      .updateField(() => scouting.teleopFuelMissed = v),
                ),
                SwitchListTile(
                  title: const Text('Crossed Bump'),
                  value: scouting.teleopCrossedBump,
                  onChanged: (v) => scouting
                      .updateField(() => scouting.teleopCrossedBump = v),
                ),
                SwitchListTile(
                  title: const Text('Entered Trench'),
                  value: scouting.teleopEnteredTrench,
                  onChanged: (v) => scouting
                      .updateField(() => scouting.teleopEnteredTrench = v),
                ),
                SwitchListTile(
                  title: const Text('Ground Pickup'),
                  value: scouting.fuelGroundPickup,
                  onChanged: (v) => scouting
                      .updateField(() => scouting.fuelGroundPickup = v),
                ),
                SwitchListTile(
                  title: const Text('Human Player Pickup'),
                  value: scouting.fuelHumanPickup,
                  onChanged: (v) => scouting
                      .updateField(() => scouting.fuelHumanPickup = v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEndgameTab(
      ScoutingProvider scouting, AppStateProvider appState, ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Endgame Section
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: AppTheme.endgameColor.withValues(alpha: 0.5)),
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
                  expandedInsets: EdgeInsets.zero,
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

        // Defense
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('Defense Rating: ${scouting.defenseRating}',
                    style: theme.textTheme.bodyLarge),
                Slider(
                  value: scouting.defenseRating.toDouble(),
                  min: 0,
                  max: 5,
                  divisions: 5,
                  label: '${scouting.defenseRating}',
                  onChanged: (v) => scouting
                      .updateField(() => scouting.defenseRating = v.round()),
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
            labelText: 'Match Notes',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: (v) =>
              scouting.updateField(() => scouting.matchNotes = v),
        ),
        const SizedBox(height: 16),

        // Submit / Reset
        if (scouting.practiceMode)
          FilledButton.icon(
            onPressed: () {
              _notesController.clear();
              scouting.resetForm();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
          )
        else
          FilledButton.icon(
            onPressed: scouting.submitting
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Submit Match Data?'),
                        content: Text(
                          'Match ${scouting.matchNumber}\n'
                          'Team ${scouting.selectedTeamNumber}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Submit'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;

                    final result = await scouting.submit(
                      scouterName: appState.settings.scouterName,
                      secretTeamKey: appState.settings.secretTeamKey,
                      eventKey:
                          appState.settings.selectedEventKey ?? '',
                    );
                    if (!mounted) return;
                    context.read<AppStateProvider>().refreshHeldDataCount();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.message),
                        backgroundColor:
                            result.success ? Colors.green : Colors.red,
                      ),
                    );
                    if (result.success) {
                      scouting.resetForm();
                      _resetMatchSelection();
                    }
                  },
            icon: scouting.submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: const Text('Submit'),
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  void _resetMatchSelection() {
    final scouting = context.read<ScoutingProvider>();
    final appState = context.read<AppStateProvider>();
    _matchController.text = '${scouting.matchNumber}';
    _notesController.clear();
    final newMatch = _findMatch(appState.matches, scouting.matchNumber);

    setState(() {
      _selectedMatch = newMatch;
    });

    if (_selectedRobotIndex != null && newMatch != null) {
      final isRed = _selectedRobotIndex! < 3;
      final pos = isRed ? _selectedRobotIndex! : _selectedRobotIndex! - 3;
      final teamList = isRed ? newMatch.redTeams : newMatch.blueTeams;
      if (pos < teamList.length) {
        final teamNum = int.tryParse(teamList[pos]);
        scouting.updateField(() {
          scouting.selectedTeamNumber = teamNum;
          scouting.scoutingActive = true;
        });
      } else {
        setState(() => _selectedRobotIndex = null);
      }
    } else {
      setState(() => _selectedRobotIndex = null);
    }

    _tabController.animateTo(0);
  }
}

class _KeepAliveTab extends StatefulWidget {
  final Widget child;
  const _KeepAliveTab({required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
