import '../models/match_result.dart';

/// A team's official record from played matches.
class TeamRecord {
  final int wins;
  final int losses;
  final int ties;
  final double? avgScore;
  final double? avgRp; // ranking points per played match
  final double? avgFuel; // hub fuel counted per match for their alliance

  const TeamRecord(this.wins, this.losses, this.ties, this.avgScore, this.avgRp, this.avgFuel);

  int get played => wins + losses + ties;

  String get label => '$wins-$losses${ties > 0 ? '-$ties' : ''}';
}

/// Matches (sorted) that [team] is in.
List<MatchResult> matchesForTeam(Iterable<MatchResult> matches, int team) =>
    [for (final m in matches) if (m.hasTeam(team)) m]..sort((a, b) => a.sortKey.compareTo(b.sortKey));

/// Record over [matches] for [team]; pass quals only for a ranking-style view.
TeamRecord teamRecord(Iterable<MatchResult> matches, int team, {bool qualsOnly = false}) {
  var w = 0, l = 0, t = 0;
  var score = 0.0, rp = 0.0, fuel = 0.0;
  var scoreN = 0, rpN = 0, fuelN = 0;
  for (final m in matches) {
    if (!m.played || !m.hasTeam(team)) continue;
    if (qualsOnly && !m.isQual) continue;
    final a = m.allianceOf(team)!;
    final won = m.won(team);
    if (won == true) {
      w++;
    } else if (won == false) {
      l++;
    } else {
      t++;
    }
    score += a.score!;
    scoreN++;
    if (a.breakdown != null) {
      fuel += a.breakdown!.hubTotal;
      fuelN++;
      // RP only counts in qualification.
      if (m.isQual) {
        rp += a.rp;
        rpN++;
      }
    }
  }
  return TeamRecord(w, l, t, scoreN == 0 ? null : score / scoreN, rpN == 0 ? null : rp / rpN,
      fuelN == 0 ? null : fuel / fuelN);
}
