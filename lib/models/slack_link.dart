/// Thrown when the team has no Slack set up on the API (HTTP 503).
class SlackNotConfigured implements Exception {
  @override
  String toString() => "Slack linking isn't set up for your team";
}

class SlackLinkStart {
  final String sessionId;
  final String authorizeUrl;
  const SlackLinkStart(this.sessionId, this.authorizeUrl);

  factory SlackLinkStart.fromJson(Map<String, dynamic> j) =>
      SlackLinkStart(j['session_id'] as String, j['authorize_url'] as String);
}

/// What a finished Slack sign-in hands the app.
class SlackLinkResult {
  final String slackUserId;
  final String slackTeamId;
  final String slackName;
  final String linkToken;
  const SlackLinkResult({
    required this.slackUserId,
    required this.slackTeamId,
    required this.slackName,
    required this.linkToken,
  });
}

/// One poll answer: [status] is 'pending', 'done' (with [result]) or 'error'.
class SlackLinkStatus {
  final String status;
  final SlackLinkResult? result;
  final String? error;
  const SlackLinkStatus(this.status, {this.result, this.error});

  factory SlackLinkStatus.fromJson(Map<String, dynamic> j) {
    final status = (j['status'] ?? 'error').toString();
    if (status == 'done') {
      return SlackLinkStatus(
        status,
        result: SlackLinkResult(
          slackUserId: j['slack_user_id'] as String,
          slackTeamId: j['slack_team_id'] as String,
          slackName: j['slack_name'] as String,
          linkToken: j['link_token'] as String,
        ),
      );
    }
    return SlackLinkStatus(status, error: j['error']?.toString());
  }
}
