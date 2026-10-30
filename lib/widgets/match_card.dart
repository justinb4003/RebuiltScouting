import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/match_result.dart';
import '../models/scouted_match.dart';
import '../providers/app_state_provider.dart';
import '../providers/event_data_provider.dart';
import 'team_details.dart';

const redAllianceColor = Color(0xFFC62828);
const blueAllianceColor = Color(0xFF1565C0);

Color allianceColor(String side) =>
    side == 'red' ? redAllianceColor : blueAllianceColor;

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

String _tower(int level) => level <= 0 ? 'none' : 'L$level';

/// One match: both alliances, official score/winner/RP and our scouting.
///
/// Shared by Team Details (pass [focusTeam] to highlight that team and show
/// our scouted line for it inline) and Match Breakdowns (no focus; expanding
/// shows all six teams' scouting next to the official score breakdown).
class MatchCard extends StatefulWidget {
  final MatchResult match;
  final int? focusTeam;
  final bool initiallyExpanded;

  const MatchCard({
    super.key,
    required this.match,
    this.focusTeam,
    this.initiallyExpanded = false,
  });

  @override
  State<MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<MatchCard> {
  late bool _expanded = widget.initiallyExpanded;

  MatchResult get match => widget.match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final names = {
      for (final t in context.watch<AppStateProvider>().teams)
        t.teamNumber: t.nickname,
    };
    final scouted = context.watch<EventDataProvider>().scoutedInMatch(match);
    final focus = widget.focusTeam;
    final focusRows = focus == null
        ? const <ScoutedMatch>[]
        : (scouted[focus] ?? const []);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(theme),
              const SizedBox(height: 8),
              _allianceRow(theme, 'red'),
              const SizedBox(height: 4),
              _allianceRow(theme, 'blue'),
              if (focus != null && match.isQual && match.played) ...[
                const SizedBox(height: 8),
                if (focusRows.isEmpty)
                  Text(
                    'Not scouted',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  for (final r in focusRows)
                    _ScoutedLine(row: r, showTeam: false),
              ],
              if (_expanded) ...[
                const Divider(height: 24),
                for (final side in ['red', 'blue']) ...[
                  _allianceDetail(theme, side, names, scouted),
                  const SizedBox(height: 8),
                ],
                if (match.red.breakdown != null && match.blue.breakdown != null)
                  _BreakdownTable(match: match),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) {
    final focus = widget.focusTeam;
    final won = focus == null ? null : match.won(focus);
    String? badge;
    Color? badgeColor;
    if (focus != null && match.hasTeam(focus) && match.played) {
      if (won == true) {
        badge = 'WIN';
        badgeColor = Colors.green.shade700;
      } else if (won == false) {
        badge = 'LOSS';
        badgeColor = theme.colorScheme.error;
      } else {
        badge = 'TIE';
        badgeColor = theme.colorScheme.outline;
      }
    } else if (!match.played) {
      badge = 'UPCOMING';
      badgeColor = theme.colorScheme.outline;
    }
    final t = match.startTime;
    return Row(
      children: [
        Text(match.displayName, style: theme.textTheme.titleSmall),
        if (t != null) ...[
          const SizedBox(width: 8),
          Text(
            _clock(t),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const Spacer(),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor!.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: badgeColor),
            ),
            child: Text(
              badge,
              style: theme.textTheme.labelSmall?.copyWith(
                color: badgeColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Icon(
          _expanded ? Icons.expand_less : Icons.expand_more,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }

  static String _clock(DateTime t) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '${days[t.weekday - 1]} $h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  Widget _allianceRow(ThemeData theme, String side) {
    final alliance = side == 'red' ? match.red : match.blue;
    final color = allianceColor(side);
    final winner = match.winner == side;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final t in alliance.teams)
                  _TeamChip(
                    team: t,
                    color: color,
                    highlighted: t == widget.focusTeam,
                  ),
              ],
            ),
          ),
          if (match.played) ...[
            const SizedBox(width: 8),
            if (alliance.breakdown != null && match.isQual && alliance.rp > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${alliance.rp} RP',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (winner)
              Icon(Icons.emoji_events, size: 16, color: Colors.amber.shade700),
            const SizedBox(width: 2),
            Text(
              '${alliance.score}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: winner ? FontWeight.bold : FontWeight.normal,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _allianceDetail(
    ThemeData theme,
    String side,
    Map<int, String> names,
    Map<int, List<ScoutedMatch>> scouted,
  ) {
    final alliance = side == 'red' ? match.red : match.blue;
    final color = allianceColor(side);
    final bd = alliance.breakdown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${side == 'red' ? 'Red' : 'Blue'} alliance',
          style: theme.textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        for (var i = 0; i < alliance.teams.length; i++)
          _TeamDetailRow(
            team: alliance.teams[i],
            name: names[alliance.teams[i]] ?? '',
            focused: alliance.teams[i] == widget.focusTeam,
            autoTower: bd != null && i < bd.autoTower.length
                ? bd.autoTower[i]
                : null,
            endTower: bd != null && i < bd.endTower.length
                ? bd.endTower[i]
                : null,
            rows: scouted[alliance.teams[i]] ?? const [],
            scoutable: match.isQual,
          ),
      ],
    );
  }
}

class _TeamChip extends StatelessWidget {
  final int team;
  final Color color;
  final bool highlighted;
  const _TeamChip({
    required this.team,
    required this.color,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      // The highlighted team is the one already being shown.
      onTap: highlighted ? null : () => openTeamDetails(context, team),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: highlighted ? color : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: color.withValues(alpha: highlighted ? 1 : 0.5),
          ),
        ),
        child: Text(
          '$team',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: highlighted ? Colors.white : theme.colorScheme.onSurface,
            fontWeight: highlighted ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TeamDetailRow extends StatelessWidget {
  final int team;
  final String name;
  final bool focused;
  final int? autoTower;
  final int? endTower;
  final List<ScoutedMatch> rows;
  final bool scoutable;

  const _TeamDetailRow({
    required this.team,
    required this.name,
    required this.focused,
    required this.autoTower,
    required this.endTower,
    required this.rows,
    required this.scoutable,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final official = [
      if (autoTower != null && autoTower! > 0) 'auto ${_tower(autoTower!)}',
      if (endTower != null && endTower! > 0) 'end ${_tower(endTower!)}',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: focused ? null : () => openTeamDetails(context, team),
            child: Row(
              children: [
                Text(
                  '$team',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: focused ? FontWeight.bold : FontWeight.w600,
                    decoration: focused ? null : TextDecoration.underline,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (official.isNotEmpty)
                  Text(
                    'Tower: ${official.join(', ')}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (rows.isEmpty)
            Text(
              scoutable ? 'Not scouted' : 'No scouting for playoff matches',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final r in rows) _ScoutedLine(row: r, showTeam: false),
        ],
      ),
    );
  }
}

/// Our scouted line for a team in a match: key numbers, flags and notes.
class _ScoutedLine extends StatelessWidget {
  final ScoutedMatch row;
  final bool showTeam;
  const _ScoutedLine({required this.row, required this.showTeam});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    String? s(String key) =>
        row.stat(key) == null ? null : _num(row.stat(key)!);
    final parts = <String>[
      if (row.stat('teleop_volleys') != null)
        '${s('teleop_volleys')} ${row.stat('teleop_volleys') == 1 ? 'volley' : 'volleys'}'
            '${row.stat('teleop_volley_accuracy') == null ? '' : ' @ ${row.stat('teleop_volley_accuracy')!.round()}%'}',
      if (row.stat('auto_fuel_accuracy') != null &&
          row.stat('auto_fuel_accuracy')! > 0)
        'Auto ${s('auto_fuel_accuracy')}% acc',
      if (row.stat('auto_tower_level') != null &&
          row.stat('auto_tower_level')! > 0)
        'Auto climb L${s('auto_tower_level')}',
      'Climb ${_tower((row.stat('endgame_tower_level') ?? 0).round())}',
      if (row.stat('auto_did_nothing') == 1) 'Did nothing in auto',
      if (row.stat('endgame_carried') == 1) 'Carried',
      if (row.hasDefense)
        'Defense: ${[if (row.activeDefense != 'N/A') 'active ${row.activeDefense}', if (row.inactiveDefense != 'N/A') 'inactive ${row.inactiveDefense}'].join(', ')}',
    ];
    final notes = [
      if (row.autoNotes.isNotEmpty) 'Auto: ${row.autoNotes}',
      if (row.matchNotes.isNotEmpty) row.matchNotes,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: parts.join('  ·  '),
                  style: theme.textTheme.bodySmall,
                ),
                if (row.scouterName.isNotEmpty)
                  TextSpan(text: '   ${row.scouterName}', style: muted),
              ],
            ),
          ),
          for (final n in notes)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                n,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Official red-vs-blue score breakdown.
class _BreakdownTable extends StatelessWidget {
  final MatchResult match;
  const _BreakdownTable({required this.match});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = match.red.breakdown!;
    final b = match.blue.breakdown!;
    final rows = <(String, String, String)>[
      ('Auto points', '${r.autoPoints}', '${b.autoPoints}'),
      ('Teleop points', '${r.teleopPoints}', '${b.teleopPoints}'),
      (
        'Hub fuel (auto / teleop / end)',
        '${r.hubAuto} / ${r.hubTeleop} / ${r.hubEndgame}',
        '${b.hubAuto} / ${b.hubTeleop} / ${b.hubEndgame}',
      ),
      ('Tower points', '${r.towerPoints}', '${b.towerPoints}'),
      (
        'Fouls (minor / major)',
        '${r.minorFouls} / ${r.majorFouls}',
        '${b.minorFouls} / ${b.majorFouls}',
      ),
      ('Foul points earned', '${r.foulPoints}', '${b.foulPoints}'),
      if (match.isQual) ('Ranking points', '${r.rp}', '${b.rp}'),
      ('Total', '${r.totalPoints}', '${b.totalPoints}'),
    ];
    String bonuses(AllianceBreakdown x) => [
      if (x.energized) 'Energized',
      if (x.supercharged) 'Supercharged',
      if (x.traversal) 'Traversal',
    ].join(', ');
    final rb = bonuses(r), bb = bonuses(b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Official breakdown', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(1.3),
              2: FlexColumnWidth(1.3),
            },
            children: [
              TableRow(
                children: [
                  const SizedBox.shrink(),
                  Text(
                    'Red',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: redAllianceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Blue',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: blueAllianceColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              for (final (label, red, blue) in rows)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(label, style: theme.textTheme.bodySmall),
                    ),
                    Text(
                      red,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      blue,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (rb.isNotEmpty || bb.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              [
                if (rb.isNotEmpty) 'Red: $rb',
                if (bb.isNotEmpty) 'Blue: $bb',
              ].join('   '),
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
