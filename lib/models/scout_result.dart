import 'package:uuid/uuid.dart';

class ScoutResult {
  final String id;
  final String scouterName;
  final String secretTeamKey;
  final String eventKey;
  final int matchNumber;
  final int teamNumber;

  // Auto phase
  bool autoDidNothing;
  int autoFuelScored;
  int autoFuelMissed;
  int autoTowerLevel;
  int autoMiddlePickup;
  int autoDepotPickup;
  int autoHumanStationPickup;

  // Teleop phase
  int teleopFuelScored;
  int teleopFuelMissed;
  // Endgame
  int endgameTowerLevel; // 0=none, 1=L1, 2=L2, 3=L3

  // Pickups
  bool fuelGroundPickup;
  bool fuelHumanPickup;

  // General
  String matchNotes;
  int defenseRating; // 0-5

  final DateTime timestamp;

  ScoutResult({
    String? id,
    required this.scouterName,
    required this.secretTeamKey,
    required this.eventKey,
    required this.matchNumber,
    required this.teamNumber,
    this.autoDidNothing = false,
    this.autoFuelScored = 0,
    this.autoFuelMissed = 0,
    this.autoTowerLevel = 0,
    this.autoMiddlePickup = 0,
    this.autoDepotPickup = 0,
    this.autoHumanStationPickup = 0,
    this.teleopFuelScored = 0,
    this.teleopFuelMissed = 0,
    this.endgameTowerLevel = 0,
    this.fuelGroundPickup = false,
    this.fuelHumanPickup = false,
    this.matchNotes = '',
    this.defenseRating = 0,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'scouter_name': scouterName,
        'secret_team_key': secretTeamKey,
        'event_key': eventKey,
        'match_number': matchNumber,
        'team_number': teamNumber,
        'auto_did_nothing': autoDidNothing,
        'auto_fuel_scored': autoFuelScored,
        'auto_fuel_missed': autoFuelMissed,
        'auto_tower_level': autoTowerLevel,
        'auto_middle_pickup': autoMiddlePickup,
        'auto_depot_pickup': autoDepotPickup,
        'auto_human_station_pickup': autoHumanStationPickup,
        'teleop_fuel_scored': teleopFuelScored,
        'teleop_fuel_missed': teleopFuelMissed,
        'endgame_tower_level': endgameTowerLevel,
        'fuel_ground_pickup': fuelGroundPickup,
        'fuel_human_pickup': fuelHumanPickup,
        'match_notes': matchNotes,
        'defense_rating': defenseRating,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ScoutResult.fromJson(Map<String, dynamic> json) => ScoutResult(
        id: json['id'],
        scouterName: json['scouter_name'] ?? '',
        secretTeamKey: json['secret_team_key'] ?? '',
        eventKey: json['event_key'] ?? '',
        matchNumber: json['match_number'] ?? 0,
        teamNumber: json['team_number'] ?? 0,
        autoDidNothing: json['auto_did_nothing'] ?? false,
        autoFuelScored: json['auto_fuel_scored'] ?? 0,
        autoFuelMissed: json['auto_fuel_missed'] ?? 0,
        autoTowerLevel: json['auto_tower_level'] ?? 0,
        autoMiddlePickup: json['auto_middle_pickup'] ?? 0,
        autoDepotPickup: json['auto_depot_pickup'] ?? 0,
        autoHumanStationPickup: json['auto_human_station_pickup'] ?? 0,
        teleopFuelScored: json['teleop_fuel_scored'] ?? 0,
        teleopFuelMissed: json['teleop_fuel_missed'] ?? 0,
        endgameTowerLevel: json['endgame_tower_level'] ?? 0,
        fuelGroundPickup: json['fuel_ground_pickup'] ?? false,
        fuelHumanPickup: json['fuel_human_pickup'] ?? false,
        matchNotes: json['match_notes'] ?? '',
        defenseRating: json['defense_rating'] ?? 0,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
      );
}
