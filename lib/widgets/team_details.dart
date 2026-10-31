import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../analytics/match_stats.dart';
import '../analytics/scout_stats.dart';
import '../models/opr.dart';
import '../models/pit_result.dart';
import '../providers/app_state_provider.dart';
import '../providers/event_data_provider.dart';
import '../services/storage_service.dart';
import 'match_card.dart';
import 'page_dialog.dart';
import 'pick_list_team_sheet.dart' show teamLabel;

/// Open the Team Details screen for [teamNumber].
void openTeamDetails(BuildContext context, int teamNumber) {
  Navigator.of(context).pushNamed('/team-details', arguments: teamNumber);
}

/// Small ⓘ next to a team name that opens [showTeamDetailsDialog].
class TeamInfoButton extends StatelessWidget {
  final int teamNumber;

  const TeamInfoButton(this.teamNumber, {super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Team details',
        icon: const Icon(Icons.info_outline, size: 18),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
        onPressed: () => showTeamDetailsDialog(context, teamNumber),
      );
}

/// Team Details over the current screen; closing returns right where the
/// user was. The open-in-new icon goes to the full page instead.
Future<void> showTeamDetailsDialog(BuildContext context, int teamNumber) {
  return showPageDialog(
    context,
    title: teamLabel(context, teamNumber),
    actions: [
      Builder(
        builder: (dialogContext) => IconButton(
          tooltip: 'Open Team Details page',
          icon: const Icon(Icons.open_in_new),
          onPressed: () {
            Navigator.pop(dialogContext);
            openTeamDetails(context, teamNumber);
          },
        ),
      ),
    ],
    body: CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: TeamDetailView(teamNumber: teamNumber, showName: false),
        ),
      ],
    ),
  );
}

/// Everything we know about one team at the selected event: pit scouting,
/// scouted averages, OPR and every match they're in. A sliver, so put it in
/// a CustomScrollView; match cards build lazily as they scroll into view.
/// Each section collapses
/// (remembered per team) and can be moved up or down (one order for every
/// team).
class TeamDetailView extends StatefulWidget {
  final int teamNumber;

  /// Off where the number and name are already in a title bar.
  final bool showName;

  const TeamDetailView(
      {super.key, required this.teamNumber, this.showName = true});

  @override
  State<TeamDetailView> createState() => _TeamDetailViewState();
}

enum _Section {
  pit('Pit scouting'),
  scouted('Scouted averages'),
  opr('OPR'),
  matches('Matches');

  final String title;
  const _Section(this.title);
}

class _TeamDetailViewState extends State<TeamDetailView> {
  // Prefs are async; keep what's been read so reopening doesn't flash.
  static final Map<int, Set<String>> _collapsedCache = {};
  static List<String>? _orderCache;

  Set<String> _collapsed = {};
  List<_Section> _order = _Section.values;

  @override
  void initState() {
    super.initState();
    final team = widget.teamNumber;
    final cached = _collapsedCache[team];
    if (cached != null) _collapsed = cached;
    if (_orderCache != null) _order = _orderFrom(_orderCache!);
    final storage = StorageService.instance;
    if (cached == null) {
      storage.loadCollapsedSections(team).then((v) {
        _collapsedCache[team] = v;
        if (mounted) setState(() => _collapsed = v);
      });
    }
    if (_orderCache == null) {
      storage.loadSectionOrder().then((v) {
        _orderCache = v;
        if (mounted) setState(() => _order = _orderFrom(v));
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.ensureEventData();
    });
  }

  /// Saved names in saved order; sections added since go at the end.
  static List<_Section> _orderFrom(List<String> names) => [
        for (final n in names)
          ..._Section.values.where((s) => s.name == n),
        for (final s in _Section.values)
          if (!names.contains(s.name)) s,
      ];

  void _toggle(_Section s) {
    setState(() {
      _collapsed = {..._collapsed};
      if (!_collapsed.remove(s.name)) _collapsed.add(s.name);
    });
    _collapsedCache[widget.teamNumber] = _collapsed;
    StorageService.instance
        .saveCollapsedSections(widget.teamNumber, _collapsed);
  }

  void _move(_Section s, int by) {
    final i = _order.indexOf(s);
    final j = i + by;
    if (j < 0 || j >= _order.length) return;
    setState(() {
      _order = [..._order]
        ..removeAt(i)
        ..insert(j, s);
    });
    _orderCache = [for (final s in _order) s.name];
    StorageService.instance.saveSectionOrder(_orderCache!);
  }

  Future<void> _refresh() async {
    final app = context.read<AppStateProvider>();
    await Future.wait([context.read<EventDataProvider>().refresh(), app.loadPitResults()]);
  }

  Widget _header(_Section s, String title) {
    final theme = Theme.of(context);
    final open = !_collapsed.contains(s.name);
    final i = _order.indexOf(s);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _toggle(s),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
            child: Row(
              children: [
                Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
                PopupMenuButton<int>(
                  tooltip: 'Move section',
                  icon: const Icon(Icons.swap_vert),
                  onSelected: (by) => _move(s, by),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: -1, enabled: i > 0, child: const Text('Move up')),
                    PopupMenuItem(
                        value: 1, enabled: i < _order.length - 1, child: const Text('Move down')),
                  ],
                ),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.expand_more),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.watch<AppStateProvider>();
    final data = context.watch<EventDataProvider>();
    final team = widget.teamNumber;

    final info = app.teams.where((t) => t.teamNumber == team);
    final nickname = info.isEmpty ? '' : info.first.nickname;
    final location = info.isEmpty
        ? ''
        : [info.first.city, info.first.stateProv].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    final pit = app.getAllPitResultsForTeam(team)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final matches = matchesForTeam(data.matches, team);
    final record = teamRecord(data.matches, team);
    final stats = data.statsFor(team);

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showName)
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '$team', style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (nickname.isNotEmpty) TextSpan(text: '  $nickname'),
                      ]),
                      style: theme.textTheme.headlineSmall,
                    ),
                  if (location.isNotEmpty)
                    Text(location,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (data.loading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              IconButton(
                tooltip: 'Refresh data',
                icon: const Icon(Icons.refresh),
                onPressed: _refresh,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          [
            if (record.played > 0) 'Record ${record.label}',
            if (record.avgRp != null) '${record.avgRp!.toStringAsFixed(2)} RP/match',
            if (record.avgScore != null) '${record.avgScore!.toStringAsFixed(0)} avg pts',
            '${stats?.matchesScouted ?? 0} matches scouted',
          ].join('  ·  '),
          style: theme.textTheme.bodyMedium,
        ),
        Text(
          data.lastFetched == null ? 'Showing saved data' : 'Updated ${_hm(data.lastFetched!)}',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        if (data.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(data.error!, style: TextStyle(color: theme.colorScheme.error)),
          ),
      ],
    );

    Widget body(_Section s) => switch (s) {
          _Section.pit => _PitSection(records: pit),
          _Section.scouted => stats == null || stats.rows.isEmpty
              ? const Text('No matches scouted for this team yet.')
              : _SummaryTiles(stats: stats, all: data.teamStats),
          _Section.opr => data.opr[team] == null
              ? const Text('No OPR yet; it needs qualification match results.')
              : _OprTiles(team: team, opr: data.opr),
          _Section.matches => const Text('No matches found for this team at this event.'),
        };

    return SliverMainAxisGroup(slivers: [
      SliverToBoxAdapter(child: heading),
      for (final s in _order) ...[
        SliverToBoxAdapter(
          child: _header(s, s == _Section.matches ? '${s.title} (${matches.length})' : s.title),
        ),
        if (s == _Section.matches && matches.isNotEmpty)
          // Match cards build only as they scroll into view.
          if (_collapsed.contains(s.name))
            const SliverToBoxAdapter(child: SizedBox.shrink())
          else
            SliverList.builder(
              itemCount: matches.length,
              itemBuilder: (context, i) {
                final m = matches[i];
                return MatchCard(key: ValueKey(m.key), match: m, focusTeam: team);
              },
            )
        else
          SliverToBoxAdapter(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _collapsed.contains(s.name)
                  ? const SizedBox(width: double.infinity)
                  : Align(alignment: Alignment.centerLeft, child: body(s)),
            ),
          ),
      ],
    ]);
  }

  static String _hm(DateTime t) =>
      '${t.hour % 12 == 0 ? 12 : t.hour % 12}:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

// ---------------------------------------------------------------- Scouted

class _SummaryTiles extends StatelessWidget {
  final TeamStats stats;
  final Map<int, TeamStats> all;
  const _SummaryTiles({required this.stats, required this.all});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / 130).floor().clamp(2, 6);
      const gap = 8.0;
      final width = (c.maxWidth - gap * (cols - 1)) / cols;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final section in ScoutStats.sections)
            Builder(builder: (context) {
              // Skip behaviours never seen, so the grid stays about numbers.
              final defs = [
                for (final d in ScoutStats.inSection(section))
                  if (stats.mean(d.key) != null && !(d.binary && stats.mean(d.key) == 0)) d
              ];
              if (defs.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Wrap(spacing: gap, runSpacing: gap, children: [
                      for (final d in defs)
                        SizedBox(width: width, child: _StatTile(def: d, stats: stats, all: all)),
                    ]),
                  ],
                ),
              );
            }),
          Text('Averages per scouted match. Rates a team never showed are hidden.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      );
    });
  }
}

String formatStat(StatDef d, double? v) {
  if (v == null) return '–';
  if (d.binary) return '${(v * 100).round()}%';
  return v.toStringAsFixed(1);
}

class _StatTile extends StatelessWidget {
  final StatDef def;
  final TeamStats stats;
  final Map<int, TeamStats> all;
  const _StatTile({required this.def, required this.stats, required this.all});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rank = rankOf(all, stats.teamNumber, def.key);
    final delta = def.binary ? null : stats.halfDelta(def.key);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(def.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(formatStat(def, stats.mean(def.key)),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          Text(
            [
              'evt ${formatStat(def, eventMean(all, def.key))}',
              if (rank != null) '#$rank',
              if (delta != null && delta.abs() >= 0.05) '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
            ].join(' · '),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- OPR

/// GetOPRData fields worth a tile, with labels; the API returns every
/// numeric score-breakdown field.
const _oprFields = [
  ('totalPoints', 'Total points'),
  ('totalAutoPoints', 'Auto points'),
  ('totalTeleopPoints', 'Teleop points'),
  ('hubScore_totalCount', 'Fuel scored'),
  ('totalTowerPoints', 'Tower points'),
  ('rp', 'Ranking points'),
  ('foulPoints', 'Foul points drawn'),
];

class _OprTiles extends StatelessWidget {
  final int team;
  final OprData opr;
  const _OprTiles({required this.team, required this.opr});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = opr[team]!;
    final muted = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / 130).floor().clamp(2, 6);
      const gap = 8.0;
      final width = (c.maxWidth - gap * (cols - 1)) / cols;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: gap, runSpacing: gap, children: [
            for (final (field, label) in _oprFields)
              if (mine[field] != null)
                SizedBox(
                  width: width,
                  child: Builder(builder: (context) {
                    final v = mine[field]!;
                    final all = [for (final t in opr.values) t[field] ?? 0];
                    final rank = all.where((x) => x > v).length + 1;
                    final mean = all.reduce((a, b) => a + b) / all.length;
                    final digits = field == 'rp' ? 2 : 1;
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: muted),
                          const SizedBox(height: 2),
                          Text(v.toStringAsFixed(digits),
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          Text('evt ${mean.toStringAsFixed(digits)} · #$rank of ${all.length}', style: muted),
                        ],
                      ),
                    );
                  }),
                ),
          ]),
          const SizedBox(height: 8),
          Text('Estimated contribution to the alliance score in qualification matches.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      );
    });
  }
}

// -------------------------------------------------------------------- Pit

class _PitSection extends StatelessWidget {
  final List<PitResult> records; // newest first
  const _PitSection({required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const Text('No pit scouting for this team yet.');
    final full = records.where((r) => r.hasFullData).toList();
    final notes = records.where((r) => !r.hasFullData && r.notes.trim().isNotEmpty).toList();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < full.length; i++) _PitRecordCard(record: full[i], expanded: i == 0),
        if (full.isEmpty) const Text('No full pit scouting form yet.'),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Robot notes', style: theme.textTheme.titleSmall),
          for (final n in notes)
            Card(
              margin: const EdgeInsets.only(top: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.notes.trim()),
                    const SizedBox(height: 2),
                    Text(n.scouterName,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _PitRecordCard extends StatelessWidget {
  final PitResult record;
  final bool expanded;
  const _PitRecordCard({required this.record, required this.expanded});

  static String _yn(bool v) => v ? 'Yes' : 'No';

  List<(String, String)> _fields() {
    final r = record;
    String clean(String s) => (s.trim() == 'None') ? '' : s.trim();
    final starts = [
      if (r.autoStartLeftTrench) 'Left trench',
      if (r.autoStartLeftBump) 'Left bump',
      if (r.autoStartHub) 'Hub',
      if (r.autoStartRightBump) 'Right bump',
      if (r.autoStartRightTrench) 'Right trench',
    ];
    final autoNotes = [
      ('Left trench', r.autoNotesLeftTrench),
      ('Left bump', r.autoNotesLeftBump),
      ('Hub', r.autoNotesHub),
      ('Right bump', r.autoNotesRightBump),
      ('Right trench', r.autoNotesRightTrench),
    ].where((e) => clean(e.$2).isNotEmpty).map((e) => '${e.$1}: ${clean(e.$2)}').join('\n');
    return [
      ('Drive train', r.driveTrain == 'Other' && r.driveTrainOther.isNotEmpty ? r.driveTrainOther : r.driveTrain),
      ('Fuel capacity', '${r.fuelCapacity}'),
      ('Ground pickup', _yn(r.groundPickup)),
      ('Human player pickup', _yn(r.humanPlayerPickup)),
      ('Shoot on move', _yn(r.shootOnMove)),
      ('Hopper empty time', clean(r.hopperEmptyTime)),
      ('Auto starting spot', r.autoStartingSpot),
      ('Auto start positions', starts.join(', ')),
      ('Auto notes', autoNotes),
      ('Auto crash concern', r.autoCrashConcern ? 'Yes' : ''),
      ('Auto hang', r.autoHang ? 'Yes${clean(r.autoHangPosition).isEmpty ? '' : ' (${clean(r.autoHangPosition)})'}' : 'No'),
      ('Hangs', r.hangingWorks ? 'Yes, level ${r.hangingLevel}' : 'No'),
      ('Hang time', clean(r.hangingTime)),
      ('Hang how', clean(r.hangingHow)),
      ('Teleop plan (active)', clean(r.teleopActivePlan)),
      ('Teleop plan (inactive)', clean(r.teleopInactivePlan)),
      ('Willing to play defense', _yn(r.willingToPlayDefense)),
      ('Prefers defense', _yn(r.ratherPlayDefense)),
      ('Fun fact', clean(r.funQuestion)),
      ('Notes', clean(r.notes)),
    ].where((e) => e.$2.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fields = _fields();
    final stamp = record.timestamp;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: expanded,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(record.scouterName.isEmpty ? 'Unknown scouter' : record.scouterName),
        subtitle: Text('${stamp.year}-${stamp.month.toString().padLeft(2, '0')}-${stamp.day.toString().padLeft(2, '0')}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (record.imageUrls.isNotEmpty)
            SizedBox(
              height: 130,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final url in record.imageUrls)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 8),
                      child: InkWell(
                        onTap: () => _showPhoto(context, url),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(url,
                              height: 122,
                              fit: BoxFit.cover,
                              // The photo host sends no CORS headers, so decode
                              // via a plain <img> element on web.
                              webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                              errorBuilder: (_, _, _) => Container(
                                    width: 122,
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    child: const Icon(Icons.broken_image_outlined),
                                  )),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          for (final f in fields)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(f.$1,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ),
                  Expanded(child: Text(f.$2)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showPhoto(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(
            child: Image.network(url,
                fit: BoxFit.contain, webHtmlElementStrategy: WebHtmlElementStrategy.prefer)),
      ),
    );
  }
}
