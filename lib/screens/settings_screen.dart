import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../models/tba_event.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/fixed_segmented_button.dart';
import '../providers/app_state_provider.dart';
import '../theme.dart';
import '../build_info.dart';
import '../widgets/nav_drawer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static bool _eventsRefreshed = false;
  late TextEditingController _nameController;
  late TextEditingController _keyController;
  late TextEditingController _eventSearchController;
  final FocusNode _eventSearchFocusNode = FocusNode();
  final _confettiKey = GlobalKey<ConfettiOverlayState>();
  late AppStateProvider _appState;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _appState = context.read<AppStateProvider>();
    final appState = _appState;
    final settings = appState.settings;
    _nameController = TextEditingController(text: settings.scouterName);
    _keyController = TextEditingController(text: settings.secretTeamKey);
    _eventSearchController = TextEditingController(
      text: settings.selectedEventName ?? '',
    );

    // No cached events: load them. Otherwise refresh quietly once per app
    // session so newly added events show up.
    if (appState.events.isEmpty || !_eventsRefreshed) {
      final quiet = appState.events.isNotEmpty;
      _eventsRefreshed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appState.loadEvents(settings.eventYear, quiet: quiet);
      });
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Final save of all text fields on dispose
    _appState.updateScouterName(_nameController.text.trim());
    _appState.updateSecretKey(_keyController.text.trim());
    _appState.persistSettings();
    _nameController.dispose();
    _keyController.dispose();
    _eventSearchController.dispose();
    _eventSearchFocusNode.dispose();
    super.dispose();
  }

  void _debouncedSaveTextFields() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      final appState = context.read<AppStateProvider>();
      appState.updateScouterName(_nameController.text.trim());
      appState.updateSecretKey(_keyController.text.trim());
      appState.persistSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final settings = appState.settings;
    final theme = Theme.of(context);
    final hasEvent = settings.selectedEventKey?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      drawer: const NavDrawer(selectedIndex: 4),
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _sectionHeader('You'),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Scouter name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    onChanged: (_) => _debouncedSaveTextFields(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyController,
                    decoration: const InputDecoration(
                      labelText: 'Secret team key',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.key),
                    ),
                    onChanged: (_) => _debouncedSaveTextFields(),
                  ),

                  _sectionHeader('Event'),
                  _buildEventAutocomplete(appState, settings),
                  if (appState.loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    ),
                  if (appState.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 12),
                      child: Text(
                        appState.error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  if (hasEvent) ...[
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        leading: const Icon(Icons.groups),
                        title: Text(appState.teams.isEmpty
                            ? 'No teams loaded'
                            : '${appState.teams.length} teams'),
                        subtitle: Text(settings.selectedEventKey!),
                        shape: const Border(),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: (List.of(appState.teams)
                                  ..sort((a, b) =>
                                      a.teamNumber.compareTo(b.teamNumber)))
                                .map((team) => Chip(
                                      label: Text('${team.teamNumber}'),
                                      visualDensity: VisualDensity.compact,
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: appState.loading
                                ? null
                                : () => appState.loadTeams(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reload teams'),
                          ),
                        ],
                      ),
                    ),
                  ],

                  _sectionHeader('Scouting'),
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Scrollable scouting layout'),
                          subtitle: const Text(
                              'Show match scouting as one scrollable page'),
                          secondary: const Icon(Icons.view_day),
                          value: settings.scrollableScoutLayout,
                          onChanged: (value) {
                            settings.scrollableScoutLayout = value;
                            appState.saveAndNotify();
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
                        SwitchListTile(
                          title: const Text('Confetti'),
                          subtitle: const Text('Celebrate when scouting'),
                          secondary: const Icon(Icons.celebration),
                          value: settings.confettiEnabled,
                          onChanged: (value) {
                            settings.confettiEnabled = value;
                            appState.saveAndNotify();
                            if (value) {
                              _confettiKey.currentState?.fire();
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  _sectionHeader('Appearance'),
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: FixedSegmentedButton<String>(
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
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: _buildColorPicker(appState, settings),
                          ),
                          SwitchListTile(
                            title: const Text('Dyslexia-friendly font'),
                            subtitle:
                                const Text('Use OpenDyslexic across the app'),
                            secondary: const Icon(Icons.font_download),
                            value: settings.useOpenDyslexic,
                            onChanged: (value) {
                              settings.useOpenDyslexic = value;
                              appState.saveAndNotify();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MergeSemantics(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                      Text('Season ',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      DropdownButton<int>(
                        value: settings.eventYear,
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        style: theme.textTheme.bodySmall,
                        items: {
                          for (var i = 0; i < 5; i++) DateTime.now().year - i,
                          settings.eventYear,
                        }
                            .map((y) =>
                                DropdownMenuItem(value: y, child: Text('$y')))
                            .toList(),
                        onChanged: (year) {
                          if (year == null || year == settings.eventYear) {
                            return;
                          }
                          _eventSearchController.clear();
                          appState.setEventKey('');
                          appState.setEventYear(year);
                        },
                      ),
                          ],
                        ),
                      ),
                      Semantics(
                        container: true,
                        child: Text('  \u00b7  Updated $buildTimestamp',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ConfettiOverlay(key: _confettiKey),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildColorPicker(AppStateProvider appState, AppSettings settings) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppTheme.themeColors.entries.map((entry) {
        final isSelected = settings.themeColor == entry.value.toARGB32();
        return Semantics(
          button: true,
          label: '${entry.key} theme color${isSelected ? ', selected' : ''}',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              settings.themeColor = entry.value.toARGB32();
              appState.saveAndNotify();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: entry.value,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: onSurface, width: 3)
                    : null,
              ),
              child: isSelected
                  ? Icon(Icons.check,
                      color: ThemeData.estimateBrightnessForColor(
                                  entry.value) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black,
                      size: 18)
                  : null,
            ),
          ),
        );
      }).toList(),
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
        // No visible label (the section header says Event), but screen
        // readers still need one, also once an event fills the field.
        return Semantics(
          label: 'Event',
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              hintText: 'Search by name or code',
              helperText: settings.selectedEventKey == null
                  ? 'Pick an event to start scouting'
                  : null,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.event),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          semanticLabel: 'Clear event'),
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
          ),
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
