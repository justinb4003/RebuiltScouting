/// One published score on a game's leaderboard (GameScores container,
/// per secret key, across all events).
class GameScore {
  final String id;
  final String game;
  final String player;
  final int score;
  final String eventKey;
  final DateTime? createdAt;

  GameScore({
    required this.id,
    required this.game,
    required this.player,
    required this.score,
    required this.eventKey,
    this.createdAt,
  });

  factory GameScore.fromJson(Map<String, dynamic> json) => GameScore(
        id: json['id'] ?? '',
        game: json['game'] ?? '',
        player: json['player'] ?? '',
        score: (json['score'] as num?)?.toInt() ?? 0,
        eventKey: json['event_key'] ?? '',
        createdAt: DateTime.tryParse(json['created_at'] ?? ''),
      );
}
