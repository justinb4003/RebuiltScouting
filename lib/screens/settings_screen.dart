import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tba_event.dart';
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
  final FocusNode _eventFocusNode = FocusNode();
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
    _eventFocusNode.dispose();
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

                  // Event search with autocomplete
                  RawAutocomplete<TbaEvent>(
                    textEditingController: _eventCodeController,
                    focusNode: _eventFocusNode,
                    optionsBuilder: (textEditingValue) {
                      final query =
                          textEditingValue.text.trim().toLowerCase();
                      if (query.isEmpty) return appState.events;
                      return appState.events.where((e) =>
                          e.name.toLowerCase().contains(query) ||
                          e.key.toLowerCase().contains(query) ||
                          (e.city?.toLowerCase().contains(query) ??
                              false));
                    },
                    displayStringForOption: (e) => e.key,
                    onSelected: (event) {
                      appState.setEventKey(event.key);
                    },
                    fieldViewBuilder: (context, controller, focusNode,
                        onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Event',
                          hintText: 'Search by name, code, or city',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.event),
                          suffixIcon: controller.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    controller.clear();
                                    appState.setEventKey('');
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (v) {
                          final trimmed = v.trim();
                          // Check if typed value matches a known event
                          final match = appState.events
                              .where((e) => e.key == trimmed);
                          if (match.isNotEmpty) {
                            appState.setEventKey(trimmed);
                          } else {
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
                        onTap: () {
                          if (controller.text.isNotEmpty) {
                            controller.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: controller.text.length,
                            );
                          }
                        },
                      );
                    },
                    optionsViewBuilder:
                        (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxHeight: 240),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final event =
                                    options.elementAt(index);
                                return ListTile(
                                  dense: true,
                                  title: Text(event.name),
                                  subtitle: Text(event.key),
                                  onTap: () => onSelected(event),
                                );
                              },
                            ),
                          ),
                        ),
                      );
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
                              color:
                                  Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Load Teams button
                  if (settings.selectedEventKey != null &&
                      settings.selectedEventKey!.isNotEmpty)
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
        ],
      ),
    );
  }
}
