import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/game_score.dart';
import '../models/tba_team.dart';
import '../providers/app_state_provider.dart';
import '../services/api_service.dart';
import 'nav_drawer.dart';

const _maxStrikes = 3;
const _startSeconds = 10.0;
// The clock halves every this many correct answers...
const _correctPerSpeedUp = 20;
// ...this many times: 10 → 5 → 2.5 → 1.25 → 0.625 s, then stays there.
const _maxSpeedUps = 4;

enum _Phase { intro, playing, over }

class _Question {
  final TbaTeam answer;
  final List<TbaTeam> options;
  final String? extra;
  _Question(this.answer, this.options, this.extra);
}

/// The question on screen, for a game's prompt.
class GuessRound {
  final TbaTeam answer;
  final List<TbaTeam> options;
  // From TeamGuessGame.prepare.
  final String? extra;
  // Null until answered; then the chosen option's index, or -1 on time out.
  final int? picked;
  GuessRound(this.answer, this.options, this.extra, this.picked);

  bool get revealed => picked != null;
}

/// The shared engine behind the team games: show something about a team,
/// pick it out of three choices before the clock runs out, three strikes
/// and you're out, then offer to publish to the team's leaderboard.
class TeamGuessGame extends StatefulWidget {
  /// Leaderboard id in the GameScores container, e.g. 'name-that-team'.
  final String gameId;
  final String title;
  final int navIndex;

  /// The first paragraph of the rules (the strikes and timer are added).
  final String rules;

  /// Why the game can't be played yet (beyond the event and its team list),
  /// or null when it can.
  final String? Function(AppStateProvider appState)? blocker;

  /// Teams that can be the answer.
  final List<TbaTeam> Function(AppStateProvider appState) answers;

  /// Teams the two wrong choices come from; every named team by default.
  final List<TbaTeam> Function(AppStateProvider appState)? decoys;

  /// Whether [candidate] makes a good wrong choice next to [chosen] (the
  /// answer first). Ignored when too few teams pass.
  final bool Function(TbaTeam candidate, List<TbaTeam> chosen)? decoyFilter;

  /// Shown before a choice's text, e.g. its color on a map.
  final Widget Function(int index)? optionLeading;

  /// Wait for a Next button after each answer instead of moving on.
  final bool nextButton;

  /// Text on a choice button.
  final String Function(TbaTeam team) optionText;

  /// Gets a question about [team] ready before it's shown (e.g. loads its
  /// photo) and returns what [prompt] needs, or null to skip the team.
  final Future<String?> Function(BuildContext context, TbaTeam team)? prepare;

  /// What's shown above the choices.
  final Widget Function(BuildContext context, GuessRound round) prompt;

  const TeamGuessGame({
    super.key,
    required this.gameId,
    required this.title,
    required this.navIndex,
    required this.rules,
    required this.answers,
    required this.optionText,
    required this.prompt,
    this.blocker,
    this.prepare,
    this.decoys,
    this.decoyFilter,
    this.optionLeading,
    this.nextButton = false,
  });

  @override
  State<TeamGuessGame> createState() => _TeamGuessGameState();
}

class _TeamGuessGameState extends State<TeamGuessGame>
    with SingleTickerProviderStateMixin {
  final _rng = Random();
  late final AnimationController _clock;

  _Phase _phase = _Phase.intro;
  int _correct = 0;
  int _strikes = 0;
  // Bumped every game and question so stale delays do nothing.
  int _round = 0;

  _Question? _question;
  // The question after this one, being prepared while this one is played.
  Future<_Question?>? _upcoming;
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
            _question != null &&
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
          .getGameScores(secretKey: secretKey, game: widget.gameId);
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

  /// Teams with a name, for decoys.
  List<TbaTeam> _named(AppStateProvider appState) =>
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
      _question = null;
      _round++;
    });
    _upcoming = _prepareQuestion(null);
    _next();
  }

  /// A question whose answer isn't [exclude], or null if none can be made.
  Future<_Question?> _prepareQuestion(TbaTeam? exclude) async {
    final appState = context.read<AppStateProvider>();
    final named = widget.decoys?.call(appState) ?? _named(appState);
    final pool = widget.answers(appState)
        .where((t) => t.teamNumber != exclude?.teamNumber)
        .toList()
      ..shuffle(_rng);
    // A few tries, in case a team's photo won't load.
    for (final answer in pool.take(5)) {
      String? extra;
      if (widget.prepare != null) {
        extra = await widget.prepare!(context, answer);
        if (!mounted) return null;
        if (extra == null) continue;
      }
      final shuffled = named.toList()..shuffle(_rng);
      List<TbaTeam> pickDecoys(bool filtered) {
        final decoys = <TbaTeam>[];
        final labels = {widget.optionText(answer).trim().toLowerCase()};
        for (final t in shuffled) {
          if (decoys.length == 2) break;
          if (t.teamNumber == answer.teamNumber) continue;
          if (labels.contains(widget.optionText(t).trim().toLowerCase())) {
            continue;
          }
          if (filtered && !widget.decoyFilter!(t, [answer, ...decoys])) {
            continue;
          }
          labels.add(widget.optionText(t).trim().toLowerCase());
          decoys.add(t);
        }
        return decoys;
      }
      var decoys = widget.decoyFilter == null ? <TbaTeam>[] : pickDecoys(true);
      if (decoys.length < 2) decoys = pickDecoys(false);
      if (decoys.length < 2) return null;
      return _Question(answer, [answer, ...decoys]..shuffle(_rng), extra);
    }
    return null;
  }

  Future<void> _next() async {
    final round = ++_round;
    final q = await _upcoming;
    if (!mounted || round != _round || _phase != _Phase.playing) return;
    if (q == null) {
      setState(() => _phase = _Phase.intro);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Couldn\'t set up the next question.')));
      return;
    }
    _upcoming = _prepareQuestion(q.answer);
    setState(() {
      _question = q;
      _picked = null;
    });
    _clock
      ..duration = _timeLimit
      ..forward(from: 0);
  }

  /// [pick] is the chosen option's index, or -1 when time ran out.
  void _resolve(int pick) {
    final q = _question;
    if (_picked != null || q == null) return;
    _clock.stop();
    final right = pick >= 0 && q.options[pick] == q.answer;
    setState(() {
      _picked = pick;
      if (right) {
        _correct++;
      } else {
        _strikes++;
      }
    });
    if (widget.nextButton) return;
    final round = _round;
    Future.delayed(Duration(milliseconds: right ? 300 : 1200), () {
      if (!mounted || round != _round || _phase != _Phase.playing) return;
      _advance();
    });
  }

  void _advance() {
    if (_strikes >= _maxStrikes) {
      _gameOver();
    } else {
      _next();
    }
  }

  Future<void> _gameOver() async {
    setState(() {
      _phase = _Phase.over;
      _upcoming = null;
    });
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
        game: widget.gameId,
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
    final named = _named(appState);
    final eventKey = appState.settings.selectedEventKey ?? '';
    final blocked = widget.blocker?.call(appState);

    final Widget body;
    if (eventKey.isEmpty) {
      body = _message('Pick an event in Settings to play.');
    } else if (named.length < 3) {
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
    } else if (blocked != null) {
      body = _message(blocked);
    } else {
      body = _lobby(context, widget.answers(appState).length);
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      drawer: NavDrawer(selectedIndex: widget.navIndex),
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
                '${widget.rules} You get $_maxStrikes '
                'strikes: a wrong pick or running out of time.\n\n'
                'You start with ${_startSeconds.toStringAsFixed(0)} seconds a team. '
                'Every $_correctPerSpeedUp right answers, the time halves.\n\n'
                '$teamCount teams in the game.',
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
            Semantics(
              header: true,
              child: Text('Leaderboard', style: theme.textTheme.titleMedium),
            ),
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
      rows.add(Semantics(
        label: 'Place $place, ${s.player}${mine ? ' (you)' : ''}, '
            '${s.score} correct${s.eventKey.isEmpty ? '' : ', at ${s.eventKey}'}',
        excludeSemantics: true,
        child: Padding(
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
      )));
    }
    return rows;
  }

  static String _secondsText(double secs) => secs < 1
      ? secs.toStringAsFixed(2)
      : secs.toStringAsFixed(secs == secs.roundToDouble() ? 0 : 1);

  String _resultText(_Question q) {
    final right = widget.optionText(q.answer);
    if (_picked == -1) return 'Time\'s up. It\'s $right.';
    if (q.options[_picked!] == q.answer) return 'Right!';
    return 'Wrong. It\'s $right.';
  }

  Widget _playing(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final secs = _timeLimit.inMilliseconds / 1000;
    final q = _question;

    Widget option(int i) {
      final team = q!.options[i];
      final revealed = _picked != null;
      final isAnswer = team == q.answer;
      Color? bg;
      Color? fg;
      if (revealed && isAnswer) {
        bg = Colors.green.shade600;
        fg = Colors.white;
      } else if (revealed && i == _picked) {
        bg = scheme.error;
        fg = scheme.onError;
      }
      final mark = !revealed
          ? null
          : isAnswer
              ? 'right answer'
              : i == _picked
                  ? 'your pick, wrong'
                  : null;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Semantics(
          label: mark == null
              ? widget.optionText(team)
              : '${widget.optionText(team)}, $mark',
          excludeSemantics: true,
          button: true,
          enabled: !revealed,
          onTap: revealed ? null : () => _resolve(i),
          child: SizedBox(
          height: 56,
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              disabledBackgroundColor: bg,
              disabledForegroundColor: fg,
            ),
            onPressed: revealed ? null : () => _resolve(i),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.optionLeading != null) ...[
                  widget.optionLeading!(i),
                  const SizedBox(width: 12),
                ],
                Flexible(
                  child: Text(
                    widget.optionText(team),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                if (revealed && (isAnswer || i == _picked)) ...[
                  const SizedBox(width: 12),
                  Icon(isAnswer ? Icons.check_circle : Icons.cancel, size: 22),
                ],
              ],
            ),
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
              Semantics(
                container: true,
                child: Text('$_correct correct',
                    style: theme.textTheme.titleLarge),
              ),
              const Spacer(),
              Semantics(
                container: true,
                label: '$_strikes of $_maxStrikes strikes',
                excludeSemantics: true,
                child: Row(children: [
                  for (var i = 0; i < _maxStrikes; i++)
                    Icon(
                      i < _strikes ? Icons.close : Icons.circle_outlined,
                      size: 28,
                      color: i < _strikes ? scheme.error : scheme.outlineVariant,
                    ),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            Semantics(
              label: '${_secondsText(secs)} seconds per team',
              excludeSemantics: true,
              child: Row(children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: _clock,
                  builder: (context, _) => LinearProgressIndicator(
                    value: q == null ? 1 : 1 - _clock.value,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${_secondsText(secs)} s',
                  style: theme.textTheme.bodyMedium),
            ]),
            ),
            const SizedBox(height: 24),
            if (q == null)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(
                  child: CircularProgressIndicator(
                      semanticsLabel: 'Loading the next question'),
                ),
              )
            else ...[
              Semantics(
                liveRegion: true,
                container: true,
                child: widget.prompt(
                    context, GuessRound(q.answer, q.options, q.extra, _picked)),
              ),
              if (_picked != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _resultText(q),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: _picked! >= 0 && q.options[_picked!] == q.answer
                              ? null
                              : scheme.error),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              for (var i = 0; i < q.options.length; i++) option(i),
              if (widget.nextButton && _picked != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: FilledButton.icon(
                    onPressed: _advance,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(_strikes >= _maxStrikes ? 'Finish' : 'Next'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
