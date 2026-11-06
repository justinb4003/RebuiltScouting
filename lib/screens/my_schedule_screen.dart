import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/scout_schedule.dart';
import '../providers/app_state_provider.dart';
import '../providers/schedule_provider.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/schedule_grid.dart';

/// Students' screen: my shifts, or everyone's.
class MyScheduleScreen extends StatefulWidget {
  const MyScheduleScreen({super.key});

  @override
  State<MyScheduleScreen> createState() => _MyScheduleScreenState();
}

class _MyScheduleScreenState extends State<MyScheduleScreen> {
  // Match times arrive with the match list; refresh it once per session.
  static final Set<String> _matchesRefreshed = {};
  // Just my shifts, or the whole schedule; kept for the app session.
  static bool _everyone = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = context.read<AppStateProvider>();
      final s = app.settings;
      context.read<ScheduleProvider>().load(s.selectedEventKey ?? '', s.secretTeamKey);
      final event = s.selectedEventKey ?? '';
      if (event.isNotEmpty && _matchesRefreshed.add(event)) app.loadMatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStateProvider>();
    final schedule = context.watch<ScheduleProvider>();
    final theme = Theme.of(context);
    final settings = app.settings;
    final name = settings.scouterName.trim();
    final eventKey = settings.selectedEventKey ?? '';
    final ready = eventKey.isNotEmpty && settings.secretTeamKey.isNotEmpty;
    final current = schedule.newest;
    final times = _qualTimes(app, current?.timeOffset ?? Duration.zero);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final mine = current?.shiftsFor(name) ?? const <Shift>[];

    Widget body;
    if (!ready) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Choose an event and enter your team key in Settings first.'),
        ),
      );
    } else {
      body = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (schedule.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(schedule.error!, style: TextStyle(color: theme.colorScheme.error)),
                ),
              if (current == null)
                Text(schedule.loading ? 'Loading the schedule...' : 'No schedule has been published yet.')
              else ...[
                Text(
                  'Published by ${current.publishedBy}'
                  '${current.publishedAt == null ? '' : ' · ${formatWhen(current.publishedAt!)}'}',
                  style: muted,
                ),
                if (current.isPractice)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.science_outlined, color: theme.colorScheme.onTertiaryContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Practice run: match times are moved to test shift reminders. '
                            'They aren\'t the event\'s real times.',
                            style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (name.isNotEmpty && mine.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'You have ${mine.length} ${mine.length == 1 ? 'shift' : 'shifts'} as $name'
                      '${times[mine.first.firstMatch] == null ? '' : '; the first ${times[mine.first.firstMatch]!.actual ? 'started' : 'starts about'} ${formatWhen(times[mine.first.firstMatch]!.at)}'}.',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, icon: Icon(Icons.person), label: Text('My shifts')),
                    ButtonSegment(value: true, icon: Icon(Icons.groups), label: Text('Everyone')),
                  ],
                  selected: {_everyone},
                  onSelectionChanged: (v) => setState(() => _everyone = v.first),
                ),
                const SizedBox(height: 12),
                if (!_everyone && name.isEmpty)
                  const Text('Enter your scouter name in Settings to see your shifts.')
                else if (!_everyone && mine.isEmpty)
                  Text('No shifts for "$name" in this schedule. Check that your scouter name in Settings '
                      'matches the schedule, or choose Everyone.')
                else
                  ScheduleGrid(
                    blocks: toBlocks(current.shifts),
                    me: name,
                    onlyMine: !_everyone,
                    times: times,
                    breaks: findBreaks(times),
                  ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        actions: [
          Semantics(
            button: true,
            label: 'Refresh schedule',
            excludeSemantics: true,
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: !ready || schedule.loading
                  ? null
                  : () {
                      schedule.refresh();
                      app.loadMatches();
                    },
            ),
          ),
        ],
      ),
      drawer: const NavDrawer(selectedIndex: 0),
      body: body,
    );
  }

  static Map<int, MatchTime> _qualTimes(AppStateProvider app, Duration offset) => qualTimes([
        for (final m in app.matches)
          if (m.compLevel == 'qm') (match: m.matchNumber, time: m.time, actualTime: m.actualTime),
      ], offset: offset);
}
