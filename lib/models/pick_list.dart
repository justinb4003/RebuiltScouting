/// Shared, live pick list stored in the API's ScoutingResults container
/// (one document per secret key + event; also read/written by Streamlit).
enum PickStatus { ranked, unranked, decline, dnp }

class PickListEntry {
  final int teamNumber;
  int? ranking;
  bool dnp;
  bool decline;
  String notes;
  bool picked;

  PickListEntry({
    required this.teamNumber,
    this.ranking,
    this.dnp = false,
    this.decline = false,
    this.notes = '',
    this.picked = false,
  });

  bool get isRanked => ranking != null && !dnp && !decline;

  PickStatus get status => isRanked
      ? PickStatus.ranked
      : dnp
          ? PickStatus.dnp
          : decline
              ? PickStatus.decline
              : PickStatus.unranked;

  bool get isEmpty =>
      !isRanked && !dnp && !decline && notes.isEmpty && !picked;

  PickListEntry copy() => PickListEntry(
        teamNumber: teamNumber,
        ranking: ranking,
        dnp: dnp,
        decline: decline,
        notes: notes,
        picked: picked,
      );

  Map<String, dynamic> toJson() => {
        'team_number': teamNumber,
        'ranking': ranking,
        'dnp': dnp,
        'decline': decline,
        'notes': notes,
        'picked': picked,
      };

  factory PickListEntry.fromJson(Map<String, dynamic> json) => PickListEntry(
        teamNumber: (json['team_number'] as num).toInt(),
        ranking: (json['ranking'] as num?)?.toInt(),
        dnp: json['dnp'] == true,
        decline: json['decline'] == true,
        notes: (json['notes'] ?? '') as String,
        picked: json['picked'] == true,
      );
}

/// One change to one team. Mirrors the UpdatePickListTeam request body.
class PickListUpdate {
  final int teamNumber;
  final int? position;
  final PickStatus? status;
  final String? notes;
  final bool? picked;

  const PickListUpdate(
    this.teamNumber, {
    this.position,
    this.status,
    this.notes,
    this.picked,
  }) : assert(position == null || status == null);

  Map<String, dynamic> toJson() => {
        'team_number': teamNumber,
        if (position != null) 'position': position,
        if (status != null) 'status': status!.name,
        if (notes != null) 'notes': notes,
        if (picked != null) 'picked': picked,
      };
}

class PickList {
  final List<PickListEntry> teams;
  final int version;
  final String updatedBy;
  final DateTime? updatedAt;

  PickList({
    required this.teams,
    this.version = 0,
    this.updatedBy = '',
    this.updatedAt,
  });

  factory PickList.empty() => PickList(teams: []);

  PickListEntry? entryFor(int teamNumber) {
    for (final t in teams) {
      if (t.teamNumber == teamNumber) return t;
    }
    return null;
  }

  PickStatus statusOf(int teamNumber) =>
      entryFor(teamNumber)?.status ?? PickStatus.unranked;

  List<PickListEntry> get ranked =>
      teams.where((t) => t.isRanked).toList()
        ..sort((a, b) => a.ranking!.compareTo(b.ranking!));

  PickList copy() => PickList(
        teams: teams.map((t) => t.copy()).toList(),
        version: version,
        updatedBy: updatedBy,
        updatedAt: updatedAt,
      );

  /// Same rules as pick_list.apply_update in the API, so optimistic local
  /// changes match what the server will store.
  PickList apply(PickListUpdate u) {
    final next = copy();
    final teams = next.teams;
    var entry = next.entryFor(u.teamNumber);
    if (entry == null) {
      entry = PickListEntry(teamNumber: u.teamNumber);
      teams.add(entry);
    }
    if (u.position != null || u.status != null) {
      final ranked = teams
          .where((t) => !identical(t, entry) && t.isRanked)
          .toList()
        ..sort((a, b) => a.ranking!.compareTo(b.ranking!));
      if (u.position != null) {
        entry.dnp = false;
        entry.decline = false;
        ranked.insert((u.position! - 1).clamp(0, ranked.length), entry);
      } else {
        entry.dnp = u.status == PickStatus.dnp;
        entry.decline = u.status == PickStatus.decline;
        entry.ranking = null;
      }
      for (var i = 0; i < ranked.length; i++) {
        ranked[i].ranking = i + 1;
      }
    }
    for (final t in teams) {
      if (!t.isRanked) t.ranking = null;
    }
    if (u.notes != null) entry.notes = u.notes!.trim();
    if (u.picked != null) entry.picked = u.picked!;
    teams.removeWhere((t) => t.isEmpty);
    return next;
  }

  Map<String, dynamic> toJson() => {
        'teams': teams.map((t) => t.toJson()).toList(),
        'version': version,
        'updated_by': updatedBy,
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory PickList.fromJson(Map<String, dynamic> json) => PickList(
        teams: ((json['teams'] ?? []) as List)
            .map((t) => PickListEntry.fromJson(t as Map<String, dynamic>))
            .toList(),
        version: (json['version'] as num?)?.toInt() ?? 0,
        updatedBy: (json['updated_by'] ?? '') as String,
        updatedAt: DateTime.tryParse((json['updated_at'] ?? '') as String),
      );
}
