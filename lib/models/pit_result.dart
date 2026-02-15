import 'package:uuid/uuid.dart';

class PitResult {
  final String id;
  final String scouterName;
  final String secretTeamKey;
  final String eventKey;
  final int teamNumber;
  String driveTrain; // Swerve, Tank, Mecanum, Other
  String driveTrainOther;
  bool canCrossRamp;
  bool canEnterTrench;
  bool groundPickup;
  bool humanPlayerPickup;
  int fuelCapacity;
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
    this.canCrossRamp = false,
    this.canEnterTrench = false,
    this.groundPickup = false,
    this.humanPlayerPickup = false,
    this.fuelCapacity = 0,
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
        'can_cross_ramp': canCrossRamp,
        'can_enter_trench': canEnterTrench,
        'ground_pickup': groundPickup,
        'human_player_pickup': humanPlayerPickup,
        'fuel_capacity': fuelCapacity,
        'notes': notes,
        'photo_base64': photoBase64,
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
        canCrossRamp: json['can_cross_ramp'] ?? false,
        canEnterTrench: json['can_enter_trench'] ?? false,
        groundPickup: json['ground_pickup'] ?? false,
        humanPlayerPickup: json['human_player_pickup'] ?? false,
        fuelCapacity: json['fuel_capacity'] ?? 0,
        notes: json['notes'] ?? '',
        photoBase64: json['photo_base64'],
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
      );
}
