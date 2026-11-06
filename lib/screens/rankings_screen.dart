import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/rankings.dart';
import '../providers/app_state_provider.dart';
import '../providers/rankings_provider.dart';
import '../widgets/nav_drawer.dart';
import '../widgets/team_details.dart';

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
/// The header row stays put while the rows scroll; its sideways scroll is
/// kept in step with the rows'.
class _RankingsTable extends StatefulWidget {
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

  @override
  State<_RankingsTable> createState() => _RankingsTableState();
}

class _RankingsTableState extends State<_RankingsTable> {
  final _headX = ScrollController();
  final _bodyX = ScrollController();
  final _bodyY = ScrollController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _headX.addListener(() => _follow(_headX, _bodyX));
    _bodyX.addListener(() => _follow(_bodyX, _headX));
  }

  void _follow(ScrollController from, ScrollController to) {
    if (_syncing || !to.hasClients || to.offset == from.offset) return;
    _syncing = true;
    to.jumpTo(from.offset.clamp(0.0, to.position.maxScrollExtent));
    _syncing = false;
  }

  @override
  void dispose() {
    _headX.dispose();
    _bodyX.dispose();
    _bodyY.dispose();
    super.dispose();
  }

  List<RankingRow> get rows => widget.rows;
  List<RankingColumn> get columns => widget.columns;
  RankingColumn get active => widget.active;
  bool get ascending => widget.ascending;
  Map<int, String> get names => widget.names;
  ValueChanged<RankingColumn> get onSort => widget.onSort;

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
    Widget? trailing,
  }) {
    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontWeight: bold ? FontWeight.w600 : null,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    return Container(
      width: width,
      height: _rowHeight,
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: trailing == null
          ? label
          : Row(children: [Flexible(child: label), trailing]),
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

        void open(RankingRow r) => showTeamDetailsDialog(context, r.teamNumber);

        Widget rowBg(RankingRow r, int i, Widget child) => Material(
          color: i.isOdd
              ? theme.colorScheme.surfaceContainerLow
              : Colors.transparent,
          child: InkWell(onTap: () => open(r), child: child),
        );

        Widget pinnedRow(int i) => rowBg(
          rows[i],
          i,
          Row(
            children: [
              _cell(context, rows[i], _rankWidth, '${rows[i].rank}'),
              _cell(context, rows[i], _teamWidth, '${rows[i].teamNumber}',
                  bold: true),
            ],
          ),
        );

        Widget scrollingRow(int i) => rowBg(
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
                  align: c.isText ? Alignment.centerLeft : Alignment.centerRight,
                  trailing: c.kind == RankingColumnKind.name
                      ? TeamInfoButton(rows[i].teamNumber)
                      : null,
                ),
            ],
          ),
        );

        final divider = BoxDecoration(
          border: Border(right: BorderSide(color: theme.colorScheme.outlineVariant)),
        );

        final header = Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Container(
                decoration: divider,
                child: Row(
                  children: [
                    _header(context, columns[0], _rankWidth),
                    _header(context, columns[1], _teamWidth),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _headX,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final c in scrolling)
                        _header(
                          context,
                          c,
                          w(c),
                          align: c.isText ? Alignment.centerLeft : Alignment.centerRight,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        final body = SingleChildScrollView(
          controller: _bodyY,
          padding: const EdgeInsets.only(bottom: 32),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: divider,
                child: Column(children: [for (var i = 0; i < rows.length; i++) pinnedRow(i)]),
              ),
              Expanded(
                child: Scrollbar(
                  controller: _bodyX,
                  child: SingleChildScrollView(
                    controller: _bodyX,
                    scrollDirection: Axis.horizontal,
                    child: Column(children: [for (var i = 0; i < rows.length; i++) scrollingRow(i)]),
                  ),
                ),
              ),
            ],
          ),
        );

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            // Mouse drags scroll too (web defaults to touch only).
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context)
                  .copyWith(dragDevices: {...PointerDeviceKind.values}),
              child: Column(
                children: [header, Expanded(child: body)],
              ),
            ),
          ),
        );
      },
    );
  }
}
