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
  double autoFuelAccuracy;
  int autoTowerLevel;
  int autoMiddlePickup;
  bool autoDepotPickup;
  int autoHumanStationPickup;
  bool? winAuto;

  // Teleop phase
  int hopperSize;
  int teleopFuelScored;
  bool teleopShootOnFly;
  double teleopFuelAccuracy;
  List<int> volleyScoredList;
  List<int> volleyMissedList;
  List<double> volleyAccuracyList;
  // Teleop Inactive
  bool teleopInactiveScoredFuel;
  bool teleopInactiveCollectedFuel;
  bool teleopInactiveCollectedFuelPush;
  bool teleopInactiveCollectedFuelLobby;
  bool teleopInactiveCollectedFuelRefill;

  // Endgame
  int endgameTowerLevel; // 0=none, 1=L1, 2=L2, 3=L3
  int endgameFuelScored;
  double endgameFuelAccuracy;

  // Pickups
  bool fuelGroundPickup;
  bool fuelHumanPickup;
  bool fuelDepotPickup;

  // Defense - Teleop Active
  bool teleopActiveDefensePenalties;
  String teleopActiveDefenseQuality;

  // Defense - Teleop Inactive
  bool teleopInactiveDefensePenalties;
  String teleopInactiveDefenseQuality;

  // General
  String autoNotes;
  String matchNotes;

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
    this.autoFuelAccuracy = 50,
    this.autoTowerLevel = 0,
    this.autoMiddlePickup = 0,
    this.autoDepotPickup = false,
    this.autoHumanStationPickup = 0,
    this.winAuto,
    this.hopperSize = 50,
    this.teleopFuelScored = 0,
    this.teleopShootOnFly = false,
    this.teleopFuelAccuracy = 50,
    List<int>? volleyScoredList,
    List<int>? volleyMissedList,
    List<double>? volleyAccuracyList,
    this.teleopInactiveScoredFuel = false,
    this.teleopInactiveCollectedFuel = false,
    this.teleopInactiveCollectedFuelPush = false,
    this.teleopInactiveCollectedFuelLobby = false,
    this.teleopInactiveCollectedFuelRefill = false,
    this.endgameTowerLevel = 0,
    this.endgameFuelScored = 0,
    this.endgameFuelAccuracy = 50,
    this.fuelGroundPickup = false,
    this.fuelHumanPickup = false,
    this.fuelDepotPickup = false,
    this.teleopActiveDefensePenalties = false,
    this.teleopActiveDefenseQuality = 'N/A',
    this.teleopInactiveDefensePenalties = false,
    this.teleopInactiveDefenseQuality = 'N/A',
    this.autoNotes = '',
    this.matchNotes = '',
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        volleyScoredList = volleyScoredList ?? [],
        volleyMissedList = volleyMissedList ?? [],
        volleyAccuracyList = volleyAccuracyList ?? [],
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
        'auto_fuel_accuracy': autoFuelAccuracy,
        'auto_tower_level': autoTowerLevel,
        'auto_middle_pickup': autoMiddlePickup,
        'auto_depot_pickup': autoDepotPickup,
        'auto_human_station_pickup': autoHumanStationPickup,
        'win_auto': winAuto,
        'hopper_size': hopperSize,
        'teleop_fuel_scored': teleopFuelScored,
        'teleop_shoot_on_fly': teleopShootOnFly,
        'teleop_fuel_accuracy': teleopFuelAccuracy,
        'volley_scored_list': volleyScoredList,
        'volley_missed_list': volleyMissedList,
        'volley_accuracy_list': volleyAccuracyList,
        'teleop_inactive_scored_fuel': teleopInactiveScoredFuel,
        'teleop_inactive_collected_fuel': teleopInactiveCollectedFuel,
        'teleop_inactive_collected_fuel_push': teleopInactiveCollectedFuelPush,
        'teleop_inactive_collected_fuel_lobby': teleopInactiveCollectedFuelLobby,
        'teleop_inactive_collected_fuel_refill': teleopInactiveCollectedFuelRefill,
        'endgame_tower_level': endgameTowerLevel,
        'endgame_fuel_scored': endgameFuelScored,
        'endgame_fuel_accuracy': endgameFuelAccuracy,
        'fuel_ground_pickup': fuelGroundPickup,
        'fuel_human_pickup': fuelHumanPickup,
        'fuel_depot_pickup': fuelDepotPickup,
        'teleop_active_defense_penalties': teleopActiveDefensePenalties,
        'teleop_active_defense_quality': teleopActiveDefenseQuality,
        'teleop_inactive_defense_penalties': teleopInactiveDefensePenalties,
        'teleop_inactive_defense_quality': teleopInactiveDefenseQuality,
        'auto_notes': autoNotes,
        'match_notes': matchNotes,
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
        autoFuelAccuracy: (json['auto_fuel_accuracy'] ?? 50).toDouble(),
        autoTowerLevel: json['auto_tower_level'] ?? 0,
        autoMiddlePickup: json['auto_middle_pickup'] ?? 0,
        autoDepotPickup: json['auto_depot_pickup'] ?? false,
        autoHumanStationPickup: json['auto_human_station_pickup'] ?? 0,
        winAuto: json['win_auto'],
        hopperSize: json['hopper_size'] ?? 50,
        teleopFuelScored: json['teleop_fuel_scored'] ?? 0,
        teleopShootOnFly: json['teleop_shoot_on_fly'] ?? false,
        teleopFuelAccuracy: (json['teleop_fuel_accuracy'] ?? 50).toDouble(),
        volleyScoredList: (json['volley_scored_list'] as List?)?.cast<int>(),
        volleyMissedList: (json['volley_missed_list'] as List?)?.cast<int>(),
        volleyAccuracyList: (json['volley_accuracy_list'] as List?)?.map((e) => (e as num).toDouble()).toList(),
        teleopInactiveScoredFuel: json['teleop_inactive_scored_fuel'] ?? false,
        teleopInactiveCollectedFuel: json['teleop_inactive_collected_fuel'] ?? false,
        teleopInactiveCollectedFuelPush: json['teleop_inactive_collected_fuel_push'] ?? false,
        teleopInactiveCollectedFuelLobby: json['teleop_inactive_collected_fuel_lobby'] ?? false,
        teleopInactiveCollectedFuelRefill: json['teleop_inactive_collected_fuel_refill'] ?? false,
        endgameTowerLevel: json['endgame_tower_level'] ?? 0,
        endgameFuelScored: json['endgame_fuel_scored'] ?? 0,
        endgameFuelAccuracy: (json['endgame_fuel_accuracy'] ?? 50).toDouble(),
        fuelGroundPickup: json['fuel_ground_pickup'] ?? false,
        fuelHumanPickup: json['fuel_human_pickup'] ?? false,
        fuelDepotPickup: json['fuel_depot_pickup'] ?? false,
        teleopActiveDefensePenalties: json['teleop_active_defense_penalties'] ?? false,
        teleopActiveDefenseQuality: json['teleop_active_defense_quality'] ?? 'N/A',
        teleopInactiveDefensePenalties: json['teleop_inactive_defense_penalties'] ?? false,
        teleopInactiveDefenseQuality: json['teleop_inactive_defense_quality'] ?? 'N/A',
        autoNotes: json['auto_notes'] ?? '',
        matchNotes: json['match_notes'] ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
      );
}
