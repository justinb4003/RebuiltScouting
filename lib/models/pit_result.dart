import 'package:uuid/uuid.dart';

class PitResult {
  final String id;
  final String scouterName;
  final String secretTeamKey;
  final String eventKey;
  final int teamNumber;
  String driveTrain; // Swerve, Tank, Mecanum, Other
  List<String> wheelTypes; // omni, mecanum, inflated, solid
  int robotRating; // -10 to +10
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
    List<String>? wheelTypes,
    this.robotRating = 0,
    this.notes = '',
    this.photoBase64,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        wheelTypes = wheelTypes ?? [],
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'scouter_name': scouterName,
        'secret_team_key': secretTeamKey,
        'event_key': eventKey,
        'team_number': teamNumber,
        'drive_train': driveTrain,
        'wheel_types': wheelTypes,
        'robot_rating': robotRating,
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
        wheelTypes: List<String>.from(json['wheel_types'] ?? []),
        robotRating: json['robot_rating'] ?? 0,
        notes: json['notes'] ?? '',
        photoBase64: json['photo_base64'],
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
      );
}
