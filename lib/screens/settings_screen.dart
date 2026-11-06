import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/fixed_segmented_button.dart';
import '../providers/app_state_provider.dart';
import '../theme.dart';
import '../build_info.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/slack_link_dialog.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static bool _eventsRefreshed = false;
  late TextEditingController _nameController;
  late TextEditingController _keyController;
  late TextEditingController _teamController;
  late TextEditingController _eventSearchController;
  final _confettiKey = GlobalKey<ConfettiOverlayState>();
  late AppStateProvider _appState;
  Timer? _saveTimer;

  // Events the entered team is registered for, per 'team|year' (fetched
  // once per app session). The event list shows only these when known.
  static final Map<String, Set<String>> _teamEvents = {};
  String? _teamEventsWanted;

  @override
  void initState() {
    super.initState();
    _appState = context.read<AppStateProvider>();
    final appState = _appState;
    final settings = appState.settings;
    _nameController = TextEditingController(text: settings.scouterName);
    _keyController = TextEditingController(text: settings.secretTeamKey);
    _teamController =
        TextEditingController(text: settings.teamNumber?.toString() ?? '');
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
    _loadTeamEvents();
  }

  int? get _enteredTeam => int.tryParse(_teamController.text.trim());

  /// Fetches the entered team's events for the selected season, if not
  /// already known; the event list filters to them when they arrive.
  void _loadTeamEvents() {
    final team = _enteredTeam;
    if (team == null) return;
    final combo = '$team|${_appState.settings.eventYear}';
    if (_teamEvents.containsKey(combo) || _teamEventsWanted == combo) return;
    _teamEventsWanted = combo;
    ApiService.instance
        .getTeamEventKeys(team, _appState.settings.eventYear)
        .then((keys) {
      _teamEvents[combo] = keys;
    }).catchError((Object e) {
      debugPrint('Loading team events failed: $e');
    }).whenComplete(() {
      if (_teamEventsWanted == combo) _teamEventsWanted = null;
      if (mounted) setState(() {});
    });
  }

  /// The entered team's events this season, or null to show every event
  /// (no team, not loaded yet, failed, or the team has none this season).
  Set<String>? _teamEventFilter(int year) {
    final team = _enteredTeam;
    if (team == null) return null;
    final keys = _teamEvents['$team|$year'];
    return (keys == null || keys.isEmpty) ? null : keys;
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Final save of all text fields on dispose
    _appState.updateScouterName(_nameController.text.trim());
    _appState.updateSecretKey(_keyController.text.trim());
    _appState.updateTeamNumber(int.tryParse(_teamController.text.trim()));
    _appState.persistSettings();
    _nameController.dispose();
    _teamController.dispose();
    _keyController.dispose();
    _eventSearchController.dispose();
    super.dispose();
  }

  void _debouncedSaveTextFields() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      final appState = context.read<AppStateProvider>();
      appState.updateScouterName(_nameController.text.trim());
      appState.updateSecretKey(_keyController.text.trim());
      appState.updateTeamNumber(int.tryParse(_teamController.text.trim()));
      appState.persistSettings();
      _loadTeamEvents();
      setState(() {});
    });
  }

  // Whether each secret key + team number has Slack set up on the API,
  // checked once per app session. Missing = not checked yet.
  static final Map<String, bool> _slackAvailable = {};
  static final Set<String> _slackChecking = {};

  bool _slackReady(String key, int? team) {
    if (key.isEmpty || team == null) return false;
    final combo = '$key|$team';
    final known = _slackAvailable[combo];
    if (known != null) return known;
    if (_slackChecking.add(combo)) {
      ApiService.instance.slackLinkAvailable(key, team).then((ok) {
        _slackAvailable[combo] = ok;
      }).catchError((Object e) {
        debugPrint('Checking Slack failed: $e');
      }).whenComplete(() {
        _slackChecking.remove(combo);
        if (mounted) setState(() {});
      });
    }
    return false;
  }

  Widget _buildSlackLink(AppSettings settings) {
    if (!settings.slackLinked) {
      // Only teams with their own Slack set up see the button.
      final key = settings.secretTeamKey.trim();
      final team = settings.teamNumber;
      if (!_slackReady(key, team)) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => _linkSlack(key, team!),
          icon: const Icon(Icons.link),
          label: const Text('Link Slack account'),
        ),
      );
    }
    final slackName = settings.slackName ?? '';
    final sameName = _nameController.text.trim() == slackName;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        const Icon(Icons.link),
        Text('Slack: linked as $slackName'),
        TextButton(onPressed: _unlinkSlack, child: const Text('Unlink')),
        if (!sameName && slackName.isNotEmpty)
          TextButton(
            onPressed: () {
              setState(() => _nameController.text = slackName);
              _debouncedSaveTextFields();
            },
            child: const Text('Use Slack name'),
          ),
      ],
    );
  }

  Future<void> _linkSlack(String key, int team) async {
    final result = await showSlackLinkDialog(context, key, team);
    if (result == null || !mounted) return;
    if (_nameController.text.trim().isEmpty) {
      _nameController.text = result.slackName;
    }
    _saveTimer?.cancel();
    final appState = context.read<AppStateProvider>();
    appState.updateScouterName(_nameController.text.trim());
    await appState.setSlackLink(result);
    if (mounted) setState(() {});
  }

  Future<void> _unlinkSlack() async {
    final appState = context.read<AppStateProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final token = appState.settings.slackLinkToken;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink Slack account?'),
        content: const Text('Your secret team key and name stay as they are.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Unlink')),
        ],
      ),
    );
    if (ok != true || token == null) return;
    try {
      await ApiService.instance.slackUnlink(token);
    } catch (e) {
      debugPrint('Unlinking Slack failed: $e');
      messenger.showSnackBar(const SnackBar(
          content: Text("Couldn't unlink right now. Check your connection and try again.")));
      return;
    }
    await appState.clearSlackLink();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final settings = appState.settings;
    final theme = Theme.of(context);
    final hasEvent = settings.selectedEventKey?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      drawer: const NavDrawer(selectedIndex: 5),
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: _teamController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Your team number (optional)',
                      helperText:
                          'Filters the event list; used by the statewide games',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.groups),
                    ),
                    onChanged: (_) => _debouncedSaveTextFields(),
                  ),
                  const SizedBox(height: 12),
                  _buildSlackLink(settings),

                  _sectionHeader('Event'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<int>(
                        key: ValueKey(settings.eventYear),
                        initialValue: settings.eventYear,
                        decoration: const InputDecoration(
                          labelText: 'Season',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: {
                          for (var i = 0; i < 6; i++) currentSeason() - i,
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
                          _loadTeamEvents();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildEventPicker(appState, settings),
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
                        SwitchListTile(
                          title: const Text('Schedule test mode'),
                          subtitle: const Text('Publishing a schedule offers a practice run with the match '
                              'times moved to today, to test shift reminders'),
                          secondary: const Icon(Icons.science_outlined),
                          value: settings.scheduleTestMode,
                          onChanged: (value) {
                            settings.scheduleTestMode = value;
                            appState.saveAndNotify();
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
                      Semantics(
                        container: true,
                        child: Text('Updated $buildTimestamp',
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

  /// The event picker: a standard dropdown you can also type in to filter
  /// (by name, code or city).
  Widget _buildEventPicker(AppStateProvider appState, AppSettings settings) {
    final only = _teamEventFilter(settings.eventYear);
    final yearEvents = appState.events
        .where((e) => e.key.startsWith(settings.eventYear.toString()))
        .where((e) => only == null || only.contains(e.key))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final selected = settings.selectedEventKey;

    return DropdownMenu<String>(
      // Start fresh when the season changes.
      key: ValueKey(settings.eventYear),
      controller: _eventSearchController,
      initialSelection:
          yearEvents.any((e) => e.key == selected) ? selected : null,
      expandedInsets: EdgeInsets.zero,
      menuHeight: 320,
      requestFocusOnTap: true,
      enableFilter: true,
      label: const Text('Event'),
      hintText: 'Pick or type to search',
      helperText: selected == null
          ? 'Pick an event to start scouting'
          : only != null
              ? "Team $_enteredTeam's events"
              : null,
      leadingIcon: const Icon(Icons.event),
      filterCallback: (entries, filter) {
        final q = filter.trim().toLowerCase();
        if (q.isEmpty) return entries;
        return entries.where((entry) {
          final e = yearEvents.firstWhere((e) => e.key == entry.value);
          return e.name.toLowerCase().contains(q) ||
              e.key.toLowerCase().contains(q) ||
              (e.city ?? '').toLowerCase().contains(q);
        }).toList();
      },
      onSelected: (key) {
        if (key != null && key != selected) appState.setEventKey(key);
      },
      dropdownMenuEntries: [
        for (final e in yearEvents)
          DropdownMenuEntry(
            value: e.key,
            label: e.name,
            labelWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.name),
                Text(
                  '${e.key}${e.city != null ? ' \u2014 ${e.city}, ${e.stateProv ?? ''}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
