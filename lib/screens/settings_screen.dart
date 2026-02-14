import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../providers/app_state_provider.dart';
import '../widgets/nav_drawer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _keyController;
  late TextEditingController _eventCodeController;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppStateProvider>().settings;
    _nameController = TextEditingController(text: settings.scouterName);
    _keyController = TextEditingController(text: settings.secretTeamKey);
    _eventCodeController =
        TextEditingController(text: settings.selectedEventKey ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
    _eventCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final settings = appState.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      drawer: const NavDrawer(selectedIndex: 3),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Scouter Name
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Scouter Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),

          // Secret Team Key
          TextField(
            controller: _keyController,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: 'Secret Team Key',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.key),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureKey ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Event Year
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Event Selection',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownMenu<int>(
                          label: const Text('Year'),
                          initialSelection: settings.eventYear,
                          onSelected: (year) {
                            if (year != null) {
                              settings.eventYear = year;
                            }
                          },
                          dropdownMenuEntries: List.generate(
                            5,
                            (i) {
                              final y = 2026 - i;
                              return DropdownMenuEntry(
                                  value: y, label: '$y');
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: appState.loading
                            ? null
                            : () => appState.loadEvents(settings.eventYear),
                        icon: const Icon(Icons.download),
                        label: const Text('Load Events'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Event code text field
                  TextField(
                    controller: _eventCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Event Code',
                      hintText: 'e.g. 2026miwmi',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.code),
                    ),
                    onChanged: (v) {
                      settings.selectedEventKey = v.trim().isNotEmpty ? v.trim() : null;
                      settings.selectedEventName = null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Event dropdown (updates the text field)
                  if (appState.events.isNotEmpty)
                    DropdownMenu<String>(
                      label: const Text('Select from list'),
                      expandedInsets: EdgeInsets.zero,
                      enableFilter: true,
                      enableSearch: true,
                      initialSelection: settings.selectedEventKey,
                      onSelected: (key) {
                        if (key != null) {
                          final event = appState.events
                              .firstWhere((e) => e.key == key);
                          settings.selectedEventKey = key;
                          settings.selectedEventName = event.name;
                          _eventCodeController.text = key;
                        }
                      },
                      dropdownMenuEntries: appState.events
                          .map((e) => DropdownMenuEntry(
                                value: e.key,
                                label: e.name,
                              ))
                          .toList(),
                    ),

                  const SizedBox(height: 12),

                  // Load Teams button
                  if (_eventCodeController.text.isNotEmpty)
                    FilledButton.icon(
                      onPressed: appState.loading
                          ? null
                          : () => appState.loadTeams(),
                      icon: const Icon(Icons.groups),
                      label: Text(appState.teams.isEmpty
                          ? 'Load Teams'
                          : 'Reload Teams (${appState.teams.length} loaded)'),
                    ),
                ],
              ),
            ),
          ),

          if (appState.loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),

          if (appState.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                appState.error!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error),
              ),
            ),

          const SizedBox(height: 24),

          // Save button
          FilledButton.icon(
            onPressed: () async {
              settings.scouterName = _nameController.text.trim();
              settings.secretTeamKey = _keyController.text.trim();
              await appState.updateSettings(settings);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings saved!')),
                );
              }
            },
            icon: const Icon(Icons.save),
            label: const Text('Save Settings'),
          ),
        ],
      ),
    );
  }
}
