import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../build_info.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/team_details.dart';
import '../widgets/team_selector.dart';

/// `/team-details`. Pass an int team number as the route argument to open on
/// a team (see [openTeamDetails]); otherwise pick one.
class TeamDetailsScreen extends StatefulWidget {
  const TeamDetailsScreen({super.key});

  @override
  State<TeamDetailsScreen> createState() => _TeamDetailsScreenState();
}

class _TeamDetailsScreenState extends State<TeamDetailsScreen> {
  int? _team;
  bool _argRead = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argRead) {
      _argRead = true;
      final arg = ModalRoute.of(context)?.settings.arguments;
      if (arg is int) _team = arg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        // Opened from another screen: let the user go back to it.
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
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
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: TeamSelector(
                    teams: appState.teams,
                    selectedTeamNumber: _team,
                    onChanged: (v) => setState(() => _team = v),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: _team != null
                    ? TeamDetailView(key: ValueKey(_team), teamNumber: _team!)
                    : SliverToBoxAdapter(
                        child: appState.teams.isNotEmpty
                            ? const Text('Pick a team to see its pit data, scouting and matches.')
                            : const SizedBox.shrink(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
