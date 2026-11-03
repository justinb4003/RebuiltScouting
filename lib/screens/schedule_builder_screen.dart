import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/scout_schedule.dart';
import '../providers/app_state_provider.dart';
import '../providers/schedule_provider.dart';
import '../widgets/nav_drawer.dart';

/// Lead's screen: build the match-scouting schedule and publish it.
class ScheduleBuilderScreen extends StatefulWidget {
  const ScheduleBuilderScreen({super.key});

  @override
  State<ScheduleBuilderScreen> createState() => _ScheduleBuilderScreenState();
}

class _ScheduleBuilderScreenState extends State<ScheduleBuilderScreen> {
  // Kept across visits within a session.
  static int _blockLength = 8;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final s = context.read<AppStateProvider>().settings;
      final schedule = context.read<ScheduleProvider>();
      await schedule.load(s.selectedEventKey ?? '', s.secretTeamKey);
      if (mounted) schedule.startDraftIfNeeded();
      if (mounted) setState(() {});
    });
  }

  int _qualCount(AppStateProvider app) => app.matches
      .where((m) => m.compLevel == 'qm')
      .fold(0, (a, m) => m.matchNumber > a ? m.matchNumber : a);

  List<String> _names(ScheduleProvider schedule) => [
        for (final s in schedule.scouters) s.name,
      ];

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

  Future<void> _fill(ScheduleProvider schedule, int qualCount) async {
    final names = _names(schedule);
    if (names.isEmpty) return;
    if (schedule.draft.isNotEmpty &&
        !await _confirm('Replace the draft?',
            'Fill evenly starts over and replaces every block in the draft.', 'Replace')) {
      return;
    }
    schedule.setDraft(fillEvenly(names, qualCount, _blockLength));
  }

  Future<void> _edit(ScheduleProvider schedule, int qualCount, String station, int? index) async {
    final draft = schedule.draft;
    final existing = index == null ? null : draft[index];
    Shift? initial = existing;
    if (initial == null) {
      var next = 1;
      for (final s in draft) {
        if (s.station == station && s.lastMatch >= next) next = s.lastMatch + 1;
      }
      if (qualCount > 0 && next > qualCount) next = qualCount;
      final last = next + _blockLength - 1 > qualCount ? qualCount : next + _blockLength - 1;
      initial = Shift(scouterName: '', station: station, firstMatch: next, lastMatch: last);
    }
    final result = await showDialog<_BlockResult>(
      context: context,
      builder: (ctx) => _BlockDialog(
        initial: initial!,
        isNew: existing == null,
        names: _names(schedule),
        qualCount: qualCount,
      ),
    );
    if (result == null) return;
    final updated = List<Shift>.of(draft);
    if (result.delete) {
      updated.removeAt(index!);
    } else if (index == null) {
      updated.add(result.shift!);
    } else {
      updated[index] = result.shift!;
    }
    schedule.setDraft(updated);
  }

  Future<void> _publish(ScheduleProvider schedule, String publisher, int problems) async {
    final ok = await _confirm(
      'Publish schedule?',
      'Publish as $publisher. This replaces the schedule you published before, and '
          'everyone with your team key will see it as the newest one.'
          '${problems > 0 ? '\n\nUnresolved problems listed on this page: $problems.' : ''}',
      'Publish',
    );
    if (!ok || !mounted) return;
    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await schedule.publish(publisher);
      messenger.showSnackBar(const SnackBar(content: Text('Schedule published')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not publish: $e')));
    }
    if (mounted) setState(() => _publishing = false);
  }

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
    final problems = qualCount == 0 ? <String>[] : scheduleProblems(draft, qualCount);
    final publisher = settings.scouterName.trim();
    final source = schedule.draftSource;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);

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
                    const SizedBox(height: 12),
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
                      Text('$qualCount qualification matches, ${schedule.scouters.length} registered scouters.',
                          style: muted),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Block length', style: theme.textTheme.bodyLarge),
                          DropdownButton<int>(
                            value: _blockLength,
                            items: [
                              for (final n in const [6, 8, 10, 12])
                                DropdownMenuItem(value: n, child: Text('$n matches')),
                            ],
                            onChanged: (v) => setState(() => _blockLength = v ?? _blockLength),
                          ),
                          OutlinedButton(
                            onPressed: schedule.scouters.isEmpty ? null : () => _fill(schedule, qualCount),
                            child: const Text('Fill evenly'),
                          ),
                          TextButton(
                            onPressed: draft.isEmpty
                                ? null
                                : () async {
                                    if (await _confirm('Clear the draft?',
                                        'This removes every block from the draft.', 'Clear')) {
                                      schedule.setDraft([]);
                                    }
                                  },
                            child: const Text('Clear all'),
                          ),
                        ],
                      ),
                      if (schedule.scouters.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('No registered scouters yet. Names appear once people use the app '
                              'with this team key and event. You can still type names into blocks.',
                              style: muted),
                        ),
                      const SizedBox(height: 16),
                      _Problems(problems: problems),
                      const SizedBox(height: 8),
                      for (final station in scheduleStations)
                        _StationSection(
                          station: station,
                          shifts: draft,
                          onEdit: (i) => _edit(schedule, qualCount, station, i),
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

class _Problems extends StatelessWidget {
  final List<String> problems;
  const _Problems({required this.problems});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (problems.isEmpty) {
      return Row(children: [
        Icon(Icons.check_circle_outline, size: 18, color: theme.colorScheme.primary, semanticLabel: 'OK'),
        const SizedBox(width: 8),
        const Expanded(child: Text('No problems: every station is covered and nobody is double-booked.')),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Problems (${problems.length})',
              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.error)),
        ),
        const SizedBox(height: 4),
        for (final p in problems)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber, size: 18, color: theme.colorScheme.error, semanticLabel: 'Problem'),
                const SizedBox(width: 8),
                Expanded(child: Text(p)),
              ],
            ),
          ),
      ],
    );
  }
}

class _StationSection extends StatelessWidget {
  final String station;
  final List<Shift> shifts;
  final void Function(int? index) onEdit;

  const _StationSection({required this.station, required this.shifts, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = [
      for (var i = 0; i < shifts.length; i++)
        if (shifts[i].station == station) i,
    ]..sort((a, b) => shifts[a].firstMatch.compareTo(shifts[b].firstMatch));
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(stationLabel(station), style: theme.textTheme.titleMedium),
          ),
          if (mine.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No blocks', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
          for (final i in mine)
            Semantics(
              button: true,
              label: 'Edit ${stationLabel(station)} block: ${shifts[i].scouterName}, ${shifts[i].range}',
              excludeSemantics: true,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(shifts[i].scouterName),
                subtitle: Text(shifts[i].range),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => onEdit(i),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              label: 'Add block to ${stationLabel(station)}',
              button: true,
              excludeSemantics: true,
              child: TextButton.icon(
                onPressed: () => onEdit(null),
                icon: const Icon(Icons.add),
                label: const Text('Add block'),
              ),
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}

class _BlockResult {
  final Shift? shift;
  final bool delete;
  const _BlockResult.save(Shift this.shift) : delete = false;
  const _BlockResult.remove()
      : shift = null,
        delete = true;
}

/// OK/Cancel dialog editing a draft of one block.
class _BlockDialog extends StatefulWidget {
  final Shift initial;
  final bool isNew;
  final List<String> names;
  final int qualCount;

  const _BlockDialog({
    required this.initial,
    required this.isNew,
    required this.names,
    required this.qualCount,
  });

  @override
  State<_BlockDialog> createState() => _BlockDialogState();
}

class _BlockDialogState extends State<_BlockDialog> {
  static const _other = '\u0000other';
  late final List<String> _options;
  String? _choice;
  late final TextEditingController _custom;
  late final TextEditingController _first;
  late final TextEditingController _last;
  String? _error;

  @override
  void initState() {
    super.initState();
    final name = widget.initial.scouterName;
    final key = nameKey(name);
    _options = [...widget.names];
    final match = _options.where((n) => nameKey(n) == key);
    _custom = TextEditingController();
    if (name.isEmpty) {
      _choice = null;
    } else if (match.isNotEmpty) {
      _choice = match.first;
    } else {
      _choice = _other;
      _custom.text = name;
    }
    _first = TextEditingController(text: '${widget.initial.firstMatch}');
    _last = TextEditingController(text: '${widget.initial.lastMatch}');
  }

  @override
  void dispose() {
    _custom.dispose();
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  void _save() {
    final name = (_choice == _other ? _custom.text : _choice ?? '').trim();
    final first = int.tryParse(_first.text.trim());
    final last = int.tryParse(_last.text.trim());
    String? error;
    if (name.isEmpty) {
      error = 'Choose or type a scouter.';
    } else if (first == null || last == null) {
      error = 'Enter the first and last match numbers.';
    } else if (first < 1 || last < first) {
      error = 'The first match must be at least 1 and no later than the last.';
    } else if (widget.qualCount > 0 && last > widget.qualCount) {
      error = 'There are only ${widget.qualCount} qualification matches.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(
        context, _BlockResult.save(widget.initial.copyWith(scouterName: name, firstMatch: first, lastMatch: last)));
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return AlertDialog(
      title: Text('${widget.isNew ? 'Add' : 'Edit'} ${stationLabel(widget.initial.station)} block'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Scouter'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _choice,
                  hint: const Text('Choose a scouter'),
                  items: [
                    for (final n in _options) DropdownMenuItem(value: n, child: Text(n)),
                    const DropdownMenuItem(value: _other, child: Text('Someone else...')),
                  ],
                  onChanged: (v) => setState(() => _choice = v),
                ),
              ),
            ),
            if (_choice == _other)
              TextField(
                controller: _custom,
                decoration: const InputDecoration(labelText: 'Scouter name'),
                textCapitalization: TextCapitalization.words,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _first,
                    decoration: const InputDecoration(labelText: 'First match'),
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _last,
                    decoration: const InputDecoration(labelText: 'Last match'),
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                  ),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        if (!widget.isNew)
          TextButton(
            onPressed: () => Navigator.pop(context, const _BlockResult.remove()),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('OK')),
      ],
    );
  }
}
