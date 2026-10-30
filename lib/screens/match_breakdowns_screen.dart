import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../build_info.dart';
import '../providers/app_state_provider.dart';
import '../providers/event_data_provider.dart';
import '../widgets/match_card.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/team_selector.dart';

/// `/match-breakdowns`: every match with the official result next to our
/// scouting of all six teams. Filter by team and by quals / playoffs.
class MatchBreakdownsScreen extends StatefulWidget {
  const MatchBreakdownsScreen({super.key});

  @override
  State<MatchBreakdownsScreen> createState() => _MatchBreakdownsScreenState();
}

class _MatchBreakdownsScreenState extends State<MatchBreakdownsScreen> {
  int? _team;
  bool _quals = true;
  bool _playoffs = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.ensureEventData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final data = context.watch<EventDataProvider>();
    final theme = Theme.of(context);

    final matches = [
      for (final m in data.matches)
        if ((m.isQual ? _quals : _playoffs) && (_team == null || m.hasTeam(_team!))) m
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(appState.settings.selectedEventName ?? 'Configure Event to Continue...'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              'Updated $buildTimestamp',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
      drawer: const NavDrawer(selectedIndex: 12),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TeamSelector(
                  teams: appState.teams,
                  selectedTeamNumber: _team,
                  onChanged: (v) => setState(() => _team = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Quals'),
                      selected: _quals,
                      onSelected: (v) => setState(() => _quals = v),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Playoffs'),
                      selected: _playoffs,
                      onSelected: (v) => setState(() => _playoffs = v),
                    ),
                    const Spacer(),
                    if (data.loading)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else
                      IconButton(
                        tooltip: 'Refresh data',
                        icon: const Icon(Icons.refresh),
                        onPressed: data.refresh,
                      ),
                  ],
                ),
              ),
              if (data.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(data.error!, style: TextStyle(color: theme.colorScheme.error)),
                ),
              Expanded(
                child: matches.isEmpty
                    ? Center(
                        child: Text(data.matches.isEmpty
                            ? (data.loading ? 'Loading matches...' : 'No matches loaded')
                            : 'No matches for these filters'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: matches.length,
                        itemBuilder: (context, i) => MatchCard(
                          key: ValueKey(matches[i].key),
                          match: matches[i],
                          focusTeam: _team,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
