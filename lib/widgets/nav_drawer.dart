import 'package:flutter/material.dart';

class NavDrawer extends StatelessWidget {
  final int selectedIndex;

  const NavDrawer({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
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
      children: const [
        Padding(
          padding: EdgeInsets.fromLTRB(28, 16, 16, 10),
          child: Text(
            'FRC Scouting',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Divider(indent: 28, endIndent: 28),
        NavigationDrawerDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment),
          label: Text('Scout Match'),
        ),
        NavigationDrawerDestination(
          icon: Icon(Icons.build_outlined),
          selectedIcon: Icon(Icons.build),
          label: Text('Scout Pit'),
        ),
        NavigationDrawerDestination(
          icon: Icon(Icons.cloud_off_outlined),
          selectedIcon: Icon(Icons.cloud_off),
          label: Text('Held Data'),
        ),
        NavigationDrawerDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
      ],
    );
  }
}
