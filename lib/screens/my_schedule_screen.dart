import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/scout_schedule.dart';
import '../providers/app_state_provider.dart';
import '../providers/schedule_provider.dart';
import '../services/api_service.dart';
import '../services/browser.dart';
import '../services/scouter_registry.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/schedule_grid.dart';

/// Students' screen: my shifts, add them to a calendar, and everyone's.
class MyScheduleScreen extends StatefulWidget {
  const MyScheduleScreen({super.key});

  @override
  State<MyScheduleScreen> createState() => _MyScheduleScreenState();
}

class _MyScheduleScreenState extends State<MyScheduleScreen> {
  // Match times arrive with the match list; refresh it once per session.
  static final Set<String> _matchesRefreshed = {};
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

  Future<void> _calendar({required bool open}) async {
    final messenger = ScaffoldMessenger.of(context);
    final token = await ScouterRegistry.instance.calendarToken(context.read<AppStateProvider>().settings);
    if (token == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not get your calendar link. Check your connection and try again.')));
      return;
    }
    if (open) {
      openUrl(ApiService.calendarUrl(token, webcal: true));
    } else {
      await Clipboard.setData(ClipboardData(text: ApiService.calendarUrl(token)));
      messenger.showSnackBar(const SnackBar(content: Text('Calendar link copied')));
    }
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
    final times = _qualTimes(app);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final mine = current?.shiftsFor(name) ?? const <Shift>[];

    String? startOf(int match) {
      final t = times[match];
      return t == null ? null : formatWhen(t.at);
    }

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
                const SizedBox(height: 16),
                Semantics(header: true, child: Text('My shifts', style: theme.textTheme.titleMedium)),
                if (name.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Enter your scouter name in Settings to see your shifts.'),
                  )
                else if (mine.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No shifts for "$name" in this schedule.'),
                  )
                else
                  for (final s in mine)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${stationLabel(s.station)} · ${s.range}'),
                      subtitle: startOf(s.firstMatch) == null
                          ? null
                          : Text('${times[s.firstMatch]!.actual ? 'Started' : 'Starts about'} ${startOf(s.firstMatch)}'),
                    ),
                if (name.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _calendar(open: true),
                        icon: const Icon(Icons.event),
                        label: const Text('Add to my calendar'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _calendar(open: false),
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy calendar link'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your calendar reminds you 15 minutes before each shift and updates when a new schedule is published. '
                    'In Google Calendar, use Add by URL with the copied link.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 24),
                Semantics(header: true, child: Text('Everyone', style: theme.textTheme.titleMedium)),
                const SizedBox(height: 8),
                ScheduleGrid(
                  blocks: toBlocks(current.shifts),
                  me: name,
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
      drawer: const NavDrawer(selectedIndex: 3),
      body: body,
    );
  }

  static Map<int, MatchTime> _qualTimes(AppStateProvider app) => qualTimes([
        for (final m in app.matches)
          if (m.compLevel == 'qm') (match: m.matchNumber, time: m.time, actualTime: m.actualTime),
      ]);
}
