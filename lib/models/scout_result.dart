import 'package:uuid/uuid.dart';

class ScoutResult {
  final String id;
  final String scouterName;
  final String secretTeamKey;
  final String eventKey;
  final int matchNumber;
  final int teamNumber;

  // Auto phase
  bool autoLeave;
  int autoFuelScored;
  int autoFuelMissed;
  bool autoTowerLevel1;

  // Teleop phase
  int teleopFuelScored;
  int teleopFuelMissed;
  bool teleopCrossedBump;
  bool teleopEnteredTrench;

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
    this.autoLeave = false,
    this.autoFuelScored = 0,
    this.autoFuelMissed = 0,
    this.autoTowerLevel1 = false,
    this.teleopFuelScored = 0,
    this.teleopFuelMissed = 0,
    this.teleopCrossedBump = false,
    this.teleopEnteredTrench = false,
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
        'auto_leave': autoLeave,
        'auto_fuel_scored': autoFuelScored,
        'auto_fuel_missed': autoFuelMissed,
        'auto_tower_level1': autoTowerLevel1,
        'teleop_fuel_scored': teleopFuelScored,
        'teleop_fuel_missed': teleopFuelMissed,
        'teleop_crossed_bump': teleopCrossedBump,
        'teleop_entered_trench': teleopEnteredTrench,
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
        autoLeave: json['auto_leave'] ?? false,
        autoFuelScored: json['auto_fuel_scored'] ?? 0,
        autoFuelMissed: json['auto_fuel_missed'] ?? 0,
        autoTowerLevel1: json['auto_tower_level1'] ?? false,
        teleopFuelScored: json['teleop_fuel_scored'] ?? 0,
        teleopFuelMissed: json['teleop_fuel_missed'] ?? 0,
        teleopCrossedBump: json['teleop_crossed_bump'] ?? false,
        teleopEnteredTrench: json['teleop_entered_trench'] ?? false,
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
