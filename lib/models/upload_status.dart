/// Failed upload tries for one held record, kept beside (not inside) the
/// record so it never gets posted to the API.
class UploadStatus {
  final int attempts;
  final String lastError;
  final DateTime lastAttempt;

  UploadStatus(
      {required this.attempts, required this.lastError, required this.lastAttempt});

  Map<String, dynamic> toJson() => {
        'attempts': attempts,
        'last_error': lastError,
        'last_attempt': lastAttempt.toIso8601String(),
      };

  factory UploadStatus.fromJson(Map<String, dynamic> json) => UploadStatus(
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        lastError: json['last_error'] ?? '',
        lastAttempt:
            DateTime.tryParse(json['last_attempt'] ?? '') ?? DateTime.now(),
      );
}
