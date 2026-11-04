import 'dart:async';
import 'package:flutter/material.dart';
import '../models/slack_link.dart';
import '../services/api_service.dart';
import '../services/browser.dart';

/// Runs a Sign in with Slack for the team with [secretKey] and [teamNumber]
/// (the API uses that team's own Slack app): asks the API to start one, opens the Slack
/// page in another tab, then polls until the API has the result. Pops with a
/// [SlackLinkResult], or null if cancelled or it failed.
///
/// The app never receives Slack's redirect (an installed iPhone PWA opens
/// the page in Safari, a different storage context), so it polls instead.
Future<SlackLinkResult?> showSlackLinkDialog(BuildContext context, String secretKey, int teamNumber) {
  return showDialog<SlackLinkResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SlackLinkDialog(secretKey, teamNumber),
  );
}

class _SlackLinkDialog extends StatefulWidget {
  final String secretKey;
  final int teamNumber;
  const _SlackLinkDialog(this.secretKey, this.teamNumber);

  @override
  State<_SlackLinkDialog> createState() => _SlackLinkDialogState();
}

class _SlackLinkDialogState extends State<_SlackLinkDialog> {
  static const _interval = Duration(seconds: 2);
  static const _maxWait = Duration(minutes: 5);

  final _api = ApiService.instance;
  SlackLinkStart? _start;
  String? _error;
  Timer? _timer;
  bool _polling = false;
  bool _closed = false;
  final _clock = Stopwatch();

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _begin() async {
    try {
      final start = await _api.slackLinkStart(widget.secretKey, widget.teamNumber);
      if (_closed) return;
      setState(() => _start = start);
      openUrl(start.authorizeUrl, newTab: true);
      _clock.start();
      _timer = Timer.periodic(_interval, (_) => _poll());
    } on SlackNotConfigured {
      _fail("Slack linking isn't set up for team ${widget.teamNumber}.");
    } catch (e) {
      debugPrint('Slack link start failed: $e');
      _fail("Couldn't reach the server. Check your connection and try again.");
    }
  }

  Future<void> _poll() async {
    if (_closed || _polling) return;
    if (_clock.elapsed > _maxWait) {
      _fail('Timed out waiting for Slack. Try again.');
      return;
    }
    _polling = true;
    try {
      final r = await _api.slackLinkStatus(_start!.sessionId);
      if (_closed) return;
      if (r.status == 'done') {
        _timer?.cancel();
        _closed = true;
        if (!mounted) return;
        Navigator.pop(context, r.result);
      } else if (r.status == 'error') {
        _fail(r.error ?? 'Slack sign-in failed. Try again.');
      }
    } on SlackNotConfigured {
      _fail("Slack linking isn't set up for team ${widget.teamNumber}.");
    } catch (e) {
      // A dropped request is fine; the next poll tries again.
      debugPrint('Slack link poll failed: $e');
    } finally {
      _polling = false;
    }
  }

  void _fail(String message) {
    if (_closed) return;
    _timer?.cancel();
    setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return AlertDialog(
      title: const Text('Link Slack account'),
      content: error != null
          ? Text(error)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_start == null
                    ? 'Starting...'
                    : 'Finish signing in to Slack in the other tab, then '
                        'come back here. This closes by itself when it works.'),
                const SizedBox(height: 16),
                const LinearProgressIndicator(semanticsLabel: 'Waiting for Slack'),
              ],
            ),
      actions: [
        if (error == null && _start != null)
          TextButton(
            onPressed: () => openUrl(_start!.authorizeUrl, newTab: true),
            child: const Text('Open Slack again'),
          ),
        TextButton(
          onPressed: () {
            _closed = true;
            _timer?.cancel();
            Navigator.pop(context);
          },
          child: Text(error == null ? 'Cancel' : 'Close'),
        ),
      ],
    );
  }
}
