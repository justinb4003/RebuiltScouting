import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../models/tba_event.dart';
import '../services/api_service.dart';

/// Pick an event: a season, a "My events" dropdown with only [teamNumber]'s
/// events that season, and a search over every event that season by name,
/// code or city. A search starting with a year ("2027mimus", "2027 mimus")
/// switches the season to it. Returns the picked event, or null on Cancel.
Future<TbaEvent?> showEventPickerDialog(
  BuildContext context, {
  required int initialYear,
  required List<TbaEvent> initialEvents,
  int? teamNumber,
  String? selectedKey,
}) {
  return showDialog<TbaEvent>(
    context: context,
    builder: (_) => _EventPickerDialog(
      initialYear: initialYear,
      initialEvents: initialEvents,
      teamNumber: teamNumber,
      selectedKey: selectedKey,
    ),
  );
}

class _EventPickerDialog extends StatefulWidget {
  const _EventPickerDialog({
    required this.initialYear,
    required this.initialEvents,
    this.teamNumber,
    this.selectedKey,
  });

  final int initialYear;
  final List<TbaEvent> initialEvents;
  final int? teamNumber;
  final String? selectedKey;

  @override
  State<_EventPickerDialog> createState() => _EventPickerDialogState();
}

class _EventPickerDialogState extends State<_EventPickerDialog> {
  // Fetched once per app session.
  static final Map<int, List<TbaEvent>> _eventsByYear = {};
  static final Map<String, Set<String>> _teamEventKeys = {}; // 'team|year'

  static const _firstSeason = 1992;
  static final _leadingYear = RegExp(r'^(\d{4})\s*(.*)$');

  final _search = TextEditingController();
  late int _year;
  bool _loadingEvents = false;
  bool _loadingTeam = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    final seeded = widget.initialEvents
        .where((e) => e.key.startsWith('$_year'))
        .toList();
    if (seeded.isNotEmpty) _eventsByYear.putIfAbsent(_year, () => seeded);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setYear(int year) {
    if (year == _year) return;
    setState(() {
      _year = year;
      _error = null;
    });
    _load();
  }

  void _load() {
    final year = _year;
    if (!_eventsByYear.containsKey(year)) {
      setState(() => _loadingEvents = true);
      ApiService.instance.getEvents(year).then((events) {
        _eventsByYear[year] = events;
      }).catchError((Object e) {
        debugPrint('Loading $year events failed: $e');
        if (year == _year) _error = 'Could not load $year events';
      }).whenComplete(() {
        if (mounted && year == _year) setState(() => _loadingEvents = false);
      });
    }
    final team = widget.teamNumber;
    final combo = '$team|$year';
    if (team != null && !_teamEventKeys.containsKey(combo)) {
      setState(() => _loadingTeam = true);
      ApiService.instance.getTeamEventKeys(team, year).then((keys) {
        _teamEventKeys[combo] = keys;
      }).catchError((Object e) {
        debugPrint('Loading team events failed: $e');
      }).whenComplete(() {
        if (mounted && year == _year) setState(() => _loadingTeam = false);
      });
    }
  }

  List<TbaEvent> get _events => _eventsByYear[_year] ?? const [];

  List<TbaEvent> get _myEvents {
    final keys = _teamEventKeys['${widget.teamNumber}|$_year'];
    if (keys == null) return const [];
    return _events.where((e) => keys.contains(e.key)).toList()
      ..sort((a, b) => (a.startDate ?? '').compareTo(b.startDate ?? ''));
  }

  /// The search text without a leading year.
  String get _query {
    final q = _search.text.trim().toLowerCase();
    final m = _leadingYear.firstMatch(q);
    return m == null ? q : m.group(2)!.trim();
  }

  void _onSearchChanged(String text) {
    final m = _leadingYear.firstMatch(text.trim());
    if (m != null) {
      final y = int.parse(m.group(1)!);
      if (y >= _firstSeason && y <= currentSeason() + 1) _setYear(y);
    }
    setState(() {});
  }

  List<TbaEvent> get _results {
    final q = _query;
    if (q.isEmpty) return const [];
    final hits = _events.where((e) {
      return e.name.toLowerCase().contains(q) ||
          e.key.toLowerCase().contains(q) ||
          (e.city ?? '').toLowerCase().contains(q);
    }).toList();
    // An exact code first, then by name.
    hits.sort((a, b) {
      final ea = a.key == '$_year$q' ? 0 : 1;
      final eb = b.key == '$_year$q' ? 0 : 1;
      if (ea != eb) return ea - eb;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return hits;
  }

  String _subtitle(TbaEvent e) =>
      '${e.key}${e.city != null ? ' — ${e.city}, ${e.stateProv ?? ''}' : ''}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seasons = <int>{
      for (var i = 0; i < 6; i++) currentSeason() - i,
      _year,
    }.toList()
      ..sort((a, b) => b - a);
    final mine = _myEvents;
    final results = _results;
    final team = widget.teamNumber;

    Widget myEvents;
    if (team == null) {
      myEvents = const Text(
          'Enter your team number in Settings to list your events here.');
    } else if (_loadingTeam || _loadingEvents) {
      myEvents = const LinearProgressIndicator();
    } else if (mine.isEmpty) {
      myEvents = Text('Team $team has no events in $_year.');
    } else {
      myEvents = DropdownButtonFormField<String?>(
        key: ValueKey('mine-$_year'),
        initialValue: mine.any((e) => e.key == widget.selectedKey)
            ? widget.selectedKey
            : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: "Team $team's events",
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Select an event'),
          ),
          for (final e in mine)
            DropdownMenuItem(
              value: e.key,
              child: Text('${e.name} (${e.key})',
                  overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (key) {
          if (key == null) return;
          Navigator.of(context).pop(mine.firstWhere((e) => e.key == key));
        },
      );
    }

    return AlertDialog(
      title: const Text('Choose event'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 160,
                child: DropdownButtonFormField<int>(
                  key: ValueKey('season-$_year'),
                  initialValue: _year,
                  decoration: const InputDecoration(
                    labelText: 'Season',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final y in seasons)
                      DropdownMenuItem(value: y, child: Text('$y')),
                  ],
                  onChanged: (y) {
                    if (y != null) _setYear(y);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            myEvents,
            const SizedBox(height: 24),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Search all events',
                helperText: 'Name, city or event code, e.g. 2027mimus',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: (_) {
                if (results.isNotEmpty &&
                    (results.length == 1 ||
                        results.first.key == '$_year$_query')) {
                  Navigator.of(context).pop(results.first);
                }
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            if (_query.isNotEmpty) ...[
              const SizedBox(height: 8),
              if (_loadingEvents)
                const LinearProgressIndicator()
              else if (results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('No $_year events match "$_query".'),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final e in results)
                        ListTile(
                          title: Text(e.name),
                          subtitle: Text(_subtitle(e)),
                          selected: e.key == widget.selectedKey,
                          onTap: () => Navigator.of(context).pop(e),
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
