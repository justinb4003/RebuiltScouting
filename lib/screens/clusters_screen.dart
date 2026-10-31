import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cluster_config.dart';
import '../models/cluster_result.dart';
import '../providers/app_state_provider.dart';
import '../providers/cluster_provider.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/pick_list_team_sheet.dart';
import '../widgets/range_strip.dart';

// Chart data color (validated reference palette) for the focus group.
// Light / dark steps.
const _focusLight = Color(0xFF2A78D6);
const _focusDark = Color(0xFF3987E5);
const _profileRows = 5;
// The team picked from a group's chips, marked the same everywhere it shows.
const _pickedLight = Color(0xFFD62728);
const _pickedDark = Color(0xFFF0605A);

Color _pickedColor(ThemeData theme) =>
    theme.brightness == Brightness.dark ? _pickedDark : _pickedLight;

class ClustersScreen extends StatefulWidget {
  const ClustersScreen({super.key});

  @override
  State<ClustersScreen> createState() => _ClustersScreenState();
}

class _ClustersScreenState extends State<ClustersScreen> {
  late final ClusterProvider _clusters;

  // The user's axis picks (null = the default: the two dimensions that best
  // separate the groups). Static so they survive leaving the screen.
  // Groups and dimensions live in ClusterProvider.
  static String? _xPick;
  static String? _yPick;

  @override
  void initState() {
    super.initState();
    _clusters = context.read<ClusterProvider>();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.ensureClusters(),
    );
  }

  /// Chart axes: the user's picks while they exist in this result, else the
  /// dimensions that best tell the groups apart.
  (String?, String?) _axes(ClusterResult r) {
    bool valid(String? f) => f != null && r.feature(f) != null;
    final (dx, dy) = r.defaultAxes;
    final x = valid(_xPick) ? _xPick : dx;
    var y = valid(_yPick) ? _yPick : dy;
    if (y == x && _yPick == null) y = x == dx ? dy : dx;
    return (x, y);
  }

  void _setConfig(ClusterConfig Function(ClusterConfig c) change) =>
      _clusters.setCustom(change(_clusters.resolvedConfig));

  /// Above the groups: the group count and team count, then the chart axes.
  Widget _controls(ClusterResult r, String? x, String? y) {
    final theme = Theme.of(context);
    final config = _clusters.config;
    final axisItems = [
      for (final f in r.availableFeatures)
        DropdownMenuItem(value: f.name, child: Text(f.label)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Groups:', style: theme.textTheme.labelLarge),
              const SizedBox(width: 6),
              DropdownButton<int>(
                value: config.k,
                isDense: true,
                items: [
                  for (var k = ClusterConfig.minK; k <= ClusterConfig.maxK; k++)
                    DropdownMenuItem(value: k, child: Text('$k')),
                ],
                onChanged: (k) {
                  if (k != null) _setConfig((c) => c.copyWith(k: k));
                },
              ),
              const SizedBox(width: 16),
              Text(
                '${r.teams.length} teams',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (axisItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _axisPicker(
                  'X',
                  x,
                  axisItems,
                  (v) => setState(() => _xPick = v),
                ),
                _axisPicker(
                  'Y',
                  y,
                  axisItems,
                  (v) => setState(() => _yPick = v),
                ),
                if (_xPick != null || _yPick != null)
                  TextButton(
                    onPressed: () => setState(() => _xPick = _yPick = null),
                    child: const Text('Default axes'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _axisPicker(
    String label,
    String? value,
    List<DropdownMenuItem<String>> items,
    ValueChanged<String?> onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label:', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(width: 6),
        DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          isDense: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final clusters = context.watch<ClusterProvider>();
    final settings = appState.settings;
    final configured =
        settings.secretTeamKey.trim().isNotEmpty &&
        (settings.selectedEventKey ?? '').isNotEmpty;
    final r = clusters.result;
    final error = clusters.error;
    final loading = clusters.loading;
    final (xAxis, yAxis) = r == null ? (null, null) : _axes(r);

    Widget message(String text, {bool error = false}) => Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: error
            ? TextStyle(color: Theme.of(context).colorScheme.error)
            : null,
      ),
    );

    // Controls scroll with the results so phones get the screen back.
    final body = ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (!configured)
          message('Set a secret team key and event in Settings.')
        else ...[
          if (r == null && error == null)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (error != null) message(error, error: true),
          if (r != null && r.groups.isEmpty)
            message('No scouting data to cluster yet.'),
          if (r != null && r.groups.isNotEmpty) ...[
            _controls(r, xAxis, yAxis),
            for (final g in r.groups)
              _GroupCard(result: r, group: g, xAxis: xAxis, yAxis: yAxis),
          ],
        ],
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clusters'),
        actions: [
          IconButton(
            tooltip: 'Dimensions',
            icon: const Icon(Icons.tune),
            onPressed: configured
                ? () => Navigator.of(context).pushNamed('/dimensions')
                : null,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: configured ? () => _clusters.fetch(refresh: true) : null,
          ),
        ],
      ),
      drawer: const NavDrawer(selectedIndex: 9),
      body: Column(
        children: [
          if (loading) const LinearProgressIndicator(),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatefulWidget {
  final ClusterResult result;
  final ClusterGroup group;
  final String? xAxis;
  final String? yAxis;

  const _GroupCard({
    required this.result,
    required this.group,
    required this.xAxis,
    required this.yAxis,
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _allFeatures = false;
  int? _picked;

  Widget _teamChip(int tn) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final label = teamLabel(context, tn);
    final name = label.contains(' · ')
        ? label.split(' · ').skip(1).join(' · ')
        : '';
    final picked = _picked == tn;
    final red = _pickedColor(theme);
    return Tooltip(
      message: label,
      child: ChoiceChip(
        visualDensity: VisualDensity.compact,
        showCheckmark: false,
        selected: picked,
        selectedColor: red.withValues(alpha: 0.15),
        side: picked ? BorderSide(color: red, width: 1.5) : null,
        avatar: picked ? Icon(Icons.circle, size: 10, color: red) : null,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$tn'),
            if (name.isNotEmpty) ...[
              const SizedBox(width: 6),
              // Enough of the name to tell teams apart; the tooltip has it all.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(
                  name,
                  style: muted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        onSelected: (on) => setState(() => _picked = on ? tn : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final g = widget.group;
    final theme = Theme.of(context);
    if (!g.teams.contains(_picked)) _picked = null;
    final profile = _allFeatures
        ? g.profile
        : g.profile.take(_profileRows).toList();
    final strength = g.strength == null || r.strengthLabel == null
        ? ''
        : '${g.strength!.toStringAsFixed(1)} ${r.strengthLabel} · ';

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Group ${g.group}', style: theme.textTheme.titleMedium),
            Text(
              '$strength${g.teams.length} teams',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final tn in g.teams) _teamChip(tn)],
            ),
            if (widget.xAxis != null && widget.yAxis != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: _GroupScatter(
                  result: r,
                  group: g.group,
                  xAxis: widget.xAxis!,
                  yAxis: widget.yAxis!,
                  picked: _picked,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Compared to event average',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Builder(
              builder: (context) {
                final focus = theme.brightness == Brightness.dark
                    ? _focusDark
                    : _focusLight;
                return StripLegend([
                  (StripLegend.dot(focus, 10), 'Group avg'),
                  (
                    StripLegend.band(focus.withValues(alpha: 0.22)),
                    'Group range',
                  ),
                  (StripLegend.line(theme.colorScheme.outline, 1), 'Event avg'),
                  if (_picked != null)
                    (StripLegend.dot(_pickedColor(theme), 10), '$_picked'),
                ]);
              },
            ),
            const SizedBox(height: 4),
            for (final p in profile)
              _ProfileRow(result: r, entry: p, group: g.group, picked: _picked),
            if (g.profile.length > _profileRows)
              TextButton(
                onPressed: () => setState(() => _allFeatures = !_allFeatures),
                child: Text(
                  _allFeatures
                      ? 'Show top $_profileRows'
                      : 'Show all ${g.profile.length}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One group in focus (labelled, blue) over every other team in gray.
/// Every card shares the same axes so groups compare at a glance.
class _GroupScatter extends StatelessWidget {
  final ClusterResult result;
  final int group;
  final String xAxis;
  final String yAxis;
  final int? picked;

  const _GroupScatter({
    required this.result,
    required this.group,
    required this.xAxis,
    required this.yAxis,
    this.picked,
  });

  static (double, double) _range(Iterable<double> values) {
    if (values.isEmpty) return (0, 1);
    var lo = values.reduce(math.min);
    var hi = values.reduce(math.max);
    if (hi - lo < 1e-9) {
      lo -= 1;
      hi += 1;
    }
    final pad = (hi - lo) * 0.08;
    return (lo - pad, hi + pad);
  }

  /// A 1/2/5 × 10^n step giving about [target] ticks across [span].
  static double _niceStep(double span, {int target = 5}) {
    final raw = span / target;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final norm = raw / mag;
    final nice = norm < 1.5
        ? 1
        : norm < 3.5
        ? 2
        : norm < 7.5
        ? 5
        : 10;
    return nice * mag;
  }

  int _layer(ClusterTeam t) =>
      t.teamNumber == picked ? 2 : (t.group == group ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final red = _pickedColor(theme);
    final focus = dark ? _focusDark : _focusLight;
    final contextColor = scheme.outline.withValues(alpha: 0.45);
    final surface = theme.cardTheme.color ?? scheme.surfaceContainerLow;
    final grid = scheme.outlineVariant.withValues(alpha: 0.6);
    final axisText = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final plotted =
        result.teams
            .where((t) => t.values[xAxis] != null && t.values[yAxis] != null)
            .toList()
          // Focus group, then the picked team, last so they paint on top.
          ..sort((a, b) => _layer(a) - _layer(b));
    final (minX, maxX) = _range(plotted.map((t) => t.values[xAxis]!));
    final (minY, maxY) = _range(plotted.map((t) => t.values[yAxis]!));
    final xStep = _niceStep(maxX - minX);
    final yStep = _niceStep(maxY - minY, target: 4);
    // Big groups would just be a pile of overlapping numbers; the chips and
    // tooltips name those teams instead.
    final labelFocus = plotted.where((t) => t.group == group).length <= 8;

    final spots = [
      for (final t in plotted)
        ScatterSpot(
          t.values[xAxis]!,
          t.values[yAxis]!,
          dotPainter: FlDotCirclePainter(
            radius: t.teamNumber == picked ? 7 : (t.group == group ? 5 : 4),
            color: t.teamNumber == picked
                ? red
                : (t.group == group ? focus : contextColor),
            strokeWidth: 2,
            strokeColor: surface,
          ),
        ),
    ];

    String fmt(double v) =>
        v.abs() >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

    GetTitleWidgetFunction ticks(double step) =>
        (v, meta) => SideTitleWidget(
          meta: meta,
          child: Text(v.toStringAsFixed(step >= 1 ? 0 : 1), style: axisText),
        );

    return ScatterChart(
      ScatterChartData(
        scatterSpots: spots,
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          horizontalInterval: yStep,
          verticalInterval: xStep,
          getDrawingHorizontalLine: (_) => FlLine(color: grid, strokeWidth: 1),
          getDrawingVerticalLine: (_) => FlLine(color: grid, strokeWidth: 1),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: scheme.outlineVariant),
            bottom: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            axisNameWidget: Text(result.labelFor(xAxis), style: axisText),
            axisNameSize: 18,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: xStep,
              minIncluded: false,
              maxIncluded: false,
              getTitlesWidget: ticks(xStep),
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Text(result.labelFor(yAxis), style: axisText),
            axisNameSize: 18,
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: yStep,
              minIncluded: false,
              maxIncluded: false,
              getTitlesWidget: ticks(yStep),
            ),
          ),
        ),
        scatterLabelSettings: ScatterLabelSettings(
          showLabel: labelFocus || picked != null,
          getLabelFunction: (i, _) =>
              plotted[i].teamNumber == picked ||
                  (labelFocus && plotted[i].group == group)
              ? '${plotted[i].teamNumber}'
              : '',
          getLabelTextStyleFunction: (_, _) =>
              theme.textTheme.labelSmall?.copyWith(color: scheme.onSurface),
        ),
        scatterTouchData: ScatterTouchData(
          touchSpotThreshold: 8,
          touchTooltipData: ScatterTouchTooltipData(
            maxContentWidth: 220,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItems: (spot) {
              // Teams can land on the same point; list them all.
              final here = plotted
                  .where(
                    (t) =>
                        t.values[xAxis] == spot.x && t.values[yAxis] == spot.y,
                  )
                  .map(
                    (t) =>
                        '${teamLabel(context, t.teamNumber)} '
                        '(Group ${t.group})',
                  );
              if (here.isEmpty) return null;
              return ScatterTooltipItem(
                '${here.join('\n')}\n'
                '${result.labelFor(xAxis)}: ${fmt(spot.x)}\n'
                '${result.labelFor(yAxis)}: ${fmt(spot.y)}',
                textStyle: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onInverseSurface,
                ),
                textAlign: TextAlign.left,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One dimension in its own units across the event's range: the group's
/// spread (band), its average (dot) and the event average (line).
class _ProfileRow extends StatelessWidget {
  final ClusterResult result;
  final ClusterProfileEntry entry;
  final int group;
  final int? picked;

  const _ProfileRow({
    required this.result,
    required this.entry,
    required this.group,
    this.picked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final focus = theme.brightness == Brightness.dark
        ? _focusDark
        : _focusLight;
    final label = result.labelFor(entry.feature);
    final eventAvg = entry.eventMean ?? 0;
    final (lo, hi) = result.rangeOf(entry.feature) ?? (eventAvg, eventAvg);
    final groupRange = result.rangeOf(entry.feature, group: group);
    final pickedValue = picked == null
        ? null
        : result.team(picked!)?.values[entry.feature];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
                [
                  if (pickedValue != null)
                    '$picked ${formatValue(pickedValue)}',
                  '${formatValue(entry.mean)} vs ${formatValue(entry.eventMean)} avg',
                ].join('  ·  '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          RangeStrip(
            min: lo,
            max: hi,
            eventAvg: eventAvg,
            band: groupRange,
            bandColor: focus.withValues(alpha: 0.22),
            dots: [
              if (entry.mean != null) StripDot(entry.mean!, 11, focus),
              if (pickedValue != null)
                StripDot(pickedValue, 11, _pickedColor(theme)),
            ],
          ),
        ],
      ),
    );
  }
}
