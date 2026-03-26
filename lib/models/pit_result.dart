import 'package:uuid/uuid.dart';

class PitResult {
  final String id;
  final String scouterName;
  final String secretTeamKey;
  final String eventKey;
  final int teamNumber;
  String driveTrain; // Swerve, Tank, Mecanum, Other
  String driveTrainOther;
  bool groundPickup;
  bool humanPlayerPickup;
  int fuelCapacity;
  String autoStartingSpot; // Left, Center, Right
  bool autoStartLeftTrench;
  bool autoStartLeftBump;
  bool autoStartHub;
  bool autoStartRightBump;
  bool autoStartRightTrench;
  bool autoCrashConcern;
  bool autoHang;
  String autoNotes;
  bool hangingWorks;
  int hangingLevel; // 1=L1, 2=L2, 3=L3
  String hangingTime;
  String hangingHow;
  String teleopActivePlan;
  String teleopInactivePlan;
  bool willingToPlayDefense;
  bool ratherPlayDefense;
  bool shootOnMove;
  String hopperEmptyTime;
  String funQuestion;
  String notes;
  String? photoBase64;
  final DateTime timestamp;

  PitResult({
    String? id,
    required this.scouterName,
    required this.secretTeamKey,
    required this.eventKey,
    required this.teamNumber,
    this.driveTrain = 'Swerve',
    this.driveTrainOther = '',
    this.groundPickup = false,
    this.humanPlayerPickup = false,
    this.fuelCapacity = 0,
    this.autoStartingSpot = 'Left',
    this.autoStartLeftTrench = false,
    this.autoStartLeftBump = false,
    this.autoStartHub = false,
    this.autoStartRightBump = false,
    this.autoStartRightTrench = false,
    this.autoCrashConcern = false,
    this.autoHang = false,
    this.autoNotes = '',
    this.hangingWorks = false,
    this.hangingLevel = 1,
    this.hangingTime = '',
    this.hangingHow = '',
    this.teleopActivePlan = '',
    this.teleopInactivePlan = '',
    this.willingToPlayDefense = false,
    this.ratherPlayDefense = false,
    this.shootOnMove = false,
    this.hopperEmptyTime = '',
    this.funQuestion = '',
    this.notes = '',
    this.photoBase64,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'scouter_name': scouterName,
        'secret_team_key': secretTeamKey,
        'event_key': eventKey,
        'team_number': teamNumber,
        'drive_train': driveTrain,
        'drive_train_other': driveTrainOther,
        'ground_pickup': groundPickup,
        'human_player_pickup': humanPlayerPickup,
        'fuel_capacity': fuelCapacity,
        'auto_starting_spot': autoStartingSpot,
        'auto_start_left_trench': autoStartLeftTrench,
        'auto_start_left_bump': autoStartLeftBump,
        'auto_start_hub': autoStartHub,
        'auto_start_right_bump': autoStartRightBump,
        'auto_start_right_trench': autoStartRightTrench,
        'auto_crash_concern': autoCrashConcern,
        'auto_hang': autoHang,
        'auto_notes': autoNotes,
        'hanging_works': hangingWorks,
        'hanging_level': hangingLevel,
        'hanging_time': hangingTime,
        'hanging_how': hangingHow,
        'teleop_active_plan': teleopActivePlan,
        'teleop_inactive_plan': teleopInactivePlan,
        'willing_to_play_defense': willingToPlayDefense,
        'rather_play_defense': ratherPlayDefense,
        'shoot_on_move': shootOnMove,
        'hopper_empty_time': hopperEmptyTime,
        'fun_question': funQuestion,
        'notes': notes,
        'images': photoBase64 != null ? ['data:image/jpeg;base64,$photoBase64'] : [],
        'timestamp': timestamp.toIso8601String(),
      };

  factory PitResult.fromJson(Map<String, dynamic> json) => PitResult(
        id: json['id'],
        scouterName: json['scouter_name'] ?? '',
        secretTeamKey: json['secret_team_key'] ?? '',
        eventKey: json['event_key'] ?? '',
        teamNumber: json['team_number'] ?? 0,
        driveTrain: json['drive_train'] ?? 'Swerve',
        driveTrainOther: json['drive_train_other'] ?? '',
        groundPickup: json['ground_pickup'] ?? false,
        humanPlayerPickup: json['human_player_pickup'] ?? false,
        fuelCapacity: json['fuel_capacity'] ?? 0,
        autoStartingSpot: json['auto_starting_spot'] ?? 'Left',
        autoStartLeftTrench: json['auto_start_left_trench'] ?? false,
        autoStartLeftBump: json['auto_start_left_bump'] ?? false,
        autoStartHub: json['auto_start_hub'] ?? false,
        autoStartRightBump: json['auto_start_right_bump'] ?? false,
        autoStartRightTrench: json['auto_start_right_trench'] ?? false,
        autoCrashConcern: json['auto_crash_concern'] ?? false,
        autoHang: json['auto_hang'] ?? false,
        autoNotes: json['auto_notes'] ?? '',
        hangingWorks: json['hanging_works'] ?? false,
        hangingLevel: json['hanging_level'] ?? 1,
        hangingTime: json['hanging_time'] ?? '',
        hangingHow: json['hanging_how'] ?? '',
        teleopActivePlan: json['teleop_active_plan'] ?? '',
        teleopInactivePlan: json['teleop_inactive_plan'] ?? '',
        willingToPlayDefense: json['willing_to_play_defense'] ?? false,
        ratherPlayDefense: json['rather_play_defense'] ?? false,
        shootOnMove: json['shoot_on_move'] ?? false,
        hopperEmptyTime: json['hopper_empty_time'] ?? '',
        funQuestion: json['fun_question'] ?? '',
        notes: json['notes'] ?? '',
        photoBase64: json['images'],
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
      );
}
