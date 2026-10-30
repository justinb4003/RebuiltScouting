import 'dart:async';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cluster_result.dart';
import '../models/pick_list.dart';
import '../providers/app_state_provider.dart';
import '../providers/pick_list_provider.dart';
import '../services/api_service.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/pick_list_team_sheet.dart';

// Chart data colors (validated reference palette): the focus series and the
// two poles of the diverging profile bars. Light / dark steps.
const _focusLight = Color(0xFF2A78D6);
const _focusDark = Color(0xFF3987E5);
const _aboveLight = Color(0xFF2A78D6);
const _aboveDark = Color(0xFF3987E5);
const _belowLight = Color(0xFFE34948);
const _belowDark = Color(0xFFE66767);

/// Profile bars run from -3σ to +3σ so they compare across groups.
const _zScale = 3.0;
const _profileRows = 5;

class ClustersScreen extends StatefulWidget {
  const ClustersScreen({super.key});

  @override
  State<ClustersScreen> createState() => _ClustersScreenState();
}

class _ClustersScreenState extends State<ClustersScreen> {
  final _api = ApiService.instance;
  late final PickListProvider _pickList;

  // Static so the controls survive leaving the screen for the app session;
  // coming back then hits ApiService's cluster cache instead of the API.
  static int _k = 4;
  static bool _scale = true;
  static bool _excludeDnp = false;
  static bool _excludeRanked = false;
  static List<String>? _features; // null = server defaults
  static String? _xAxis;
  static String? _yAxis;

  ClusterResult? _result;
  bool _loading = false;
  String? _error;
  int _requestSeq = 0;
  Timer? _debounce;
  List<int> _requestedExclude = const [];

  @override
  void initState() {
    super.initState();
    _pickList = context.read<PickListProvider>();
    _pickList.watch();
    _pickList.addListener(_onPickListChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<AppStateProvider>().settings;
      _pickList.configure(
        secretKey: settings.secretTeamKey,
        eventKey: settings.selectedEventKey ?? '',
        scouterName: settings.scouterName,
      );
      _fetch();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pickList.removeListener(_onPickListChanged);
    _pickList.unwatch();
    super.dispose();
  }

  List<int> _exclude() {
    final list = _pickList.list;
    return [
      for (final t in list.teams)
        if ((_excludeDnp && (t.dnp || t.decline)) ||
            (_excludeRanked && t.isRanked))
          t.teamNumber,
    ]..sort();
  }

  /// Re-cluster when someone changes the pick list and we're excluding by it.
  void _onPickListChanged() {
    if (!_excludeDnp && !_excludeRanked) return;
    final next = _exclude();
    if (next.length != _requestedExclude.length ||
        !next.every(_requestedExclude.contains)) {
      _scheduleFetch();
    }
  }

  void _scheduleFetch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _fetch);
  }

  Future<void> _fetch({bool refresh = false}) async {
    final settings = context.read<AppStateProvider>().settings;
    final eventKey = settings.selectedEventKey ?? '';
    final secretKey = settings.secretTeamKey.trim();
    if (eventKey.isEmpty || secretKey.isEmpty) return;
    final seq = ++_requestSeq;
    final exclude = _exclude();
    _requestedExclude = exclude;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.getClusters(
        secretKey: secretKey,
        eventKey: eventKey,
        k: _k,
        scale: _scale,
        features: _features,
        exclude: exclude,
        refresh: refresh,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _result = result;
        _loading = false;
        _pickDefaultAxes(result);
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _pickDefaultAxes(ClusterResult r) {
    bool valid(String? f) => f != null && r.feature(f) != null;
    if (!valid(_xAxis)) {
      _xAxis = r.feature('totalPoints') != null
          ? 'totalPoints'
          : (r.features.length > 1 ? r.features[1] : r.features.firstOrNull);
    }
    if (!valid(_yAxis)) {
      _yAxis = r.features.firstWhere(
        (f) => f != _xAxis,
        orElse: () => r.features.firstOrNull ?? '',
      );
      if (!valid(_yAxis)) _yAxis = null;
    }
  }

  void _set(VoidCallback change) {
    setState(change);
    _scheduleFetch();
  }

  Future<void> _editDimensions(ClusterResult r) async {
    final selected = {...r.features};
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget section(
            String title,
            Iterable<ClusterFeature> feats,
          ) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(title, style: Theme.of(ctx).textTheme.titleSmall),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final f in feats)
                    FilterChip(
                      label: Text(f.label),
                      tooltip: 'Variance ${f.variance.toStringAsFixed(2)}',
                      selected: selected.contains(f.name),
                      onSelected: (on) => setSheet(
                        () =>
                            on ? selected.add(f.name) : selected.remove(f.name),
                      ),
                    ),
                ],
              ),
            ],
          );
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            maxChildSize: 0.95,
            builder: (ctx, scroll) => Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Text(
                        'Dimensions — sorted by variance',
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                      section(
                        'Scouted',
                        r.availableFeatures.where((f) => !f.isOpr),
                      ),
                      if (r.hasOpr)
                        section(
                          'OPR',
                          r.availableFeatures.where((f) => f.isOpr),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => setSheet(
                          () => selected
                            ..clear()
                            ..addAll(
                              r.availableFeatures
                                  .where((f) => f.isDefault)
                                  .map((f) => f.name),
                            ),
                        ),
                        child: const Text('Defaults'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () => Navigator.pop(ctx, selected),
                        child: Text('Use ${selected.length}'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (picked != null) {
      // Keep the API's variance ordering.
      _set(
        () => _features = [
          for (final f in r.availableFeatures)
            if (picked.contains(f.name)) f.name,
        ],
      );
    }
  }

  Widget _controls(ClusterResult? r) {
    final theme = Theme.of(context);
    final axisItems = [
      for (final f in r?.availableFeatures ?? const <ClusterFeature>[])
        DropdownMenuItem(value: f.name, child: Text(f.label)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Groups', style: theme.textTheme.labelLarge),
              IconButton(
                tooltip: 'Fewer groups',
                icon: const Icon(Icons.remove),
                onPressed: _k > 2 ? () => _set(() => _k--) : null,
              ),
              Text('$_k', style: theme.textTheme.titleMedium),
              IconButton(
                tooltip: 'More groups',
                icon: const Icon(Icons.add),
                onPressed: _k < 8 ? () => _set(() => _k++) : null,
              ),
            ],
          ),
          FilterChip(
            label: const Text('Normalize'),
            tooltip: 'Scale each dimension so they all count equally',
            selected: _scale,
            onSelected: (v) => _set(() => _scale = v),
          ),
          FilterChip(
            label: const Text('Exclude DNP / Decline'),
            selected: _excludeDnp,
            onSelected: (v) => _set(() => _excludeDnp = v),
          ),
          FilterChip(
            label: const Text('Exclude ranked'),
            selected: _excludeRanked,
            onSelected: (v) => _set(() => _excludeRanked = v),
          ),
          if (r != null)
            OutlinedButton.icon(
              icon: const Icon(Icons.tune),
              label: Text('Dimensions (${r.features.length})'),
              onPressed: () => _editDimensions(r),
            ),
          if (axisItems.isNotEmpty) ...[
            _axisPicker(
              'X',
              _xAxis,
              axisItems,
              (v) => setState(() => _xAxis = v),
            ),
            _axisPicker(
              'Y',
              _yAxis,
              axisItems,
              (v) => setState(() => _yAxis = v),
            ),
          ],
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

  Widget _summary(ClusterResult r) {
    final theme = Theme.of(context);
    final parts = [
      '${r.teams.length} teams in ${r.k} groups',
      if (r.strengthLabel != null) 'ordered by ${r.strengthLabel}',
      if (r.excluded.isNotEmpty) '${r.excluded.length} excluded',
      if (r.dropped.isNotEmpty) '${r.dropped.length} without OPR left out',
      if (!r.hasOpr) 'OPR not available yet',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(
        parts.join(' · '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final pickList = context.watch<PickListProvider>().list;
    final settings = appState.settings;
    final configured =
        settings.secretTeamKey.trim().isNotEmpty &&
        (settings.selectedEventKey ?? '').isNotEmpty;
    final r = _result;

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
          _controls(r),
          if (r == null && _error == null)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null) message(_error!, error: true),
          if (r != null && r.groups.isEmpty)
            message('No scouting data to cluster yet.'),
          if (r != null && r.groups.isNotEmpty) ...[
            _summary(r),
            for (final g in r.groups)
              _GroupCard(
                result: r,
                group: g,
                pickList: pickList,
                xAxis: _xAxis,
                yAxis: _yAxis,
              ),
          ],
        ],
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clusters'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: configured ? () => _fetch(refresh: true) : null,
          ),
        ],
      ),
      drawer: const NavDrawer(selectedIndex: 9),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
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
  final PickList pickList;
  final String? xAxis;
  final String? yAxis;

  const _GroupCard({
    required this.result,
    required this.group,
    required this.pickList,
    required this.xAxis,
    required this.yAxis,
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _allFeatures = false;

  Widget _teamChip(int tn) {
    final entry = widget.pickList.entryFor(tn);
    final theme = Theme.of(context);
    final badge = switch (entry?.status) {
      PickStatus.ranked => '#${entry!.ranking}',
      PickStatus.dnp => 'DNP',
      PickStatus.decline => 'Decl',
      _ => null,
    };
    return Tooltip(
      message: teamLabel(context, tn),
      child: ActionChip(
        visualDensity: VisualDensity.compact,
        label: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$tn',
                style: entry?.picked == true
                    ? const TextStyle(decoration: TextDecoration.lineThrough)
                    : null,
              ),
              if (badge != null)
                TextSpan(
                  text: '  $badge',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: entry!.dnp
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        onPressed: () => showPickListTeamSheet(context, tn),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final g = widget.group;
    final theme = Theme.of(context);
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
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Compared to event average',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            for (final p in profile) _ProfileRow(result: r, entry: p),
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

  const _GroupScatter({
    required this.result,
    required this.group,
    required this.xAxis,
    required this.yAxis,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
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
          // Focus group last so it paints on top.
          ..sort(
            (a, b) => (a.group == group ? 1 : 0) - (b.group == group ? 1 : 0),
          );
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
            radius: t.group == group ? 5 : 4,
            color: t.group == group ? focus : contextColor,
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
          showLabel: labelFocus,
          getLabelFunction: (i, _) =>
              plotted[i].group == group ? '${plotted[i].teamNumber}' : '',
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

/// Diverging bar: how far this group's average sits from the event
/// average, in standard deviations.
class _ProfileRow extends StatelessWidget {
  final ClusterResult result;
  final ClusterProfileEntry entry;

  const _ProfileRow({required this.result, required this.entry});

  String _fmt(double? v) =>
      v == null ? '–' : v.toStringAsFixed(v.abs() < 1 ? 2 : 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final z = entry.z;
    final color = z >= 0
        ? (dark ? _aboveDark : _aboveLight)
        : (dark ? _belowDark : _belowLight);
    final frac = (z.abs() / _zScale).clamp(0.0, 1.0);
    final label = result.labelFor(entry.feature);
    final sign = z >= 0 ? '+' : '−';

    return Tooltip(
      message:
          '$label\nGroup avg ${_fmt(entry.mean)} · '
          'event avg ${_fmt(entry.eventMean)} · '
          '$sign${z.abs().toStringAsFixed(1)}σ',
      child: Padding(
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
                  '${_fmt(entry.mean)} vs ${_fmt(entry.eventMean)} avg',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 10,
              child: LayoutBuilder(
                builder: (context, c) {
                  final half = c.maxWidth / 2;
                  final w = math.max(half * frac, 2.0);
                  const r = Radius.circular(4);
                  return Stack(
                    children: [
                      Positioned(
                        left: half - 0.5,
                        top: 0,
                        bottom: 0,
                        width: 1,
                        child: ColoredBox(color: scheme.outlineVariant),
                      ),
                      Positioned(
                        left: z >= 0 ? half : half - w,
                        width: w,
                        top: 1,
                        bottom: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: z >= 0
                                ? const BorderRadius.only(
                                    topRight: r,
                                    bottomRight: r,
                                  )
                                : const BorderRadius.only(
                                    topLeft: r,
                                    bottomLeft: r,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
