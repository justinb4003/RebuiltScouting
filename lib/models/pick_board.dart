import 'dart:math' as math;
import 'pick_list.dart';

/// Same normalization as pick_votes.voter_key in the API: one ballot per
/// person regardless of how they capitalize or space their name.
String voterKey(String voter) => voter
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// One person's pick list. Reuses [PickList] so ordering rules match the
/// shared list; personal lists only use ranked / unranked / DNP.
class Ballot {
  final String voter;
  final PickList list;

  const Ballot(this.voter, this.list);

  String get key => voterKey(voter);

  /// Someone who opened the board but hasn't ranked or DNP'd anyone yet
  /// shouldn't count against consensus.
  bool get isActive => list.teams.any((t) => t.isRanked || t.dnp);

  factory Ballot.fromJson(Map<String, dynamic> json) =>
      Ballot((json['voter'] ?? '') as String, PickList.fromJson(json));

  Map<String, dynamic> toJson() => {'voter': voter, ...list.toJson()};
}

/// One team's line on the board: everyone's rank and how many agree.
class BoardRow {
  final int teamNumber;

  /// Voter key -> rank, for active voters who ranked this team.
  final Map<String, int> ranks;
  final List<String> dnpBy;

  /// The board spot this team holds (row #k is the team the most people
  /// put at #k); null for teams that didn't win a spot.
  final int? agreedRank;

  /// 0–100: share of everyone voting who put the team exactly at
  /// [agreedRank]. Null with fewer than two people voting or no spot.
  final double? agreement;
  final bool taken;

  const BoardRow({
    required this.teamNumber,
    required this.ranks,
    required this.dnpBy,
    required this.agreedRank,
    required this.agreement,
    required this.taken,
  });
}

/// Everyone's ballots for an event (API PickVotes container) plus the shared
/// list of teams already taken by other alliances.
class PickBoard {
  /// Ballots keyed by [voterKey].
  final Map<String, Ballot> ballots;
  final Set<int> taken;
  final int takenVersion;

  const PickBoard({
    this.ballots = const {},
    this.taken = const {},
    this.takenVersion = 0,
  });

  /// Active ballots, alphabetical.
  List<Ballot> get voters => ballots.values.where((b) => b.isActive).toList()
    ..sort((a, b) => a.voter.toLowerCase().compareTo(b.voter.toLowerCase()));

  PickBoard withBallot(Ballot b) =>
      PickBoard(ballots: {...ballots, b.key: b}, taken: taken,
          takenVersion: takenVersion);

  PickBoard withTaken(Set<int> taken, int version) =>
      PickBoard(ballots: ballots, taken: taken, takenVersion: version);

  /// The board, spot by spot: row #k is the team the most people put at
  /// #k on their own list; a tie shows every tied team at #k. A team shows
  /// once, at the first spot it wins, so later spots go to the next
  /// most-voted team. A spot nobody put a remaining team at is skipped.
  /// Teams on lists that never win a spot follow (no spot, no agreement).
  /// Teams nobody ranked (DNP only) aren't shown.
  /// [teamCount] is the number of teams at the event.
  List<BoardRow> rows(int teamCount) {
    final voters = this.voters;
    final longest =
        voters.fold<int>(0, (m, b) => math.max(m, b.list.ranked.length));
    final n = math.max(teamCount, longest);
    final ranksByTeam = <int, Map<String, int>>{};
    final dnpByTeam = <int, List<String>>{};
    for (final b in voters) {
      for (final t in b.list.teams) {
        if (t.isRanked) {
          (ranksByTeam[t.teamNumber] ??= {})[b.key] = t.ranking!;
        } else if (t.dnp) {
          (dnpByTeam[t.teamNumber] ??= []).add(b.key);
        }
      }
    }
    // Tie-break only: average spot, with left-off / DNP counted as last.
    double meanRank(int tn) => voters.isEmpty
        ? 0
        : voters.fold<int>(
                0, (sum, b) => sum + (ranksByTeam[tn]?[b.key] ?? n + 1)) /
            voters.length;
    int votesAt(int tn, int k) =>
        ranksByTeam[tn]!.values.where((r) => r == k).length;
    // Display order among tied or spotless teams.
    int byListsThenMean(int a, int b) {
      final byLists =
          ranksByTeam[b]!.length.compareTo(ranksByTeam[a]!.length);
      if (byLists != 0) return byLists;
      final byMean = meanRank(a).compareTo(meanRank(b));
      return byMean != 0 ? byMean : a.compareTo(b);
    }

    BoardRow row(int tn, {int? spot}) => BoardRow(
          teamNumber: tn,
          ranks: ranksByTeam[tn] ?? const {},
          dnpBy: dnpByTeam[tn] ?? const [],
          agreedRank: spot,
          agreement: spot == null || voters.length < 2
              ? null
              : 100 * votesAt(tn, spot) / voters.length,
          taken: taken.contains(tn),
        );

    final open = ranksByTeam.keys.toSet();
    final rows = <BoardRow>[];
    for (var k = 1; k <= longest && open.isNotEmpty; k++) {
      final most = open.fold<int>(0, (m, tn) => math.max(m, votesAt(tn, k)));
      if (most == 0) continue; // every #k vote went to a team placed above
      final winners = open.where((tn) => votesAt(tn, k) == most).toList()
        ..sort(byListsThenMean);
      open.removeAll(winners);
      rows.addAll([for (final tn in winners) row(tn, spot: k)]);
    }
    rows.addAll([for (final tn in open.toList()..sort(byListsThenMean)) row(tn)]);
    return rows;
  }

  factory PickBoard.fromJson(Map<String, dynamic> json) {
    final ballots = [
      for (final l in (json['lists'] ?? []) as List)
        Ballot.fromJson(l as Map<String, dynamic>),
    ];
    final taken = json['taken'] as Map<String, dynamic>?;
    return PickBoard(
      ballots: {for (final b in ballots) b.key: b},
      taken: {
        for (final t in (taken?['teams'] ?? []) as List) (t as num).toInt(),
      },
      takenVersion: (taken?['version'] as num?)?.toInt() ?? 0,
    );
  }

  /// Same shape as GetPickVotes so the cache round-trips through fromJson.
  Map<String, dynamic> toJson() => {
        'lists': ballots.values.map((b) => b.toJson()).toList(),
        'taken': {'teams': taken.toList()..sort(), 'version': takenVersion},
      };
}
