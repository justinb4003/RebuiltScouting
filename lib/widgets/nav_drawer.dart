import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';

class NavDrawer extends StatelessWidget {
  final int selectedIndex;

  const NavDrawer({super.key, required this.selectedIndex});

  static const _routes = ['/scout', '/pit', '/robot-note', '/held', '/settings', '/scouting-status', '/pit-status', '/match-breakdowns', '/rankings', '/team-details', '/head-to-head', '/pick-list', '/clusters', '/dimensions'];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final heldCount = appState.heldDataCount;

    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        Navigator.pop(context); // Close drawer
        Navigator.pushReplacementNamed(context, _routes[index]);
      },
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 16, 16, 10),
          child: Text(
            'FRC Scouting',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(indent: 28, endIndent: 28),
        const NavigationDrawerDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment),
          label: Text('Scout Match'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.build_outlined),
          selectedIcon: Icon(Icons.build),
          label: Text('Scout Pit'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.sticky_note_2_outlined),
          selectedIcon: Icon(Icons.sticky_note_2),
          label: Text('Robot Note'),
        ),
        NavigationDrawerDestination(
          icon: Badge(
            isLabelVisible: heldCount > 0,
            label: Text('$heldCount'),
            child: const Icon(Icons.cloud_off_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible: heldCount > 0,
            label: Text('$heldCount'),
            child: const Icon(Icons.cloud_off),
          ),
          label: const Text('Held Data'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
        const Divider(indent: 28, endIndent: 28),
        const _SectionLabel('Management'),
        const NavigationDrawerDestination(
          icon: Icon(Icons.grid_on_outlined),
          selectedIcon: Icon(Icons.grid_on),
          label: Text('Scouting Status'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon: Icon(Icons.fact_check),
          label: Text('Pit Status'),
        ),
        const Divider(indent: 28, endIndent: 28),
        const _SectionLabel('Analytics'),
        const NavigationDrawerDestination(
          icon: Icon(Icons.sports_esports_outlined),
          selectedIcon: Icon(Icons.sports_esports),
          label: Text('Match Breakdowns'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.leaderboard_outlined),
          selectedIcon: Icon(Icons.leaderboard),
          label: Text('Rankings'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.badge_outlined),
          selectedIcon: Icon(Icons.badge),
          label: Text('Team Details'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.compare_arrows_outlined),
          selectedIcon: Icon(Icons.compare_arrows),
          label: Text('Head to Head'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.how_to_vote_outlined),
          selectedIcon: Icon(Icons.how_to_vote),
          label: Text('Pick List'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.bubble_chart_outlined),
          selectedIcon: Icon(Icons.bubble_chart),
          label: Text('Clusters'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.tune_outlined),
          selectedIcon: Icon(Icons.tune),
          label: Text('Dimensions'),
        ),
        const Divider(indent: 28, endIndent: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: TextButton.icon(
            onPressed: () async {
              final appState = context.read<AppStateProvider>();
              await appState.refreshHeldDataCount();
              if (!context.mounted) return;
              final unsent = appState.heldDataCount;
              final unsentText = unsent == 0
                  ? 'There is no unsent scouting data.'
                  : '$unsent unsent scouting ${unsent == 1 ? 'item' : 'items'} '
                      'will be lost.';
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset App?'),
                  content: Text(
                    'This will clear all local data including settings and '
                    'cached teams/matches. '
                    '$unsentText '
                    'This cannot be undone.',
                  ),
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
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await context.read<AppStateProvider>().resetToDefaults();
                if (context.mounted) {
                  Navigator.pop(context); // Close drawer
                  Navigator.pushReplacementNamed(context, '/settings');
                }
              }
            },
            icon: Icon(Icons.restart_alt,
                color: Theme.of(context).colorScheme.error),
            label: Text('Reset App',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ),
      ],
    );
  }
}

/// A heading for a group of drawer destinations.
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 16, 8),
      child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}
