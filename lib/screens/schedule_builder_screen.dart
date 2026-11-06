import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/scout_schedule.dart';
import '../providers/app_state_provider.dart';
import '../providers/schedule_provider.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/schedule_grid.dart';

/// Lead's screen: pick who's scouting, put them in groups of up to six, let
/// the groups take turns in blocks of matches, adjust, and publish.
class ScheduleBuilderScreen extends StatefulWidget {
  const ScheduleBuilderScreen({super.key});

  @override
  State<ScheduleBuilderScreen> createState() => _ScheduleBuilderScreenState();
}

class _ScheduleBuilderScreenState extends State<ScheduleBuilderScreen> {
  // Match times (estimated and actual) come with the match list; refresh it
  // once per session.
  static final Set<String> _matchesRefreshed = {};
  bool _publishing = false;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final app = context.read<AppStateProvider>();
      final s = app.settings;
      final schedule = context.read<ScheduleProvider>();
      final event = s.selectedEventKey ?? '';
      if (event.isNotEmpty && _matchesRefreshed.add(event)) app.loadMatches();
      await schedule.load(s.selectedEventKey ?? '', s.secretTeamKey);
      if (mounted) schedule.startDraftIfNeeded();
      if (mounted) setState(() {});
    });
  }

  int _qualCount(AppStateProvider app) => app.matches
      .where((m) => m.compLevel == 'qm')
      .fold(0, (a, m) => m.matchNumber > a ? m.matchNumber : a);

  /// Everyone who could be picked: registered scouters plus names added by
  /// hand, alphabetical.
  List<String> _everyone(ScheduleProvider schedule) {
    final seen = <String>{};
    final names = <String>[];
    for (final n in [for (final s in schedule.scouters) s.name, ...schedule.roster]) {
      if (seen.add(nameKey(n))) names.add(n);
    }
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  /// Ticked names in the same order as [_everyone].
  List<String> _picked(ScheduleProvider schedule) =>
      [for (final n in _everyone(schedule)) if (schedule.roster.contains(n)) n];

  Future<bool> _confirm(String title, String body, String ok) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _addName(ScheduleProvider schedule) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => const _NameDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    final existing = _everyone(schedule).where((n) => nameKey(n) == nameKey(name));
    schedule.setRoster({...schedule.roster, existing.isEmpty ? name.trim() : existing.first});
  }

  /// Roll a whole new schedule from the groups and everyone else.
  void _generate(ScheduleProvider schedule, List<(int, int)> ranges) {
    final before = schedule.draft;
    // Roll a few times if someone ends up over the max (block lengths
    // differ, so who gets the long ones matters).
    final picked = _picked(schedule);
    var shifts = <Shift>[];
    for (var roll = 0; roll < 40; roll++) {
      shifts = generateSchedule(picked, schedule.groups, ranges, _rng,
          maxMatches: schedule.maxMatches,
          sameCrews: schedule.options.sameCrews,
          sameStations: schedule.options.sameStations);
      if (matchesPerPerson(shifts).values.every((n) => n <= schedule.maxMatches)) break;
    }
    schedule.setDraft(shifts);
    if (before.isEmpty) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('New schedule generated'),
        action: SnackBarAction(label: 'Undo', onPressed: () => schedule.setDraft(before)),
      ));
  }

  /// Add (index == null) or edit a group of people who scout together.
  Future<void> _editGroup(ScheduleProvider schedule, int? index) async {
    final current = index == null ? <String>[] : schedule.groups[index];
    final elsewhere = {
      for (var g = 0; g < schedule.groups.length; g++)
        if (g != index) ...schedule.groups[g].map(nameKey),
    };
    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => _GroupDialog(
        title: index == null ? 'New group' : 'Group ${index + 1}',
        candidates: [for (final n in _picked(schedule)) if (!elsewhere.contains(nameKey(n))) n],
        initial: current,
      ),
    );
    if (result == null) return;
    final groups = [...schedule.groups];
    if (index == null) {
      groups.add(result);
    } else {
      groups[index] = result;
    }
    schedule.setGroups(groups);
  }

  Future<void> _editCell(ScheduleProvider schedule, ScheduleBlock block, String station) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _CellDialog(
        title: '${block.range}, ${stationLabel(station)}',
        current: block.names[station] ?? '',
        roster: _picked(schedule),
        others: [
          for (final n in _everyone(schedule))
            if (!schedule.roster.contains(n)) n,
        ],
      ),
    );
    if (result == null) return;
    schedule.setDraft(setCell(schedule.draft, station, block.firstMatch, block.lastMatch, result));
  }

  Future<void> _publish(ScheduleProvider schedule, String publisher, int problems) async {
    final app = context.read<AppStateProvider>();
    final message = 'Publish as $publisher. This replaces the schedule you published before, and '
        'everyone with your team key will see it as the newest one.'
        '${problems > 0 ? '\n\nUnresolved problems listed on this page: $problems.' : ''}';
    var offset = Duration.zero;
    if (app.settings.scheduleTestMode) {
      // Practice run: the predicted times (as the API's reminders use).
      final predicted = qualTimes([
        for (final m in app.matches)
          if (m.compLevel == 'qm') (match: m.matchNumber, time: m.time, actualTime: null),
      ]);
      final result = await showDialog<Duration>(
        context: context,
        builder: (_) => _PracticePublishDialog(
          message: message,
          times: predicted,
          shiftStarts: [for (final b in toBlocks(schedule.draft)) b.firstMatch],
        ),
      );
      if (result == null || !mounted) return;
      offset = result;
    } else {
      final ok = await _confirm('Publish schedule?', message, 'Publish');
      if (!ok || !mounted) return;
    }
    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await schedule.publish(publisher, timeOffset: offset);
      messenger.showSnackBar(SnackBar(
          content: Text(offset == Duration.zero ? 'Schedule published' : 'Practice schedule published')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not publish: $e')));
    }
    if (mounted) setState(() => _publishing = false);
  }

  Widget _section(ThemeData theme, String title, {String? trailing}) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Semantics(
          header: true,
          child: Text.rich(TextSpan(children: [
            TextSpan(text: title, style: theme.textTheme.titleMedium),
            if (trailing != null)
              TextSpan(
                text: '  $trailing',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
          ])),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStateProvider>();
    final schedule = context.watch<ScheduleProvider>();
    final theme = Theme.of(context);
    final settings = app.settings;
    final eventKey = settings.selectedEventKey ?? '';
    final ready = eventKey.isNotEmpty && settings.secretTeamKey.isNotEmpty;
    final qualCount = _qualCount(app);
    final draft = schedule.draft;
    final problems = qualCount == 0 || draft.isEmpty ? <String>[] : scheduleProblems(draft, qualCount, maxMatches: schedule.maxMatches);
    final publisher = settings.scouterName.trim();
    final source = schedule.draftSource;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final everyone = _everyone(schedule);
    final picked = _picked(schedule);
    final grouped = {for (final g in schedule.groups) ...g.map(nameKey)};
    final times = qualTimes([
      for (final m in app.matches)
        if (m.compLevel == 'qm') (match: m.matchNumber, time: m.time, actualTime: m.actualTime),
    ]);
    final perPerson = blocksPerPerson(draft);
    // "22 scouts × 3 shifts → 11 blocks of 7–8 matches"
    // Shifts end at lunch and the end of each day.
    final breaks = findBreaks(times);
    final cuts = schedule.options.endAtBreaks ? shiftCuts(breaks) : const <int>[];
    final ranges = blockRanges(
        qualCount, blockCountFor(picked.length, schedule.shiftsPerPerson, qualCount),
        cuts: cuts);
    final lengths = [for (final (a, b) in ranges) b - a + 1];
    final cantFit = maxMatchesProblem(picked.length, qualCount, schedule.maxMatches);
    final plan = ranges.isEmpty
        ? null
        : '${picked.length} scouts × ${schedule.shiftsPerPerson} '
            '${schedule.shiftsPerPerson == 1 ? 'shift' : 'shifts'} → ${ranges.length} '
            '${ranges.length == 1 ? 'block' : 'blocks'} of '
            '${lengths.reduce(min) == lengths.reduce(max) ? '${lengths.first}' : '${lengths.reduce(min)}–${lengths.reduce(max)}'} matches'
            '${cuts.isEmpty ? '' : ', ending at ${[for (final b in breaks) if (b.kind != BreakKind.other) b.label.toLowerCase()].join(' and ')}'}';

    Widget body;
    if (!ready) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Choose an event and enter your team key in Settings first.'),
        ),
      );
    } else {
      body = Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  children: [
                    Text(
                      source == null
                          ? 'Starting from an empty schedule.'
                          : 'Started from ${source.publishedBy}\'s schedule'
                              '${source.publishedAt == null ? '' : ', ${formatWhen(source.publishedAt!)}'}.',
                      style: muted,
                    ),
                    if (schedule.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(schedule.error!, style: TextStyle(color: theme.colorScheme.error)),
                      ),

                    // 1. Who's scouting
                    _section(theme, '1. Who\'s scouting', trailing: '${picked.length} of ${everyone.length}'),
                    if (everyone.isEmpty)
                      Text('Nobody has registered for this event yet. Names appear once people use the app '
                          'with this team key and event, or add them below.', style: muted),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final n in everyone)
                          FilterChip(
                            label: Text(n),
                            selected: schedule.roster.contains(n),
                            onSelected: (on) => schedule.setRoster(
                                on ? {...schedule.roster, n} : ({...schedule.roster}..remove(n))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: everyone.isEmpty ? null : () => schedule.setRoster(everyone.toSet()),
                          child: const Text('Select all'),
                        ),
                        TextButton(
                          onPressed: picked.isEmpty ? null : () => schedule.setRoster({}),
                          child: const Text('Select none'),
                        ),
                        TextButton.icon(
                          onPressed: () => _addName(schedule),
                          icon: const Icon(Icons.person_add_alt),
                          label: const Text('Add a name'),
                        ),
                      ],
                    ),

                    // 2. Groups
                    _section(theme, '2. Scout together', trailing: '2–6 per group'),
                    Text('Put people who like to scout together in a group; they always get the same blocks. '
                        'Everyone else is placed at random.', style: muted),
                    for (var g = 0; g < schedule.groups.length; g++)
                      _FriendGroup(
                        index: g,
                        names: schedule.groups[g],
                        onEdit: () => _editGroup(schedule, g),
                        onRemove: () {
                          final groups = [...schedule.groups]..removeAt(g);
                          schedule.setGroups(groups);
                        },
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: picked.length - grouped.length < 2 ? null : () => _editGroup(schedule, null),
                        icon: const Icon(Icons.group_add_outlined),
                        label: const Text('Add group'),
                      ),
                    ),

                    // 3. Schedule
                    _section(theme, '3. Schedule',
                        trailing: qualCount == 0 ? null : '$qualCount qualification matches'),
                    if (qualCount == 0) ...[
                      const Text('The qualification match schedule isn\'t loaded yet.'),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: app.loading ? null : app.loadMatches,
                          icon: const Icon(Icons.event_note),
                          label: const Text('Load match schedule'),
                        ),
                      ),
                    ] else ...[
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Shifts per person', style: theme.textTheme.bodyLarge),
                          DropdownButton<int>(
                            value: schedule.shiftsPerPerson,
                            items: [
                              for (var n = 1; n <= 8; n++) DropdownMenuItem(value: n, child: Text('$n')),
                            ],
                            onChanged: (v) => schedule.setShiftsPerPerson(v ?? schedule.shiftsPerPerson),
                          ),
                          Text('Max matches', style: theme.textTheme.bodyLarge),
                          DropdownButton<int>(
                            value: schedule.maxMatches,
                            items: [
                              for (final n in {
                                for (var n = 4; n <= 40; n += n < 20 ? 1 : 5) n,
                                schedule.maxMatches,
                              }.toList()..sort())
                                DropdownMenuItem(value: n, child: Text('$n')),
                            ],
                            onChanged: (v) => schedule.setMaxMatches(v ?? schedule.maxMatches),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final o = await showDialog<ScheduleOptions>(
                                context: context,
                                builder: (_) => _AlgorithmDialog(schedule.options),
                              );
                              if (o != null) schedule.setOptions(o);
                            },
                            icon: const Icon(Icons.tune),
                            label: const Text('Algorithm…'),
                          ),
                          FilledButton.icon(
                            onPressed: picked.isEmpty || cantFit != null ? null : () => _generate(schedule, ranges),
                            icon: const Icon(Icons.casino_outlined),
                            label: Text(draft.isEmpty ? 'Generate schedule' : 'Generate again'),
                          ),
                          TextButton(
                            onPressed: draft.isEmpty
                                ? null
                                : () async {
                                    if (await _confirm('Clear the schedule?',
                                        'This removes every block from the schedule below.', 'Clear')) {
                                      schedule.setDraft([]);
                                    }
                                  },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                      if (cantFit != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error,
                                  semanticLabel: 'Problem'),
                              const SizedBox(width: 8),
                              Expanded(child: Text(cantFit, style: TextStyle(color: theme.colorScheme.error))),
                            ],
                          ),
                        ),
                      if (plan != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(plan, style: theme.textTheme.bodyLarge),
                        ),
                      Text('Six scouts per block, chosen at random so everyone gets the same number of shifts. '
                          'Generate again for a whole new schedule, or tap a name to change just that spot.',
                          style: muted),
                      const SizedBox(height: 12),
                      if (draft.isNotEmpty) ...[
                        _Problems(
                          problems: problems,
                          warnings: scheduleWarnings(draft, picked),
                          qualCount: qualCount,
                          shifts: perPerson.isEmpty ? null : perPerson.values.first,
                          maxMatches: schedule.maxMatches,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (draft.isNotEmpty) ...[
                        _MatchCounts(shifts: draft, maxMatches: schedule.maxMatches),
                        const SizedBox(height: 12),
                      ],
                      if (draft.isEmpty)
                        Text('No blocks yet.', style: muted)
                      else
                        ScheduleGrid(
                          blocks: toBlocks(draft),
                          times: times,
                          breaks: breaks,
                          onTapCell: (b, station) => _editCell(schedule, b, station),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (qualCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (publisher.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('Enter your scouter name in Settings to publish.',
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  FilledButton.icon(
                    onPressed: publisher.isEmpty || draft.isEmpty || _publishing
                        ? null
                        : () => _publish(schedule, publisher, problems.length),
                    icon: _publishing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.publish),
                    label: const Text('Publish'),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Builder'),
        actions: [
          Semantics(
            button: true,
            label: 'Refresh registered scouters and schedules',
            excludeSemantics: true,
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: !ready || schedule.loading ? null : schedule.refresh,
            ),
          ),
        ],
      ),
      drawer: const NavDrawer(selectedIndex: 8),
      body: body,
    );
  }
}

/// Errors (red) and things that could be better (amber), or exactly what
/// was checked when there's nothing to fix.
class _Problems extends StatelessWidget {
  final List<String> problems;
  final List<String> warnings;
  final int qualCount;
  // Shifts each person has, when it's the same for everyone.
  final int? shifts;
  final int maxMatches;

  const _Problems({
    required this.maxMatches,
    required this.problems,
    required this.warnings,
    required this.qualCount,
    required this.shifts,
  });

  Widget _list(ThemeData theme, String title, List<String> items, Color color, IconData icon, String kind) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text('$title (${items.length})', style: theme.textTheme.titleSmall?.copyWith(color: color)),
          ),
          const SizedBox(height: 4),
          for (final p in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: color, semanticLabel: kind),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p)),
                ],
              ),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (problems.isEmpty && warnings.isEmpty) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: theme.colorScheme.primary, semanticLabel: 'OK'),
          const SizedBox(width: 8),
          Expanded(
            child: Text('All 6 positions covered for all $qualCount quals · nobody double-booked'
                '${shifts == null ? '' : ' · everyone has $shifts ${shifts == 1 ? 'shift' : 'shifts'}'}'
                ' · nobody over $maxMatches matches'),
          ),
        ],
      );
    }
    final amber = theme.brightness == Brightness.dark ? Colors.amber.shade300 : Colors.amber.shade900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (problems.isNotEmpty)
          _list(theme, 'Problems', problems, theme.colorScheme.error, Icons.error_outline, 'Problem'),
        if (problems.isNotEmpty && warnings.isNotEmpty) const SizedBox(height: 8),
        if (warnings.isNotEmpty)
          _list(theme, 'Could be better', warnings, amber, Icons.warning_amber, 'Could be better'),
      ],
    );
  }
}

/// Publish in schedule test mode: optionally as a practice run, with the
/// match times moved so a chosen shift starts at a chosen time today. Pops
/// the time offset (zero = a normal publish), or null when cancelled.
class _PracticePublishDialog extends StatefulWidget {
  final String message;
  final Map<int, MatchTime> times;
  final List<int> shiftStarts;
  const _PracticePublishDialog({required this.message, required this.times, required this.shiftStarts});

  @override
  State<_PracticePublishDialog> createState() => _PracticePublishDialogState();
}

class _PracticePublishDialogState extends State<_PracticePublishDialog> {
  late bool _practice = widget.times.isNotEmpty;
  late int _match = widget.shiftStarts.firstWhere(widget.times.containsKey, orElse: () => 1);
  // Default: 20 minutes from now, on the next 5 minutes, so the first
  // reminder (15 minutes before) comes within a few minutes.
  late TimeOfDay _at = () {
    final t = DateTime.now().add(const Duration(minutes: 20));
    final m = (t.minute + 4) ~/ 5 * 5;
    final r = DateTime(t.year, t.month, t.day, t.hour).add(Duration(minutes: m));
    return TimeOfDay(hour: r.hour, minute: r.minute);
  }();

  Duration? get _offset {
    final real = widget.times[_match]?.at;
    if (real == null) return null;
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, _at.hour, _at.minute);
    if (target.isBefore(now.subtract(const Duration(hours: 1)))) target = target.add(const Duration(days: 1));
    // Whole minutes, so times stay tidy.
    return Duration(minutes: target.difference(real).inMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final starts = [for (final m in widget.shiftStarts) if (widget.times.containsKey(m)) m];
    return AlertDialog(
      title: const Text('Publish schedule?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _practice,
              onChanged: starts.isEmpty ? null : (v) => setState(() => _practice = v ?? false),
              title: const Text('Practice run'),
              subtitle: Text(starts.isEmpty
                  ? 'Match times aren\'t loaded, so times can\'t be moved.'
                  : 'Move every match time so the shift below starts at the time below. Everyone sees the '
                      'moved times, and linked scouts get Slack reminders for them.'),
            ),
            if (_practice && starts.isNotEmpty) ...[
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<int>(
                    value: starts.contains(_match) ? _match : starts.first,
                    items: [
                      for (var i = 0; i < starts.length; i++)
                        DropdownMenuItem(value: starts[i], child: Text('Shift ${i + 1} (Q${starts[i]})')),
                    ],
                    onChanged: (v) => setState(() => _match = v ?? _match),
                  ),
                  Text('starts at', style: theme.textTheme.bodyLarge),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final t = await showTimePicker(context: context, initialTime: _at);
                      if (t != null) setState(() => _at = t);
                    },
                    icon: const Icon(Icons.schedule),
                    label: Text(_at.format(context)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _practice ? (_offset ?? Duration.zero) : Duration.zero),
          child: Text(_practice ? 'Publish practice run' : 'Publish'),
        ),
      ],
    );
  }
}

/// How Generate works: checkboxes, OK/Cancel. Pops the new options.
class _AlgorithmDialog extends StatefulWidget {
  final ScheduleOptions initial;
  const _AlgorithmDialog(this.initial);

  @override
  State<_AlgorithmDialog> createState() => _AlgorithmDialogState();
}

class _AlgorithmDialogState extends State<_AlgorithmDialog> {
  late var _o = widget.initial;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Algorithm'),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              value: _o.endAtBreaks,
              onChanged: (v) => setState(() => _o = _o.copyWith(endAtBreaks: v)),
              title: const Text('End shifts at lunch and end of day'),
              subtitle: const Text('Off: every shift is about the same length, so match counts come out more even, '
                  'but some shifts run through a break.'),
            ),
            CheckboxListTile(
              value: _o.sameCrews,
              onChanged: (v) => setState(() => _o = _o.copyWith(sameCrews: v)),
              title: const Text('Same crews every round'),
              subtitle: const Text('After the first round, the same people come around together again. '
                  'Off: each shift picks whoever has scouted least, at random, so crews mix.'),
            ),
            CheckboxListTile(
              value: _o.sameStations,
              onChanged: (v) => setState(() => _o = _o.copyWith(sameStations: v)),
              title: const Text('Keep people on the same station'),
              subtitle: const Text('People go back to the station they had last time when it\'s free. '
                  'Off: stations are shuffled every shift.'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _o), child: const Text('OK')),
      ],
    );
  }
}

/// Every scouter's match and shift count, most matches first, so the
/// extremes (and anyone over the max) are easy to spot.
class _MatchCounts extends StatelessWidget {
  final List<Shift> shifts;
  final int maxMatches;
  const _MatchCounts({required this.shifts, required this.maxMatches});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final matches = matchesPerPerson(shifts);
    final blocks = {for (final e in blocksPerPerson(shifts).entries) nameKey(e.key): e.value};
    final rows = matches.entries.toList()
      ..sort((a, b) => b.value != a.value
          ? b.value.compareTo(a.value)
          : a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    final head = theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant);
    Widget cell(String text, {TextStyle? style, bool end = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(text, style: style, textAlign: end ? TextAlign.end : TextAlign.start),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Matches per scout (${rows.length})', style: theme.textTheme.titleSmall),
        ),
        const SizedBox(height: 4),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth(),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
              children: [
                Semantics(header: true, child: cell('Scouter', style: head)),
                Semantics(header: true, child: cell('Matches', style: head, end: true)),
                Semantics(header: true, child: cell('Shifts', style: head, end: true)),
              ],
            ),
            for (var i = 0; i < rows.length; i++)
              () {
                final over = rows[i].value > maxMatches;
                final style = over ? TextStyle(color: scheme.error, fontWeight: FontWeight.bold) : null;
                return TableRow(
                  decoration: BoxDecoration(color: i.isOdd ? scheme.surfaceContainerLow : null),
                  children: [
                    cell(rows[i].key, style: style),
                    cell(over ? '${rows[i].value} (over $maxMatches)' : '${rows[i].value}', style: style, end: true),
                    cell('${blocks[nameKey(rows[i].key)] ?? 0}', style: style, end: true),
                  ],
                );
              }(),
          ],
        ),
      ],
    );
  }
}

/// A group of people who scout together, as chips.
class _FriendGroup extends StatelessWidget {
  final int index;
  final List<String> names;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _FriendGroup({
    required this.index,
    required this.names,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('Group ${index + 1}  ·  ${names.length} together', style: theme.textTheme.titleSmall),
                ),
              ),
              TextButton(
                onPressed: onEdit,
                child: Text('Edit', semanticsLabel: 'Edit group ${index + 1}'),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, semanticLabel: 'Remove group ${index + 1}'),
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
              ),
            ],
          ),
          Semantics(
            container: true,
            label: 'Group ${index + 1}: ${names.join(', ')}',
            excludeSemantics: true,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final n in names)
                  Chip(
                    avatar: const Icon(Icons.person_outline, size: 18),
                    label: Text(n),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// OK/Cancel: who scouts one station for one block.
class _CellDialog extends StatefulWidget {
  final String title;
  final String current;
  final List<String> roster;
  final List<String> others;

  const _CellDialog({
    required this.title,
    required this.current,
    required this.roster,
    required this.others,
  });

  @override
  State<_CellDialog> createState() => _CellDialogState();
}

class _CellDialogState extends State<_CellDialog> {
  static const _other = '\u0000other';
  late String _choice;
  late final TextEditingController _custom;

  @override
  void initState() {
    super.initState();
    _custom = TextEditingController();
    final all = [...widget.roster, ...widget.others];
    final match = all.where((n) => nameKey(n) == nameKey(widget.current));
    if (widget.current.trim().isEmpty) {
      _choice = '';
    } else if (match.isNotEmpty) {
      _choice = match.first;
    } else {
      _choice = _other;
      _custom.text = widget.current;
    }
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Scouter'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _choice,
                items: [
                  const DropdownMenuItem(value: '', child: Text('Nobody')),
                  for (final n in widget.roster) DropdownMenuItem(value: n, child: Text(n)),
                  for (final n in widget.others)
                    DropdownMenuItem(value: n, child: Text('$n (not selected)')),
                  const DropdownMenuItem(value: _other, child: Text('Someone else...')),
                ],
                onChanged: (v) => setState(() => _choice = v ?? ''),
              ),
            ),
          ),
          if (_choice == _other)
            TextField(
              controller: _custom,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Scouter name'),
              textCapitalization: TextCapitalization.words,
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _choice == _other ? _custom.text.trim() : _choice),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// OK/Cancel: a name that isn't in the registry.
class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add a name'),
        content: TextField(
          controller: _name,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Scouter name',
            helperText: 'For someone who hasn\'t used the app at this event yet',
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, _name.text), child: const Text('Add')),
        ],
      );
}

/// OK/Cancel checklist: 2–6 people who scout together.
class _GroupDialog extends StatefulWidget {
  final String title;
  final List<String> candidates;
  final List<String> initial;

  const _GroupDialog({required this.title, required this.candidates, required this.initial});

  @override
  State<_GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends State<_GroupDialog> {
  late final List<String> _chosen = [...widget.initial];

  @override
  Widget build(BuildContext context) {
    final n = _chosen.length;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$n chosen. Pick 2 to 6 people.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final name in widget.candidates)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _chosen.contains(name),
                      title: Text(name),
                      onChanged: !_chosen.contains(name) && n >= 6
                          ? null
                          : (on) => setState(() => on == true ? _chosen.add(name) : _chosen.remove(name)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: n < 2 ? null : () => Navigator.pop(context, _chosen),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
