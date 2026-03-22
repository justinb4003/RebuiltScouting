import 'package:uuid/uuid.dart';

class RobotNote {
  final String id;
  final String scouterName;
  final String secretTeamKey;
  final String eventKey;
  final int teamNumber;
  final String notes;
  final DateTime timestamp;

  RobotNote({
    String? id,
    required this.scouterName,
    required this.secretTeamKey,
    required this.eventKey,
    required this.teamNumber,
    required this.notes,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'scouter_name': scouterName,
        'secret_team_key': secretTeamKey,
        'event_key': eventKey,
        'team_number': teamNumber,
        'notes': notes,
        'timestamp': timestamp.toIso8601String(),
      };

  factory RobotNote.fromJson(Map<String, dynamic> json) => RobotNote(
        id: json['id'],
        scouterName: json['scouter_name'] ?? '',
        secretTeamKey: json['secret_team_key'] ?? '',
        eventKey: json['event_key'] ?? '',
        teamNumber: json['team_number'] ?? 0,
        notes: json['notes'] ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
      );
}
