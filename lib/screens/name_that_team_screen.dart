import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/game_score.dart';
import '../models/tba_team.dart';
import '../providers/app_state_provider.dart';
import '../services/api_service.dart';
import '../widgets/nav_drawer.dart';

/// Leaderboard id for this game in the GameScores container.
const _gameId = 'name-that-team';
const _maxStrikes = 3;
const _startSeconds = 10.0;
// The clock halves every this many correct answers...
const _correctPerSpeedUp = 20;
// ...this many times: 10 → 5 → 2.5 → 1.25 → 0.625 s, then stays there.
const _maxSpeedUps = 4;

enum _Phase { intro, playing, over }

/// Name That Team: a team number, three team names, pick the right one
/// before the clock runs out. Three strikes and you're out.
class NameThatTeamScreen extends StatefulWidget {
  const NameThatTeamScreen({super.key});

  @override
  State<NameThatTeamScreen> createState() => _NameThatTeamScreenState();
}

class _NameThatTeamScreenState extends State<NameThatTeamScreen>
    with SingleTickerProviderStateMixin {
  final _rng = Random();
  late final AnimationController _clock;

  _Phase _phase = _Phase.intro;
  int _correct = 0;
  int _strikes = 0;
  // Bumped every question so a stale "next question" delay does nothing.
  int _round = 0;

  TbaTeam? _answer;
  List<TbaTeam> _options = [];
  // Set once the question is answered (or timed out): the pick, or -1.
  int? _picked;

  List<GameScore>? _scores;
  String? _scoresError;
  String? _publishedId;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed &&
            _phase == _Phase.playing &&
            _picked == null) {
          _resolve(-1);
        }
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadScores());
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  Future<void> _loadScores() async {
    final secretKey =
        context.read<AppStateProvider>().settings.secretTeamKey.trim();
    if (secretKey.isEmpty) return;
    try {
      final scores = await ApiService.instance
          .getGameScores(secretKey: secretKey, game: _gameId);
      if (!mounted) return;
      setState(() {
        _scores = scores;
        _scoresError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _scoresError = 'Couldn\'t load the leaderboard.');
    }
  }

  /// Teams with a name; the game needs at least three of them.
  List<TbaTeam> _teams(AppStateProvider appState) =>
      appState.teams.where((t) => t.nickname.trim().isNotEmpty).toList();

  Duration get _timeLimit {
    final speedUps = min(_correct ~/ _correctPerSpeedUp, _maxSpeedUps);
    return Duration(
        milliseconds: (_startSeconds * 1000 / (1 << speedUps)).round());
  }

  void _start() {
    setState(() {
      _phase = _Phase.playing;
      _correct = 0;
      _strikes = 0;
      _publishedId = null;
      _answer = null;
    });
    _next();
  }

  void _next() {
    final teams = _teams(context.read<AppStateProvider>());
    // A different team from the last one.
    final pool = teams.where((t) => t != _answer).toList();
    final answer = pool[_rng.nextInt(pool.length)];
    final decoys = <TbaTeam>[];
    final names = {answer.nickname.trim().toLowerCase()};
    for (final t in teams.toList()..shuffle(_rng)) {
      if (decoys.length == 2) break;
      if (names.add(t.nickname.trim().toLowerCase())) decoys.add(t);
    }
    setState(() {
      _round++;
      _answer = answer;
      _options = [answer, ...decoys]..shuffle(_rng);
      _picked = null;
    });
    _clock
      ..duration = _timeLimit
      ..forward(from: 0);
  }

  /// [pick] is the chosen option's index, or -1 when time ran out.
  void _resolve(int pick) {
    if (_picked != null) return;
    _clock.stop();
    final right = pick >= 0 && _options[pick] == _answer;
    setState(() {
      _picked = pick;
      if (right) {
        _correct++;
      } else {
        _strikes++;
      }
    });
    final round = _round;
    Future.delayed(Duration(milliseconds: right ? 300 : 1200), () {
      if (!mounted || round != _round || _phase != _Phase.playing) return;
      if (_strikes >= _maxStrikes) {
        _gameOver();
      } else {
        _next();
      }
    });
  }

  Future<void> _gameOver() async {
    setState(() => _phase = _Phase.over);
    await _loadScores();
    if (!mounted) return;
    final settings = context.read<AppStateProvider>().settings;
    final player = settings.scouterName.trim();
    final secretKey = settings.secretTeamKey.trim();
    final score = _correct;
    final scores = _scores;

    final String placeText;
    if (scores == null) {
      placeText = 'The leaderboard didn\'t load, so your place isn\'t known.';
    } else {
      final place = 1 + scores.where((s) => s.score > score).length;
      placeText = 'You\'d be #$place of ${scores.length + 1} '
          'on your team\'s leaderboard.';
    }
    final canPublish = player.isNotEmpty && secretKey.isNotEmpty;

    final publish = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Game over'),
        content: Text(
          '$score correct. $placeText\n\n'
          '${canPublish ? 'Publish your score as $player?' : 'Set your scouter name and secret team key in Settings to publish scores.'}',
        ),
        actions: canPublish
            ? [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Not now'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Publish'),
                ),
              ]
            : [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('OK'),
                ),
              ],
      ),
    );
    if (publish == true && mounted) await _publish(player, secretKey, score);
  }

  Future<void> _publish(String player, String secretKey, int score) async {
    final eventKey =
        context.read<AppStateProvider>().settings.selectedEventKey ?? '';
    final id = const Uuid().v4();
    try {
      await ApiService.instance.postGameScore(
        id: id,
        secretKey: secretKey,
        game: _gameId,
        player: player,
        score: score,
        eventKey: eventKey,
      );
      if (!mounted) return;
      setState(() => _publishedId = id);
      await _loadScores();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t publish your score: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final teams = _teams(appState);
    final eventKey = appState.settings.selectedEventKey ?? '';

    final Widget body;
    if (eventKey.isEmpty) {
      body = _message('Pick an event in Settings to play.');
    } else if (teams.length < 3) {
      body = _message(
        appState.loading
            ? 'Loading teams…'
            : 'This game needs the event\'s team list (at least 3 teams).',
        action: appState.loading
            ? null
            : FilledButton.tonal(
                onPressed: appState.loadTeams,
                child: const Text('Load teams'),
              ),
      );
    } else if (_phase == _Phase.playing) {
      body = _playing(context);
    } else {
      body = _lobby(context, teams.length);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Name That Team')),
      drawer: const NavDrawer(selectedIndex: 14),
      body: SafeArea(child: body),
    );
  }

  Widget _message(String text, {Widget? action}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 16), action],
            ],
          ),
        ),
      );

  /// Before the first game and after each one: rules or last score,
  /// Start, and the leaderboard.
  Widget _lobby(BuildContext context, int teamCount) {
    final theme = Theme.of(context);
    final over = _phase == _Phase.over;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (over) ...[
              Text('$_correct correct',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
            ] else
              Text(
                'A team number comes up with three team names. Pick the '
                'right one before time runs out. You get $_maxStrikes '
                'strikes: a wrong pick or running out of time.\n\n'
                'You start with ${_startSeconds.toStringAsFixed(0)} seconds a team. '
                'Every $_correctPerSpeedUp right answers, the time halves.\n\n'
                '$teamCount teams at this event.',
                style: theme.textTheme.bodyLarge,
              ),
            const SizedBox(height: 24),
            Center(
              child: FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow),
                label: Text(over ? 'Play again' : 'Start'),
              ),
            ),
            const SizedBox(height: 32),
            Text('Leaderboard', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._leaderboard(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _leaderboard(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final secretKey =
        context.read<AppStateProvider>().settings.secretTeamKey.trim();
    if (secretKey.isEmpty) {
      return [Text('Set your secret team key in Settings to see it.', style: muted)];
    }
    if (_scoresError != null && _scores == null) {
      return [Text(_scoresError!, style: muted)];
    }
    final scores = _scores;
    if (scores == null) return [Text('Loading…', style: muted)];
    if (scores.isEmpty) return [Text('No scores yet.', style: muted)];
    final rows = <Widget>[];
    for (var i = 0; i < scores.length && i < 25; i++) {
      final s = scores[i];
      // Ties share a place.
      final place = 1 + scores.where((o) => o.score > s.score).length;
      final mine = s.id == _publishedId;
      final style = mine
          ? theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold, color: theme.colorScheme.primary)
          : theme.textTheme.bodyLarge;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 40, child: Text('#$place', style: style)),
          Expanded(child: Text(s.player, style: style)),
          if (s.eventKey.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(s.eventKey, style: muted),
            ),
          SizedBox(
            width: 48,
            child: Text('${s.score}', textAlign: TextAlign.right, style: style),
          ),
        ]),
      ));
    }
    return rows;
  }

  Widget _playing(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final secs = _timeLimit.inMilliseconds / 1000;
    final answer = _answer!;

    Widget option(int i) {
      final team = _options[i];
      final revealed = _picked != null;
      final isAnswer = team == answer;
      Color? bg;
      Color? fg;
      if (revealed && isAnswer) {
        bg = Colors.green.shade600;
        fg = Colors.white;
      } else if (revealed && i == _picked) {
        bg = scheme.error;
        fg = scheme.onError;
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          height: 64,
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              disabledBackgroundColor: bg,
              disabledForegroundColor: fg,
            ),
            onPressed: revealed ? null : () => _resolve(i),
            child: Text(
              team.nickname,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(children: [
              Text('$_correct correct', style: theme.textTheme.titleLarge),
              const Spacer(),
              for (var i = 0; i < _maxStrikes; i++)
                Icon(
                  Icons.close,
                  size: 28,
                  color: i < _strikes ? scheme.error : scheme.outlineVariant,
                ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: _clock,
                  builder: (context, _) => LinearProgressIndicator(
                    value: 1 - _clock.value,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${secs < 1 ? secs.toStringAsFixed(2) : secs.toStringAsFixed(secs == secs.roundToDouble() ? 0 : 1)} s',
                  style: theme.textTheme.bodyMedium),
            ]),
            const SizedBox(height: 32),
            Text(
              '${answer.teamNumber}',
              textAlign: TextAlign.center,
              style: theme.textTheme.displayLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_picked == -1)
              Text("Time's up",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: scheme.error)),
            const SizedBox(height: 24),
            for (var i = 0; i < _options.length; i++) option(i),
          ],
        ),
      ),
    );
  }
}
