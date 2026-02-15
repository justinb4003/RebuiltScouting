import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';

class NavDrawer extends StatelessWidget {
  final int selectedIndex;

  const NavDrawer({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    final heldCount = context.watch<AppStateProvider>().heldDataCount;

    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        Navigator.pop(context); // Close drawer
        switch (index) {
          case 0:
            Navigator.pushReplacementNamed(context, '/scout');
            break;
          case 1:
            Navigator.pushReplacementNamed(context, '/pit');
            break;
          case 2:
            Navigator.pushReplacementNamed(context, '/held');
            break;
          case 3:
            Navigator.pushReplacementNamed(context, '/settings');
            break;
        }
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: TextButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Reset App?'),
                  content: const Text(
                    'This will clear all local data including settings, '
                    'cached teams/matches, and any unsent scouting results. '
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
