import 'dart:math';

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

/// Plain-text errors in [shifts] across Q1..Q[qualCount]: a station nobody
/// scouts, overlapping blocks in a station, a scouter on two stations at
/// once, blocks past the last qualification match, and (with [maxMatches])
/// anyone scouting more matches than that. Empty when every match has six
/// different scouts.
List<String> scheduleProblems(List<Shift> shifts, int qualCount, {int? maxMatches}) {
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
        add('${stationLabel(station)}: nobody scouting', m);
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
  if (maxMatches != null) {
    final over = [
      for (final e in matchesPerPerson(shifts).entries)
        if (e.value > maxMatches) '${e.key} (${e.value})',
    ];
    if (over.isNotEmpty) {
      problems.add('More than $maxMatches matches: ${over.join(', ')}');
    }
  }
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

// ---------------------------------------------------------------------------
// Blocks and groups: how the Schedule Builder lays a schedule out.

bool isRedStation(String station) => station.startsWith('red');

/// A run of qualification matches and who scouts each station during it
/// (stations missing from [names] are unscouted).
class ScheduleBlock {
  final int firstMatch;
  final int lastMatch;
  final Map<String, String> names;

  const ScheduleBlock(this.firstMatch, this.lastMatch, this.names);

  String get range => matchRange(firstMatch, lastMatch);
}

/// [shifts] cut into blocks wherever any shift starts or ends, so each
/// block has at most one scouter per station (a station with two overlapping
/// shifts shows the first; scheduleProblems reports the overlap).
List<ScheduleBlock> toBlocks(List<Shift> shifts) {
  final edges = <int>{};
  for (final s in shifts) {
    edges
      ..add(s.firstMatch)
      ..add(s.lastMatch + 1);
  }
  final sorted = edges.toList()..sort();
  final blocks = <ScheduleBlock>[];
  for (var i = 0; i + 1 < sorted.length; i++) {
    final first = sorted[i], last = sorted[i + 1] - 1;
    final names = <String, String>{};
    for (final s in shifts) {
      if (s.firstMatch <= first && last <= s.lastMatch) {
        names.putIfAbsent(s.station, () => s.scouterName);
      }
    }
    if (names.isNotEmpty) blocks.add(ScheduleBlock(first, last, names));
  }
  return blocks;
}

/// One shift per filled cell of [blocks].
List<Shift> fromBlocks(List<ScheduleBlock> blocks) => [
      for (final b in blocks)
        for (final station in scheduleStations)
          if ((b.names[station] ?? '').trim().isNotEmpty)
            Shift(
              scouterName: b.names[station]!.trim(),
              station: station,
              firstMatch: b.firstMatch,
              lastMatch: b.lastMatch,
            ),
    ];

/// [shifts] with [station] in Q[first]..Q[last] set to [name] (or cleared
/// when [name] is empty). Shifts at that station overlapping the range are
/// trimmed around it.
List<Shift> setCell(List<Shift> shifts, String station, int first, int last, String name) {
  final out = <Shift>[];
  for (final s in shifts) {
    if (s.station != station || s.lastMatch < first || s.firstMatch > last) {
      out.add(s);
      continue;
    }
    if (s.firstMatch < first) out.add(s.copyWith(lastMatch: first - 1));
    if (s.lastMatch > last) out.add(s.copyWith(firstMatch: last + 1));
  }
  if (name.trim().isNotEmpty) {
    out.add(Shift(scouterName: name.trim(), station: station, firstMatch: first, lastMatch: last));
  }
  out.sort((a, b) => a.firstMatch != b.firstMatch
      ? a.firstMatch.compareTo(b.firstMatch)
      : scheduleStations.indexOf(a.station).compareTo(scheduleStations.indexOf(b.station)));
  return out;
}

/// People who scout together (2–6): always in the same blocks.
typedef ScoutGroup = List<String>;

/// How many blocks give each of [people] about [shiftsPerPerson] shifts,
/// with six scouts per block (or everyone, if fewer than six). At least one,
/// and never more blocks than matches.
int blockCountFor(int people, int shiftsPerPerson, int qualCount) {
  if (people < 1 || shiftsPerPerson < 1 || qualCount < 1) return 0;
  final seats = people < 6 ? people : 6;
  final blocks = (people * shiftsPerPerson / seats).round();
  return blocks.clamp(1, qualCount);
}

/// Q1..Q[qualCount] split into [count] runs of consecutive matches, as even
/// as possible (longer runs first): 80 into 11 -> 3 of 8, then 8 of 7.
///
/// With [cuts] (match numbers a break follows, e.g. lunch after Q14), no run
/// crosses a cut: the stretches between cuts share the runs in proportion to
/// their length, at least one each (so there can be more than [count] when
/// there are more stretches than that).
List<(int, int)> blockRanges(int qualCount, int count, {List<int> cuts = const []}) {
  if (qualCount < 1 || count < 1) return [];
  // Stretches of matches between cuts.
  final edges = [0, ...{for (final c in cuts) if (c >= 1 && c < qualCount) c}.toList()..sort(), qualCount];
  final stretches = [for (var i = 0; i + 1 < edges.length; i++) (edges[i] + 1, edges[i + 1])];
  final lengths = [for (final (a, b) in stretches) b - a + 1];
  // Largest remainder: each stretch gets its share of the runs, at least one.
  final total = count < stretches.length ? stretches.length : count;
  final exact = [for (final l in lengths) l * total / qualCount];
  final runs = [for (final e in exact) e.floor() < 1 ? 1 : e.floor()];
  var left = total - runs.fold(0, (a, b) => a + b);
  final byRemainder = [for (var i = 0; i < runs.length; i++) i]
    ..sort((a, b) => (exact[b] - exact[b].floor()).compareTo(exact[a] - exact[a].floor()));
  for (var k = 0; left > 0; k = (k + 1) % byRemainder.length) {
    final i = byRemainder[k];
    if (runs[i] < lengths[i]) {
      runs[i]++;
      left--;
    }
  }
  while (left < 0) {
    // Too many (from the at-least-one rule): take from the biggest share.
    final i = [for (var j = 0; j < runs.length; j++) j].reduce((a, b) => runs[a] >= runs[b] ? a : b);
    if (runs[i] <= 1) break;
    runs[i]--;
    left++;
  }
  final out = <(int, int)>[];
  for (var s = 0; s < stretches.length; s++) {
    final (first, last) = stretches[s];
    final len = lengths[s], n = runs[s] > len ? len : runs[s];
    var at = first;
    for (var i = 0; i < n; i++) {
      final size = len ~/ n + (i < len % n ? 1 : 0);
      out.add((at, at + size - 1));
      at += size;
    }
    assert(at == last + 1);
  }
  return out;
}

/// The breaks shifts should end at: lunch and the end of each day.
List<int> shiftCuts(List<ScheduleBreak> breaks) =>
    [for (final b in breaks) if (b.kind != BreakKind.other) b.afterMatch];

/// A random schedule over [ranges] (from [blockRanges]): six scouts per
/// block (fewer only if fewer than six people are scouting).
///
/// [roster] is everyone scouting; each of [groups] (2–6 people from the
/// roster) is always placed together. The first lap (until everyone has
/// scouted once) is random; after that the same order repeats, so the same
/// crews scout together again (exactly, when the head count is a multiple of
/// six; otherwise the crews drift by a few people per lap). Everyone waits in
/// one line: each block takes from the front, and whoever scouts goes to the
/// back, so nobody gets a second shift before everyone has had a first. A
/// group that doesn't fit whole waits at the front for the next block. With
/// [maxMatches], people who'd go over it are skipped when someone else can
/// take the spot. Stations are random the first time; after that people
/// go back to the station they had, when it's free.
List<Shift> generateSchedule(
    List<String> roster, List<ScoutGroup> groups, List<(int, int)> ranges, Random rng,
    {int? maxMatches}) {
  if (roster.isEmpty || ranges.isEmpty) return [];
  final inRoster = {for (final n in roster) nameKey(n)};
  // Units: each group (still scouting) as one, everyone else alone.
  final units = <List<String>>[];
  final grouped = <String>{};
  for (final g in groups) {
    final members = [for (final n in g) if (inRoster.contains(nameKey(n)) && grouped.add(nameKey(n))) n];
    if (members.isNotEmpty) units.add(members);
  }
  for (final n in roster) {
    if (grouped.add(nameKey(n))) units.add([n]);
  }
  final seatsPerBlock = roster.length < 6 ? roster.length : 6;
  final load = List.filled(units.length, 0);
  final matches = List.filled(units.length, 0);
  // The line: unit indexes, front first. Random for the first lap.
  final line = [for (var i = 0; i < units.length; i++) i]..shuffle(rng);
  final blocks = <ScheduleBlock>[];
  final stationOf = <String, String>{};
  for (final (first, last) in ranges) {
    final length = last - first + 1;
    // Cost per seat: shifts so far first (so nobody gets a second before
    // everyone has had a first, even when a group can't fit), then place in
    // line, plus a big penalty for going over [maxMatches].
    final cost = <int, double>{
      for (var pos = 0; pos < line.length; pos++)
        line[pos]: units[line[pos]].length *
            (load[line[pos]] * 1000 + pos + (maxMatches != null && matches[line[pos]] + length > maxMatches ? 100000 : 0)).toDouble(),
    };
    final order = [...line]..sort((a, b) => (cost[a]! / units[a].length).compareTo(cost[b]! / units[b].length));
    // Cheapest set of whole units filling exactly the block's seats
    // (branch and bound, cheapest first, so the first answer is the greedy
    // one and the search only improves on it).
    var picked = <int>[];
    var best = double.infinity;
    var steps = 0;
    final chosen = <int>[];
    void search(int from, int seats, double spent) {
      if (++steps > 20000 || spent >= best) return;
      if (seats == 0) {
        best = spent;
        picked = List.of(chosen);
        return;
      }
      for (var k = from; k < order.length; k++) {
        final i = order[k];
        if (units[i].length > seats) continue;
        chosen.add(i);
        search(k + 1, seats - units[i].length, spent + cost[i]!);
        chosen.removeLast();
      }
    }
    search(0, seatsPerBlock, 0);
    // Whoever scouts goes to the back, keeping their order in line.
    final went = picked.toSet();
    final stay = [for (final i in line) if (!went.contains(i)) i];
    final moved = [for (final i in line) if (went.contains(i)) i];
    line
      ..clear()
      ..addAll(stay)
      ..addAll(moved);
    for (final i in picked) {
      load[i]++;
      matches[i] += length;
    }
    // Back on the station they had last time when it's free; everyone
    // else (and the first lap) gets a random one.
    final people = [for (final i in moved) ...units[i]]..shuffle(rng);
    final seats = <String, String>{};
    final newcomers = <String>[];
    for (final n in people) {
      final st = stationOf[n];
      if (st != null && !seats.containsKey(st)) {
        seats[st] = n;
      } else {
        newcomers.add(n);
      }
    }
    final free = [for (final st in scheduleStations) if (!seats.containsKey(st)) st]..shuffle(rng);
    for (var k = 0; k < newcomers.length; k++) {
      seats[free[k]] = newcomers[k];
    }
    seats.forEach((st, n) => stationOf[n] = st);
    blocks.add(ScheduleBlock(first, last, {
      for (final st in scheduleStations)
        if (seats.containsKey(st)) st: seats[st]!,
    }));
  }
  return fromBlocks(blocks);
}

/// Things that work but aren't ideal: people who scout more shifts than
/// others, and people picked to scout who have no shifts.
List<String> scheduleWarnings(List<Shift> shifts, List<String> roster) {
  final perPerson = blocksPerPerson(shifts);
  final out = <String>[];
  if (perPerson.isNotEmpty && perPerson.values.first != perPerson.values.last) {
    final most = perPerson.values.last;
    final busiest = [for (final e in perPerson.entries) if (e.value == most) e.key];
    out.add('Shifts per person range from ${perPerson.values.first} to $most '
        '(most: ${busiest.join(', ')})');
  }
  final scheduled = {for (final n in perPerson.keys) nameKey(n)};
  final idle = [for (final n in roster) if (!scheduled.contains(nameKey(n))) n];
  if (idle.isNotEmpty) out.add('No shifts: ${idle.join(', ')}');
  return out;
}

/// How many qualification matches each person scouts in [shifts], most
/// first.
Map<String, int> matchesPerPerson(List<Shift> shifts) {
  final counts = <String, int>{};
  final display = <String, String>{};
  for (final s in shifts) {
    final k = nameKey(s.scouterName);
    display[k] ??= s.scouterName;
    counts[k] = (counts[k] ?? 0) + s.lastMatch - s.firstMatch + 1;
  }
  final out = {for (final e in counts.entries) display[e.key]!: e.value};
  return Map.fromEntries(out.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
}

/// Why [people] scouts can't cover Q1..Q[qualCount] (six positions each)
/// without someone scouting more than [maxMatches], or null if they can.
/// Every match needs six scouts no matter how the shifts are cut, so this
/// is just the total over the people.
String? maxMatchesProblem(int people, int qualCount, int maxMatches) {
  if (people < 1 || qualCount < 1) return null;
  final seats = people < 6 ? people : 6;
  final total = qualCount * seats;
  final each = (total / people).ceil();
  if (each <= maxMatches) return null;
  final needed = (total / maxMatches).ceil();
  return '$qualCount quals × $seats positions is $total matches to scout. '
      'With $people scouts that\'s at least $each each, over the max of $maxMatches. '
      'Pick at least $needed scouts or raise the max to $each.';
}

/// How many blocks each person has in [shifts], fewest first.
Map<String, int> blocksPerPerson(List<Shift> shifts) {
  final counts = <String, int>{};
  final display = <String, String>{};
  for (final b in toBlocks(shifts)) {
    for (final n in b.names.values) {
      final k = nameKey(n);
      display[k] ??= n;
      counts[k] = (counts[k] ?? 0) + 1;
    }
  }
  final out = {for (final e in counts.entries) display[e.key]!: e.value};
  return Map.fromEntries(out.entries.toList()..sort((a, b) => a.value.compareTo(b.value)));
}

// ---------------------------------------------------------------------------
// Match times and breaks (lunch, end of day) for showing the schedule.

/// When a qualification match starts: when it actually did, once played,
/// otherwise TBA's estimate.
class MatchTime {
  final DateTime at;
  final bool actual;
  const MatchTime(this.at, {required this.actual});
}

/// Qual match number -> start time, from epoch-second times.
Map<int, MatchTime> qualTimes(Iterable<({int match, int? time, int? actualTime})> matches) => {
      for (final m in matches)
        if ((m.actualTime ?? m.time) != null)
          m.match: MatchTime(
            DateTime.fromMillisecondsSinceEpoch((m.actualTime ?? m.time)! * 1000),
            actual: m.actualTime != null,
          ),
    };

enum BreakKind { lunch, endOfDay, other }

/// A pause in the qualification schedule between [afterMatch] and the next.
class ScheduleBreak {
  final int afterMatch;
  final DateTime from; // start of the last match before it
  final DateTime to; // start of the first match after it
  final BreakKind kind;
  const ScheduleBreak(this.afterMatch, this.from, this.to, this.kind);

  String get label => switch (kind) {
        BreakKind.lunch => 'Lunch',
        BreakKind.endOfDay => 'End of day',
        BreakKind.other => 'Break',
      };
}

/// Gaps between consecutive quals well beyond the usual ~8 minute cycle:
/// into the next day is the end of the day; 40+ minutes starting between
/// 10 AM and 2 PM is lunch; anything else over 25 minutes is a break.
List<ScheduleBreak> findBreaks(Map<int, MatchTime> times) {
  final numbers = times.keys.toList()..sort();
  final out = <ScheduleBreak>[];
  for (var i = 0; i + 1 < numbers.length; i++) {
    if (numbers[i + 1] != numbers[i] + 1) continue;
    final a = times[numbers[i]]!.at.toLocal(), b = times[numbers[i + 1]]!.at.toLocal();
    final gap = b.difference(a);
    if (gap.inMinutes <= 25) continue;
    final kind = a.day != b.day || gap.inHours >= 6
        ? BreakKind.endOfDay
        : gap.inMinutes >= 40 && a.hour >= 10 && a.hour < 14
            ? BreakKind.lunch
            : BreakKind.other;
    out.add(ScheduleBreak(numbers[i], a, b, kind));
  }
  return out;
}

/// "10:50 AM", or "Fri 10:50 AM" with [day].
String clockTime(DateTime t, {bool day = false}) {
  final l = t.toLocal();
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final m = l.minute.toString().padLeft(2, '0');
  return '${day ? '${_weekdays[l.weekday - 1]} ' : ''}$h:$m ${l.hour < 12 ? 'AM' : 'PM'}';
}
