import 'dart:async';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../models/tba_event.dart';
import '../widgets/fixed_segmented_button.dart';
import '../providers/app_state_provider.dart';
import '../theme.dart';
import '../widgets/nav_drawer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _keyController;
  late TextEditingController _eventSearchController;
  final FocusNode _eventSearchFocusNode = FocusNode();
  late ConfettiController _confettiController;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 400));
    final appState = context.read<AppStateProvider>();
    final settings = appState.settings;
    _nameController = TextEditingController(text: settings.scouterName);
    _keyController = TextEditingController(text: settings.secretTeamKey);
    _eventSearchController = TextEditingController(
      text: settings.selectedEventName ?? '',
    );

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
    appState.persistTextFields();
    _nameController.dispose();
    _keyController.dispose();
    _eventSearchController.dispose();
    _eventSearchFocusNode.dispose();
    _confettiController.dispose();
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
      appBar: AppBar(title: Text(settings.selectedEventName ?? 'Configure Event to Continue...')),
      drawer: const NavDrawer(selectedIndex: 3),
      body: Stack(
        children: [
          ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Dyslexia-friendly font toggle
          SwitchListTile(
            title: const Text('Dyslexia-friendly font'),
            subtitle: const Text('Use OpenDyslexic across the app'),
            secondary: const Icon(Icons.font_download),
            value: settings.useOpenDyslexic,
            onChanged: (value) {
              settings.useOpenDyslexic = value;
              appState.saveAndNotify();
            },
          ),
          const SizedBox(height: 16),

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
            decoration: const InputDecoration(
              labelText: 'Secret Team Key',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.key),
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
                              // Clear event selection when year changes
                              _eventSearchController.clear();
                              appState.setEventKey('');
                            }
                          },
                          dropdownMenuEntries: List.generate(
                            5,
                            (i) {
                              final y = DateTime.now().year - i;
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
                        label: const Text('Force Events Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Event search autocomplete
                  _buildEventAutocomplete(appState, settings),

                  if (settings.selectedEventKey != null &&
                      settings.selectedEventKey!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 12),
                      child: Text(
                        settings.selectedEventKey!,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
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
                          : 'Force Reload Teams (${appState.teams.length} loaded)'),
                    ),
                ],
              ),
            ),
          ),

          // Team list card
          if (appState.teams.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Teams (${appState.teams.length})',
                          style:
                              Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: (List.of(appState.teams)
                              ..sort((a, b) =>
                                  a.teamNumber.compareTo(b.teamNumber)))
                            .map((team) => Tooltip(
                                  message: team.nickname,
                                  child: Chip(
                                    label: Text('${team.teamNumber}'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
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

          // Theme mode toggle
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Appearance',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  FixedSegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'light',
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: 'system',
                        label: Text('System'),
                        icon: Icon(Icons.settings_brightness),
                      ),
                      ButtonSegment(
                        value: 'dark',
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (selected) {
                      settings.themeMode = selected.first;
                      appState.saveAndNotify();
                    },
                  ),
                ],
              ),
            ),
          ),

          // Theme color picker
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme Color',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppTheme.themeColors.entries.map((entry) {
                      final isSelected =
                          settings.themeColor == entry.value.toARGB32();
                      return GestureDetector(
                        onTap: () {
                          settings.themeColor = entry.value.toARGB32();
                          appState.saveAndNotify();
                        },
                        child: Tooltip(
                          message: entry.key,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: entry.value,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      width: 3,
                                    )
                                  : null,
                            ),
                            child: isSelected
                                ? Icon(Icons.check,
                                    color: ThemeData.estimateBrightnessForColor(
                                                entry.value) ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black,
                                    size: 20)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // Confetti & haptic toggles
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Confetti'),
            subtitle: const Text('Celebrate when scouting'),
            secondary: const Icon(Icons.celebration),
            value: settings.confettiEnabled,
            onChanged: (value) {
              settings.confettiEnabled = value;
              appState.saveAndNotify();
              if (value) {
                _confettiController.stop();
                _confettiController.play();
              }
            },
          ),
          SwitchListTile(
            title: const Text('Haptic feedback'),
            subtitle: const Text('Vibrate on counter taps'),
            secondary: const Icon(Icons.vibration),
            value: settings.hapticEnabled,
            onChanged: (value) {
              settings.hapticEnabled = value;
              appState.saveAndNotify();
            },
          ),
        ],
      ),
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

  Widget _buildEventAutocomplete(AppStateProvider appState, AppSettings settings) {
    final yearEvents = appState.events
        .where((e) => e.key.startsWith(settings.eventYear.toString()))
        .toList();

    return RawAutocomplete<TbaEvent>(
      textEditingController: _eventSearchController,
      focusNode: _eventSearchFocusNode,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return yearEvents;
        return yearEvents.where((e) =>
            e.name.toLowerCase().contains(query) ||
            e.key.toLowerCase().contains(query));
      },
      displayStringForOption: (e) => e.name,
      onSelected: (event) {
        appState.setEventKey(event.key);
        _eventSearchController.text = event.name;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Search Events',
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
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final event = options.elementAt(index);
                  final isSelected = event.key == settings.selectedEventKey;
                  return ListTile(
                    dense: true,
                    selected: isSelected,
                    title: Text(event.name),
                    subtitle: Text(
                      '${event.key}${event.city != null ? ' \u2014 ${event.city}, ${event.stateProv ?? ''}' : ''}',
                    ),
                    onTap: () => onSelected(event),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
