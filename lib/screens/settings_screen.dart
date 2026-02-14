import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppStateProvider>();
    final settings = appState.settings;
    _nameController = TextEditingController(text: settings.scouterName);
    _keyController = TextEditingController(text: settings.secretTeamKey);
    _eventCodeController =
        TextEditingController(text: settings.selectedEventKey ?? '');

    // Load events from cache or API when settings screen opens
    if (appState.events.isEmpty) {
      appState.loadEvents(settings.eventYear);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Final save of all text fields on dispose
    final appState = context.read<AppStateProvider>();
    appState.updateScouterName(_nameController.text.trim());
    appState.updateSecretKey(_keyController.text.trim());
    final eventCode = _eventCodeController.text.trim();
    appState.settings.selectedEventKey =
        eventCode.isNotEmpty ? eventCode : null;
    appState.persistTextFields();
    _nameController.dispose();
    _keyController.dispose();
    _eventCodeController.dispose();
    super.dispose();
  }

  void _debouncedSaveTextFields() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      final appState = context.read<AppStateProvider>();
      appState.updateScouterName(_nameController.text.trim());
      appState.updateSecretKey(_keyController.text.trim());
      appState.persistTextFields();
    });
  }

  void _onDropdownSelected(String? key) {
    if (key != null) {
      _eventCodeController.text = key;
      context.read<AppStateProvider>().setEventKey(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final settings = appState.settings;

    // Determine if event code matches an event in the list for dropdown display
    final matchingEventKey =
        appState.events.any((e) => e.key == settings.selectedEventKey)
            ? settings.selectedEventKey
            : null;

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
            onChanged: (_) => _debouncedSaveTextFields(),
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
            onChanged: (_) => _debouncedSaveTextFields(),
          ),
          const SizedBox(height: 24),

          // Event Selection
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
                              appState.setEventYear(year);
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
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
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
                      final trimmed = v.trim();
                      final match =
                          appState.events.where((e) => e.key == trimmed);
                      if (match.isNotEmpty) {
                        appState.setEventKey(trimmed);
                      } else {
                        // Update in-memory and schedule a save
                        settings.selectedEventKey =
                            trimmed.isNotEmpty ? trimmed : null;
                        settings.selectedEventName = null;
                        _debouncedSaveTextFields();
                      }
                      setState(() {});
                    },
                    onSubmitted: (v) {
                      final trimmed = v.trim();
                      if (trimmed.isNotEmpty) {
                        appState.setEventKey(trimmed);
                      }
                    },
                  ),
                  if (settings.selectedEventName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 12),
                      child: Text(
                        settings.selectedEventName!,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Event dropdown (updates the text field)
                  if (appState.events.isNotEmpty)
                    DropdownMenu<String>(
                      key: ValueKey('dropdown_$matchingEventKey'),
                      label: const Text('Select from list'),
                      expandedInsets: EdgeInsets.zero,
                      enableFilter: true,
                      enableSearch: true,
                      initialSelection: matchingEventKey,
                      onSelected: _onDropdownSelected,
                      dropdownMenuEntries: appState.events
                          .map((e) => DropdownMenuEntry(
                                value: e.key,
                                label: e.name,
                              ))
                          .toList(),
                    ),

                  const SizedBox(height: 12),

                  // Load Teams button
                  if (settings.selectedEventKey != null &&
                      settings.selectedEventKey!.isNotEmpty)
                    FilledButton.icon(
                      onPressed: appState.loading || matchingEventKey == null
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
        ],
      ),
    );
  }
}
