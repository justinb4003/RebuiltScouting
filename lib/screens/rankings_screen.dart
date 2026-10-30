import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/rankings.dart';
import '../providers/app_state_provider.dart';
import '../providers/rankings_provider.dart';
import '../widgets/nav_drawer.dart';

// Chart data color (validated reference palette), light / dark steps.
const _focusLight = Color(0xFF2A78D6);
const _focusDark = Color(0xFF3987E5);

const _rowHeight = 44.0;
const _headerHeight = 56.0;
const _rankWidth = 68.0;
const _teamWidth = 64.0;

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  // Kept across visits within a session.
  static RankingColumnKind _sortKind = RankingColumnKind.rank;
  static int _sortIndex = 0;
  static bool _ascending = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = context.read<AppStateProvider>().settings.selectedEventKey;
      if (key != null) context.read<RankingsProvider>().load(key);
    });
  }

  void _onSort(RankingColumn c) => setState(() {
    if (_sortKind == c.kind && _sortIndex == c.index) {
      _ascending = !_ascending;
    } else {
      _sortKind = c.kind;
      _sortIndex = c.index;
      _ascending = c.defaultAscending;
    }
  });

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    final rel = d.inMinutes < 1
        ? 'just now'
        : d.inHours < 1
        ? '${d.inMinutes} min ago'
        : d.inDays < 1
        ? '${d.inHours} h ago'
        : '${d.inDays} d ago';
    final l = t.toLocal();
    final hm =
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
    return '$rel ($hm)';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final rankings = context.watch<RankingsProvider>();
    final eventKey = appState.settings.selectedEventKey ?? '';
    final data = rankings.data;
    final theme = Theme.of(context);

    Widget message(String text, {bool error = false}) => Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: error ? TextStyle(color: theme.colorScheme.error) : null,
      ),
    );

    final Widget body;
    if (eventKey.isEmpty) {
      body = Center(child: message('Select an event in Settings.'));
    } else if (data == null) {
      body = rankings.error != null
          ? Center(child: message(rankings.error!, error: true))
          : const Center(child: CircularProgressIndicator());
    } else if (data.isEmpty) {
      body = Center(
        child: message(
          'No rankings posted yet for this event.\n${_status(data, rankings)}',
        ),
      );
    } else {
      final names = {for (final t in appState.teams) t.teamNumber: t.nickname};
      final columns = data.columns;
      final active = columns.firstWhere(
        (c) => c.kind == _sortKind && c.index == _sortIndex,
        orElse: () => columns.first,
      );
      final rows = sortRankings(
        data.rows,
        active,
        _ascending,
        nameOf: (n) => names[n] ?? '',
      );
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _status(data, rankings),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: rankings.error != null
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: _RankingsTable(
              data: data,
              rows: rows,
              columns: columns,
              active: active,
              ascending: _ascending,
              names: names,
              onSort: _onSort,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rankings'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: eventKey.isEmpty || rankings.loading
                ? null
                : () => rankings.refresh(),
          ),
        ],
      ),
      drawer: const NavDrawer(selectedIndex: 10),
      body: Column(
        children: [
          if (rankings.loading) const LinearProgressIndicator(),
          Expanded(child: body),
        ],
      ),
    );
  }

  String _status(RankingsData data, RankingsProvider p) {
    final parts = ['Updated ${_ago(data.fetchedAt)}'];
    if (p.error != null) parts.add(p.error!);
    return parts.join(' · ');
  }
}

/// Rank + Team stay pinned on the left; everything else scrolls sideways.
/// Header and rows share one vertical scroll so the two panes stay aligned.
class _RankingsTable extends StatelessWidget {
  final RankingsData data;
  final List<RankingRow> rows;
  final List<RankingColumn> columns;
  final RankingColumn active;
  final bool ascending;
  final Map<int, String> names;
  final ValueChanged<RankingColumn> onSort;

  const _RankingsTable({
    required this.data,
    required this.rows,
    required this.columns,
    required this.active,
    required this.ascending,
    required this.names,
    required this.onSort,
  });

  static double _width(RankingColumn c) => switch (c.kind) {
    RankingColumnKind.name => 190,
    RankingColumnKind.record => 84,
    RankingColumnKind.played => 76,
    RankingColumnKind.dq => 56,
    _ => 104,
  };

  bool _isActive(RankingColumn c) =>
      c.kind == active.kind && c.index == active.index;

  Widget _header(
    BuildContext context,
    RankingColumn c,
    double width, {
    Alignment align = Alignment.centerRight,
  }) {
    final theme = Theme.of(context);
    final on = _isActive(c);
    return InkWell(
      onTap: () => onSort(c),
      child: Container(
        width: width,
        height: _headerHeight,
        alignment: align,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (on)
              Icon(
                ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: theme.colorScheme.primary,
              ),
            Flexible(
              child: Text(
                c.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: align == Alignment.centerLeft
                    ? TextAlign.left
                    : TextAlign.right,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: on ? theme.colorScheme.primary : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    RankingRow r,
    double width,
    String text, {
    Alignment align = Alignment.centerRight,
    bool bold = false,
  }) {
    return Container(
      width: width,
      height: _rowHeight,
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: bold ? FontWeight.w600 : null,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  String _text(RankingColumn c, RankingRow r) => switch (c.kind) {
    RankingColumnKind.rank => '${r.rank}',
    RankingColumnKind.team => '${r.teamNumber}',
    RankingColumnKind.name => names[r.teamNumber] ?? '',
    RankingColumnKind.record => r.record,
    RankingColumnKind.played => '${r.matchesPlayed}',
    RankingColumnKind.dq => '${r.dq}',
    _ => () {
      final v = c.valueOf(r);
      return v == null ? '–' : v.toStringAsFixed(c.precision);
    }(),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scrolling = columns.sublist(2);
    final naturalWidth = scrolling.fold<double>(0, (s, c) => s + _width(c));

    return LayoutBuilder(
      builder: (context, box) {
        final maxW = box.maxWidth > 1100 ? 1100.0 : box.maxWidth;
        // On wide screens give the spare width to the Name column.
        final extra = (maxW - _rankWidth - _teamWidth - naturalWidth).clamp(
          0.0,
          double.infinity,
        );
        double w(RankingColumn c) =>
            _width(c) + (c.kind == RankingColumnKind.name ? extra : 0);

        void open(RankingRow r) => Navigator.pushNamed(
          context,
          '/team-details',
          arguments: r.teamNumber,
        );

        Widget rowBg(RankingRow r, int i, Widget child) => Material(
          color: i.isOdd
              ? theme.colorScheme.surfaceContainerLow
              : Colors.transparent,
          child: InkWell(onTap: () => open(r), child: child),
        );

        final pinned = Column(
          children: [
            Row(
              children: [
                _header(context, columns[0], _rankWidth),
                _header(context, columns[1], _teamWidth),
              ],
            ),
            for (var i = 0; i < rows.length; i++)
              rowBg(
                rows[i],
                i,
                Row(
                  children: [
                    _cell(context, rows[i], _rankWidth, '${rows[i].rank}'),
                    _cell(
                      context,
                      rows[i],
                      _teamWidth,
                      '${rows[i].teamNumber}',
                      bold: true,
                    ),
                  ],
                ),
              ),
          ],
        );

        final scrollPane = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            children: [
              Row(
                children: [
                  for (final c in scrolling)
                    _header(
                      context,
                      c,
                      w(c),
                      align: c.isText
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                    ),
                ],
              ),
              for (var i = 0; i < rows.length; i++)
                rowBg(
                  rows[i],
                  i,
                  Row(
                    children: [
                      for (final c in scrolling)
                        _cell(
                          context,
                          rows[i],
                          w(c),
                          _text(c, rows[i]),
                          align: c.isText
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                if (data.sortOrderInfo.isNotEmpty && rows.length > 1)
                  _ScoreChart(data: data, names: names),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      child: pinned,
                    ),
                    Expanded(child: scrollPane),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Primary ranking score (first sort-order column) by official rank.
class _ScoreChart extends StatelessWidget {
  final RankingsData data;
  final Map<int, String> names;

  const _ScoreChart({required this.data, required this.names});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final info = data.sortOrderInfo.first;
    final byRank = [
      for (final r in data.rows)
        if (r.sortOrders.isNotEmpty && r.sortOrders.first != null) r,
    ]..sort((a, b) => a.rank.compareTo(b.rank));
    if (byRank.length < 2) return const SizedBox.shrink();
    final maxY = byRank
        .map((r) => r.sortOrders.first!)
        .reduce((a, b) => a > b ? a : b);
    // Round the axis up to a tidy step so ticks read 0, 1, 2 rather than 1.2.
    final step = _niceStep(maxY <= 0 ? 1.0 : maxY / 4);
    final top = step * (maxY / step).ceil().clamp(1, 1000);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${info.name} by rank', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                maxY: top,
                alignment: BarChartAlignment.spaceBetween,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: step,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: step,
                      getTitlesWidget: (v, meta) => v == meta.max
                          ? const SizedBox.shrink()
                          : Text(
                              v.toStringAsFixed(
                                info.precision > 0 && top < 10 ? 1 : 0,
                              ),
                              style: labelStyle,
                            ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (v, _) {
                        final rank = byRank[v.toInt()].rank;
                        // Label roughly every fifth bar.
                        final every = byRank.length > 30 ? 10 : 5;
                        return rank == 1 || rank % every == 0
                            ? Text('$rank', style: labelStyle)
                            : const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) => scheme.inverseSurface,
                    getTooltipItem: (group, _, rod, _) {
                      final r = byRank[group.x];
                      final nick = names[r.teamNumber];
                      return BarTooltipItem(
                        'Rank ${r.rank}: ${r.teamNumber}'
                        '${nick == null || nick.isEmpty ? '' : ' · $nick'}\n'
                        '${info.name}: ${info.format(rod.toY)}',
                        theme.textTheme.bodySmall!.copyWith(
                          color: scheme.onInverseSurface,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < byRank.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: byRank[i].sortOrders.first!,
                          color: dark ? _focusDark : _focusLight,
                          width: byRank.length > 40 ? 4 : 6,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Smallest 1/2/5 x 10^n step at or above [raw].
double _niceStep(double raw) {
  var mag = 1.0;
  while (mag > raw) {
    mag /= 10;
  }
  while (mag * 10 <= raw) {
    mag *= 10;
  }
  for (final m in [1, 2, 5, 10]) {
    if (mag * m >= raw) return mag * m;
  }
  return mag * 10;
}
