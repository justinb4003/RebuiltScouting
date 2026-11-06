import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../providers/app_state_provider.dart';
import '../build_info.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/slack_link_dialog.dart';
import '../widgets/event_picker_dialog.dart';
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
    _teamController =
        TextEditingController(text: settings.teamNumber?.toString() ?? '');

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

  int? get _enteredTeam => int.tryParse(_teamController.text.trim());

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
                      prefixIcon: Icon(Icons.person),
                    ),
                    onChanged: (_) => _debouncedSaveTextFields(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyController,
                    decoration: const InputDecoration(
                      labelText: 'Secret team key',
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
                      prefixIcon: Icon(Icons.groups),
                    ),
                    onChanged: (_) => _debouncedSaveTextFields(),
                  ),
                  const SizedBox(height: 12),
                  _buildSlackLink(settings),

                  _sectionHeader('Event'),
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

  /// The selected event; tap to choose another in the event dialog.
  Widget _buildEventPicker(AppStateProvider appState, AppSettings settings) {
    final key = settings.selectedEventKey;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.event),
        title: Text(key == null
            ? 'No event selected'
            : settings.selectedEventName ?? key),
        subtitle: Text(key ?? 'Pick an event to start scouting'),
        trailing: const Text('Change'),
        onTap: () => _chooseEvent(appState),
      ),
    );
  }

  Future<void> _chooseEvent(AppStateProvider appState) async {
    final settings = appState.settings;
    final picked = await showEventPickerDialog(
      context,
      initialYear: settings.eventYear,
      initialEvents: appState.events,
      teamNumber: _enteredTeam,
      selectedKey: settings.selectedEventKey,
    );
    if (picked == null || picked.key == settings.selectedEventKey) return;
    final year = int.tryParse(picked.key.substring(0, 4));
    if (year != null && year != settings.eventYear) {
      await appState.setEventYear(year);
    }
    await appState.setEventKey(picked.key);
  }
}
