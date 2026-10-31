import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../analytics/cluster_similarity.dart';
import '../models/cluster_result.dart';
import '../providers/cluster_provider.dart';
import 'range_strip.dart';
import 'team_details.dart' show showTeamDetailsDialog;

// Same data colors as the Clusters screen: the focus team, and the muted
// context for its neighbors.
const _focusLight = Color(0xFF2A78D6);
const _focusDark = Color(0xFF3987E5);

const _rows = 6;

/// Team Details section: the team's cluster group, its nearest neighbors and
/// the dimensions that set it apart from the average robot, all from the
/// clustering in [ClusterProvider] (this device's settings, no exclusions).
class SimilarTeamsSection extends StatefulWidget {
  final int team;
  const SimilarTeamsSection({super.key, required this.team});

  @override
  State<SimilarTeamsSection> createState() => _SimilarTeamsSectionState();
}

class _SimilarTeamsSectionState extends State<SimilarTeamsSection> {
  static final Expando<ClusterSpace> _spaces = Expando();
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final p = context.watch<ClusterProvider>();
    final r = p.result;
    final team = widget.team;

    if (r == null) {
      if (p.error != null) {
        return Text(p.error!, style: TextStyle(color: theme.colorScheme.error));
      }
      if (!p.configured) {
        return const Text('Set a secret team key and event in Settings.');
      }
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final space = _spaces[r] ??= ClusterSpace(r);
    final me = r.team(team);
    if (me == null || !space.contains(team)) {
      return Text(
        r.dropped.contains(team)
            ? 'Not clustered yet: OPR dimensions are on and this team has no OPR.'
            : 'Not clustered: no scouting data for this team yet.',
      );
    }

    final group = r.group(me.group);
    final neighbors = space.neighbors(team);
    final distinctions = space.distinctions(team, [
      for (final n in neighbors) n.teamNumber,
    ]);
    final shown = _all ? distinctions : distinctions.take(_rows).toList();
    final strength = group?.strength == null || r.strengthLabel == null
        ? null
        : '${group!.strength!.toStringAsFixed(1)} ${r.strengthLabel}';
    final source = p.isCustom
        ? 'your custom settings'
        : (p.teamDefault != null
              ? 'team default settings'
              : 'built-in settings');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Group ${me.group} of ${r.k}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: [
                  '',
                  ?strength,
                  '${group?.teams.length ?? 0} teams',
                ].join('  ·  '),
              ),
            ],
          ),
          style: theme.textTheme.titleSmall,
        ),
        Text('${r.features.length} dimensions, $source', style: muted),
        const SizedBox(height: 12),
        Text('Most similar', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final n in neighbors)
              Tooltip(
                message:
                    'Closer than ${n.similarity.round()}% of team pairs at this event'
                    '${n.group == me.group ? '' : ' (Group ${n.group})'}',
                child: ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${n.teamNumber}'),
                        TextSpan(
                          text: '  ${n.similarity.round()}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  onPressed: () => showTeamDetailsDialog(context, n.teamNumber),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('What sets them apart', style: theme.textTheme.titleSmall),
        Text(
          '% = share of what makes this team unlike the average robot. Each line runs from the lowest to the highest team at the event.',
          style: muted,
        ),
        const SizedBox(height: 6),
        Builder(
          builder: (context) {
            final scheme = theme.colorScheme;
            return StripLegend([
              (
                StripLegend.dot(
                  theme.brightness == Brightness.dark
                      ? _focusDark
                      : _focusLight,
                  10,
                ),
                'This team',
              ),
              (
                StripLegend.dot(scheme.outline.withValues(alpha: 0.6), 8),
                'Most similar',
              ),
              (StripLegend.line(scheme.onSurface, 2), 'Group avg'),
              (StripLegend.line(scheme.outline, 1), 'Event avg'),
            ]);
          },
        ),
        const SizedBox(height: 4),
        for (final d in shown) _DistinctionRow(result: r, d: d),
        if (distinctions.length > _rows)
          TextButton(
            onPressed: () => setState(() => _all = !_all),
            child: Text(
              _all ? 'Show top $_rows' : 'Show all ${distinctions.length}',
            ),
          ),
      ],
    );
  }
}

/// One dimension: label, share of distinctiveness and values, over the
/// dimension's range at the event in its own units.
class _DistinctionRow extends StatelessWidget {
  final ClusterResult result;
  final Distinction d;
  const _DistinctionRow({required this.result, required this.d});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final focus = theme.brightness == Brightness.dark
        ? _focusDark
        : _focusLight;
    final label = result.labelFor(d.feature);
    final (lo, hi) = result.rangeOf(d.feature) ?? (d.mean, d.mean);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(d.share * 100).round()}%  ·  ${formatValue(d.value)} vs ${formatValue(d.mean)} avg',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          RangeStrip(
            min: lo,
            max: hi,
            eventAvg: d.mean,
            tick: d.groupMean,
            dots: [
              for (final (_, v) in d.neighborValues)
                StripDot(v, 8, scheme.outline.withValues(alpha: 0.6)),
              if (d.value != null) StripDot(d.value!, 12, focus),
            ],
          ),
        ],
      ),
    );
  }
}
