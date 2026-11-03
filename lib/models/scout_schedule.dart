// Match-scouting schedule: who scouts which robot station, for which
// qualification matches. See the API's scout_schedule.py.

const scheduleStations = ['red1', 'red2', 'red3', 'blue1', 'blue2', 'blue3'];

/// "red1" -> "Red 1"
String stationLabel(String station) =>
    '${station[0].toUpperCase()}${station.substring(1, station.length - 1)} ${station[station.length - 1]}';

/// Case- and spacing-insensitive name, the same as the API's voter_key.
String nameKey(String name) => name
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

String matchRange(int first, int last) =>
    first == last ? 'Q$first' : 'Q$first–Q$last';

class Shift {
  final String scouterName;
  final String station;
  final int firstMatch;
  final int lastMatch;

  const Shift({
    required this.scouterName,
    required this.station,
    required this.firstMatch,
    required this.lastMatch,
  });

  Shift copyWith({String? scouterName, int? firstMatch, int? lastMatch}) => Shift(
        scouterName: scouterName ?? this.scouterName,
        station: station,
        firstMatch: firstMatch ?? this.firstMatch,
        lastMatch: lastMatch ?? this.lastMatch,
      );

  String get range => matchRange(firstMatch, lastMatch);

  Map<String, dynamic> toJson() => {
        'scouter_name': scouterName,
        'station': station,
        'first_match': firstMatch,
        'last_match': lastMatch,
      };

  factory Shift.fromJson(Map<String, dynamic> j) => Shift(
        scouterName: (j['scouter_name'] ?? '').toString(),
        station: (j['station'] ?? '').toString(),
        firstMatch: (j['first_match'] as num).toInt(),
        lastMatch: (j['last_match'] as num).toInt(),
      );
}

class ScoutSchedule {
  final String publishedBy;
  final DateTime? publishedAt;
  final List<Shift> shifts;

  const ScoutSchedule({
    required this.publishedBy,
    required this.publishedAt,
    required this.shifts,
  });

  Map<String, dynamic> toJson() => {
        'published_by': publishedBy,
        'published_at': publishedAt?.toUtc().toIso8601String(),
        'shifts': [for (final s in shifts) s.toJson()],
      };

  factory ScoutSchedule.fromJson(Map<String, dynamic> j) => ScoutSchedule(
        publishedBy: (j['published_by'] ?? '').toString(),
        publishedAt: DateTime.tryParse((j['published_at'] ?? '').toString()),
        shifts: [
          for (final s in (j['shifts'] as List? ?? const []))
            Shift.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
      );

  /// The shifts whose scouter matches [name] (spacing/case-insensitive),
  /// earliest first.
  List<Shift> shiftsFor(String name) {
    final key = nameKey(name);
    if (key.isEmpty) return const [];
    return [
      for (final s in shifts)
        if (nameKey(s.scouterName) == key) s,
    ]..sort((a, b) => a.firstMatch.compareTo(b.firstMatch));
  }
}

class ScouterInfo {
  final String name;
  final DateTime? firstSeen;
  final DateTime? lastSeen;

  const ScouterInfo({required this.name, this.firstSeen, this.lastSeen});

  Map<String, dynamic> toJson() => {
        'scouter_name': name,
        'first_seen': firstSeen?.toUtc().toIso8601String(),
        'last_seen': lastSeen?.toUtc().toIso8601String(),
      };

  factory ScouterInfo.fromJson(Map<String, dynamic> j) => ScouterInfo(
        name: (j['scouter_name'] ?? '').toString(),
        firstSeen: DateTime.tryParse((j['first_seen'] ?? '').toString()),
        lastSeen: DateTime.tryParse((j['last_seen'] ?? '').toString()),
      );
}

/// Round-robin [names] across the six stations in blocks of [blockLength]
/// matches covering Q1..Q[qualCount]. With fewer than six names only that
/// many stations are filled (each station keeps one scouter), so nobody is
/// ever on two stations at once.
List<Shift> fillEvenly(List<String> names, int qualCount, int blockLength) {
  if (names.isEmpty || qualCount < 1 || blockLength < 1) return [];
  final stations = names.length < 6 ? names.length : 6;
  final shifts = <Shift>[];
  var block = 0;
  for (var first = 1; first <= qualCount; first += blockLength, block++) {
    final last = first + blockLength - 1 > qualCount ? qualCount : first + blockLength - 1;
    for (var s = 0; s < stations; s++) {
      shifts.add(Shift(
        scouterName: names[(block * stations + s) % names.length],
        station: scheduleStations[s],
        firstMatch: first,
        lastMatch: last,
      ));
    }
  }
  return shifts;
}

/// Plain-text problems with [shifts] across Q1..Q[qualCount]: stations with
/// no scouter, overlapping blocks in a station, a scouter on two stations at
/// once, and blocks past the last qualification match. Empty when fine.
List<String> scheduleProblems(List<Shift> shifts, int qualCount) {
  // message -> matches it applies to (in order)
  final found = <String, List<int>>{};
  void add(String message, int match) => (found[message] ??= []).add(match);

  for (final station in scheduleStations) {
    final here = [for (final s in shifts) if (s.station == station) s];
    for (var m = 1; m <= qualCount; m++) {
      final names = [
        for (final s in here)
          if (s.firstMatch <= m && m <= s.lastMatch) s.scouterName,
      ];
      if (names.isEmpty) {
        add('${stationLabel(station)}: no scouter', m);
      } else if (names.length > 1) {
        add('${stationLabel(station)}: ${names.join(' and ')} overlap', m);
      }
    }
  }
  for (var m = 1; m <= qualCount; m++) {
    final byName = <String, Set<String>>{};
    final display = <String, String>{};
    for (final s in shifts) {
      if (s.firstMatch <= m && m <= s.lastMatch) {
        final k = nameKey(s.scouterName);
        (byName[k] ??= {}).add(s.station);
        display[k] ??= s.scouterName;
      }
    }
    byName.forEach((k, stations) {
      if (stations.length > 1) {
        final labels = [
          for (final st in scheduleStations)
            if (stations.contains(st)) stationLabel(st),
        ];
        add('${display[k]} is on ${labels.join(' and ')} at once', m);
      }
    });
  }
  final problems = <String>[];
  found.forEach((message, matches) {
    final ranges = <String>[];
    var start = matches.first, prev = matches.first;
    for (final m in [...matches.skip(1), -1]) {
      if (m != prev + 1) {
        ranges.add(matchRange(start, prev));
        start = m;
      }
      prev = m;
    }
    problems.add('$message, ${ranges.join(', ')}');
  });
  for (final s in shifts) {
    if (s.lastMatch > qualCount) {
      problems.add(
          '${stationLabel(s.station)}: ${s.scouterName} ${s.range} runs past the last qualification match (Q$qualCount)');
    }
  }
  return problems;
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Sat 3:45 PM" in the device's time zone.
String formatWhen(DateTime t) {
  final l = t.toLocal();
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final m = l.minute.toString().padLeft(2, '0');
  return '${_weekdays[l.weekday - 1]} $h:$m ${l.hour < 12 ? 'AM' : 'PM'}';
}
