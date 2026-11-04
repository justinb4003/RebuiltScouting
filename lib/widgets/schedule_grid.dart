import 'package:flutter/material.dart';
import '../models/scout_schedule.dart';

/// Alliance colors for schedule cells, readable in light and dark themes.
/// Color is never the only cue: every cell also says "Red 1", "Blue 2", ...
class AllianceColors {
  final Color fill;
  final Color edge;
  final Color label;
  const AllianceColors(this.fill, this.edge, this.label);

  static AllianceColors of(BuildContext context, String station) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final base = isRedStation(station) ? Colors.red : Colors.blue;
    return AllianceColors(
      Color.lerp(theme.colorScheme.surface, base, dark ? 0.22 : 0.12)!,
      base.withValues(alpha: dark ? 0.7 : 0.55),
      dark ? base.shade200 : base.shade800,
    );
  }
}

/// A red row (Red 1–3) over a blue row (Blue 1–3); [cell] builds each one.
class AllianceRows extends StatelessWidget {
  final Widget Function(String station) cell;
  const AllianceRows({super.key, required this.cell});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final row in const [
            ['red1', 'red2', 'red3'],
            ['blue1', 'blue2', 'blue3'],
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(child: cell(row[i])),
                  ],
                ],
              ),
            ),
        ],
      );
}

/// One station's tinted box: "Red 1" over the scouter's name.
class StationCell extends StatelessWidget {
  final String station;
  final String? name;
  final bool isMe;
  final VoidCallback? onTap;
  // Read before the cell, e.g. "Q1–Q10".
  final String? semanticPrefix;

  const StationCell({
    super.key,
    required this.station,
    required this.name,
    this.isMe = false,
    this.onTap,
    this.semanticPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AllianceColors.of(context, station);
    final empty = (name ?? '').trim().isEmpty;
    final label = stationLabel(station);
    final shown = empty ? 'No scout' : (isMe ? '$name (you)' : name!);
    // You: a heavy outline in the theme's primary color, a person icon and
    // bold "(you)", so it never depends on color alone.
    final me = theme.colorScheme.primary;
    Widget box = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      decoration: BoxDecoration(
        color: colors.fill,
        border: Border(left: BorderSide(color: colors.edge, width: 4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: colors.label, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMe) ...[
                Icon(Icons.person, size: 18, color: me),
                const SizedBox(width: 2),
              ],
              Flexible(
                child: Text(
                  shown,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: empty
                      ? theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)
                      : theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: isMe ? FontWeight.w800 : FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (isMe) {
      box = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: me, width: 3),
          borderRadius: BorderRadius.circular(6),
        ),
        child: box,
      );
    }
    return Semantics(
      container: true,
      button: onTap != null,
      label: '${semanticPrefix == null ? '' : '$semanticPrefix, '}$label: '
          '${empty ? 'no scout' : name}${isMe ? ' (you)' : ''}',
      excludeSemantics: true,
      child: onTap == null
          ? box
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: onTap,
                child: box,
              ),
            ),
    );
  }
}

/// The schedule as one banded card per shift: who's where, each match's
/// time (actual once played, otherwise "~estimate"), and lunch / end of
/// day where they fall. A changeover line between shifts says how many
/// scouts swap.
class ScheduleGrid extends StatelessWidget {
  final List<ScheduleBlock> blocks;
  // Outlined, bold "(you)" on this person's cells.
  final String? me;
  // Only the shifts [me] is in (numbered as in the whole schedule), without
  // the changeover lines between them.
  final bool onlyMine;
  final Map<int, MatchTime> times;
  final List<ScheduleBreak> breaks;
  final void Function(ScheduleBlock block, String station)? onTapCell;

  const ScheduleGrid({
    super.key,
    required this.blocks,
    this.me,
    this.onlyMine = false,
    this.times = const {},
    this.breaks = const [],
    this.onTapCell,
  });

  /// How long a match takes, for when a shift ends (its last match's start
  /// plus this; the API's shift reminders use the same).
  static const matchLength = Duration(minutes: 8);

  /// "52 min", "1 h 4 min", "13 h" (a shift that crosses a break).
  static String _duration(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60;
    if (h == 0) return '$m min';
    return m == 0 ? '$h h' : '$h h $m min';
  }

  String _time(int match, {bool day = false}) {
    final t = times[match];
    if (t == null) return '';
    return '${t.actual ? '' : '~'}${clockTime(t.at, day: day)}';
  }

  @override
  Widget build(BuildContext context) {
    final meKey = nameKey(me ?? '');
    final children = <Widget>[];
    var shown = 0;
    bool mine(ScheduleBlock b) => b.names.values.any((n) => nameKey(n) == meKey);
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (onlyMine && !mine(b)) continue;
      if (i > 0 && !onlyMine) {
        final prev = blocks[i - 1];
        for (final br in breaks.where((br) => br.afterMatch >= prev.lastMatch && br.afterMatch < b.firstMatch)) {
          children.add(_BreakBanner(br));
        }
        children.add(_Changeover(shift: i + 1, previous: prev, next: b));
      }
      // Weekday on the first shift and whenever the day changes.
      final start = times[b.firstMatch]?.at.toLocal();
      final prevStart = i == 0 || onlyMine ? null : times[blocks[i - 1].firstMatch]?.at.toLocal();
      final newDay = start != null && (prevStart == null || prevStart.day != start.day);
      children.add(_ShiftCard(
        index: i,
        shade: (shown++).isOdd,
        count: blocks.length,
        block: b,
        meKey: meKey,
        timeRange: times[b.firstMatch] == null
            ? null
            : b.firstMatch == b.lastMatch || times[b.lastMatch] == null
                ? _time(b.firstMatch, day: newDay)
                : '${_time(b.firstMatch, day: newDay)} – ${_time(b.lastMatch, day: times[b.lastMatch]!.at.toLocal().day != start!.day)}'
                    ' (${_duration(times[b.lastMatch]!.at.difference(times[b.firstMatch]!.at) + matchLength)})',
        matchTime: _time,
        breaks: [for (final br in breaks) if (br.afterMatch >= b.firstMatch && br.afterMatch < b.lastMatch) br],
        onTapCell: onTapCell,
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

class _ShiftCard extends StatelessWidget {
  final int index;
  // Alternate cards (as shown) get a darker band.
  final bool shade;
  final int count;
  final ScheduleBlock block;
  final String meKey;
  final String? timeRange;
  final String Function(int match) matchTime;
  final List<ScheduleBreak> breaks;
  final void Function(ScheduleBlock block, String station)? onTapCell;

  const _ShiftCard({
    required this.index,
    required this.shade,
    required this.count,
    required this.block,
    required this.meKey,
    required this.timeRange,
    required this.matchTime,
    required this.breaks,
    required this.onTapCell,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    // Banding: alternate shifts get a different background.
    final band = !shade ? scheme.surfaceContainerLow : scheme.surfaceContainerHighest;
    final b = block;
    final myStation = meKey.isEmpty
        ? null
        : b.names.entries.where((e) => nameKey(e.value) == meKey).map((e) => e.key).firstOrNull;
    final matchItems = <Widget>[];
    for (var m = b.firstMatch; m <= b.lastMatch; m++) {
      final t = matchTime(m);
      matchItems.add(Semantics(
        container: true,
        label: 'Q$m${t.isEmpty ? '' : ', ${t.startsWith('~') ? 'about ${t.substring(1)}' : 'started $t'}'}',
        excludeSemantics: true,
        child: Text.rich(TextSpan(children: [
          TextSpan(text: 'Q$m ', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          TextSpan(text: t, style: muted),
        ])),
      ));
      for (final br in breaks.where((br) => br.afterMatch == m)) {
        matchItems.add(_BreakPill(br));
      }
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(color: band, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: 'Shift ${index + 1} of $count', style: theme.textTheme.titleSmall),
              TextSpan(text: '  ·  ${b.range}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.normal)),
              if (timeRange != null)
                TextSpan(
                  text: '  ·  $timeRange',
                  semanticsLabel: ', ${timeRange!.replaceAll('~', 'about ')}',
                  style: muted,
                ),
              if (myStation != null)
                TextSpan(
                  text: '  ·  You: ${stationLabel(myStation)}',
                  semanticsLabel: ', you are on ${stationLabel(myStation)}',
                  style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
                ),
            ])),
          ),
          const SizedBox(height: 6),
          AllianceRows(
            cell: (station) {
              final name = b.names[station];
              return StationCell(
                station: station,
                name: name,
                isMe: meKey.isNotEmpty && name != null && nameKey(name) == meKey,
                semanticPrefix: 'Shift ${index + 1}, ${b.range}',
                onTap: onTapCell == null ? null : () => onTapCell!(b, station),
              );
            },
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: matchItems),
        ],
      ),
    );
  }
}

/// Between two shifts: who changes out.
class _Changeover extends StatelessWidget {
  final int shift;
  final ScheduleBlock previous;
  final ScheduleBlock next;
  const _Changeover({required this.shift, required this.previous, required this.next});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final before = {for (final n in previous.names.values) nameKey(n)};
    final after = [for (final n in next.names.values) nameKey(n)];
    final stay = after.where(before.contains).length;
    final fresh = after.length - stay;
    final text = stay == 0
        ? 'Shift $shift starts · all $fresh new'
        : fresh == 0
            ? 'Shift $shift starts · same scouts'
            : 'Shift $shift starts · $fresh new, $stay stay';
    final color = theme.colorScheme.primary;
    return Semantics(
      container: true,
      label: text,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(Icons.swap_vert, size: 18, color: color),
            const SizedBox(width: 6),
            Text(text, style: theme.textTheme.labelMedium?.copyWith(color: color)),
            const SizedBox(width: 8),
            Expanded(child: Divider(color: color.withValues(alpha: 0.5), thickness: 1.5)),
          ],
        ),
      ),
    );
  }
}

IconData _breakIcon(BreakKind kind) => switch (kind) {
      BreakKind.lunch => Icons.restaurant,
      BreakKind.endOfDay => Icons.bedtime_outlined,
      BreakKind.other => Icons.pause_circle_outline,
    };

String _breakText(ScheduleBreak br) => br.kind == BreakKind.endOfDay
    ? 'End of day · next match ${clockTime(br.to, day: true)}'
    : '${br.label} · ${clockTime(br.from)} – ${clockTime(br.to)}';

/// A lunch / end-of-day banner between two shifts.
class _BreakBanner extends StatelessWidget {
  final ScheduleBreak br;
  const _BreakBanner(this.br);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      label: _breakText(br),
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(_breakIcon(br.kind), size: 20, color: scheme.onTertiaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_breakText(br),
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onTertiaryContainer, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A break that falls inside a shift, among its match times.
class _BreakPill extends StatelessWidget {
  final ScheduleBreak br;
  const _BreakPill(this.br);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      label: _breakText(br),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_breakIcon(br.kind), size: 14, color: scheme.onTertiaryContainer),
            const SizedBox(width: 4),
            Text(_breakText(br),
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onTertiaryContainer)),
          ],
        ),
      ),
    );
  }
}
