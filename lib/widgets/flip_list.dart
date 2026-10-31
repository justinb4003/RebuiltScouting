import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// How long a row takes to glide to its new spot. Deliberately slow so you
/// can follow a team moving up or down the board.
const flipMoveDuration = Duration(milliseconds: 1100);

/// How long a row that just appeared takes to fade in.
const flipFadeDuration = Duration(milliseconds: 1400);

/// How long the puff of smoke lasts when a row leaves.
const flipPoofDuration = Duration(milliseconds: 1600);

/// Wrap a non-scrolling, non-lazy layout (e.g. a Column) whose children are
/// [FlipItem]s. When the order changes each item glides from where it was to
/// where it is now; items that show up after the first frame fade in, and
/// items that leave go up in a puff of smoke where they last were.
/// Positions are measured relative to [child], so scrolling doesn't count as
/// moving. Width changes (window resizes) snap instead of animating.
class FlipScope extends StatefulWidget {
  final Widget child;

  const FlipScope({super.key, required this.child});

  @override
  State<FlipScope> createState() => _FlipScopeState();
}

class _FlipScopeState extends State<FlipScope> {
  bool _settled = false;
  bool _leaving = false;
  final _ghosts = <_Ghost>[];

  @override
  void initState() {
    super.initState();
    // Items built with the scope are the starting picture: no fade.
    SchedulerBinding.instance.addPostFrameCallback((_) => _settled = true);
  }

  @override
  void deactivate() {
    // The whole list is going (e.g. tab switch): no poofs.
    _leaving = true;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _leaving = false;
  }

  void _poof(_Ghost g) {
    if (_leaving) return;
    // Items leave while an ancestor of this scope rebuilds, so marking the
    // scope dirty now is allowed and it rebuilds in the same frame: the
    // ghost replaces the row with no blank frame in between.
    setState(() => _ghosts.add(g));
  }

  @override
  Widget build(BuildContext context) => _FlipScopeData(
    state: this,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        for (final g in _ghosts)
          Positioned(
            key: g.key,
            left: g.rect.left,
            top: g.rect.top,
            width: g.rect.width,
            height: g.rect.height,
            child: IgnorePointer(
              child: _Poof(
                onDone: () => setState(() => _ghosts.remove(g)),
                child: g.child,
              ),
            ),
          ),
      ],
    ),
  );
}

/// A row that just left, drawn where it was while it goes poof.
class _Ghost {
  final Key key = UniqueKey();
  final Rect rect;
  final Widget child;

  _Ghost(this.rect, this.child);
}

class _Poof extends StatefulWidget {
  final Widget child;
  final VoidCallback onDone;

  const _Poof({required this.child, required this.onDone});

  @override
  State<_Poof> createState() => _PoofState();
}

class _PoofState extends State<_Poof> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: flipPoofDuration)
        ..forward().whenComplete(() {
          if (mounted) widget.onDone();
        });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final smoke = Theme.of(context).colorScheme.onSurfaceVariant;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        // The row swells, blurs and fades in the first half...
        final row = Curves.easeOut.transform(math.min(1, t * 2));
        return CustomPaint(
          foregroundPainter: _SmokePainter(t, smoke),
          child: Opacity(
            opacity: 1 - row,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 16 * row, sigmaY: 16 * row),
              child: Transform.scale(scale: 1 + 0.3 * row, child: child),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// ...while puffs of smoke billow out along it and drift away.
class _SmokePainter extends CustomPainter {
  final double t;
  final Color color;

  _SmokePainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final grow = Curves.easeOutCubic.transform(t);
    final fade = (1 - t) * (t < 0.15 ? t / 0.15 : 1);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7 * fade)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final r = size.height * 0.45;
    const count = 9;
    for (var i = 0; i < count; i++) {
      final along = (i + 0.5) / count;
      // Fixed pseudo-random spread so every puff looks a little different.
      final angle = i * 2.4;
      final drift = Offset(math.cos(angle), math.sin(angle)) * r * 2.4 * grow;
      final center = Offset(size.width * along, size.height / 2) + drift;
      canvas.drawCircle(
        center,
        r * (0.4 + 0.8 * grow) * (0.8 + 0.4 * ((i * 7) % 3) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SmokePainter old) => old.t != t || old.color != color;
}

class _FlipScopeData extends InheritedWidget {
  final _FlipScopeState state;

  const _FlipScopeData({required this.state, required super.child});

  @override
  bool updateShouldNotify(_FlipScopeData old) => false;
}

/// One row inside a [FlipScope]. Needs a key that follows the thing it
/// shows (a team number, not a list index) so it's recognized after a move.
class FlipItem extends StatefulWidget {
  final Widget child;

  const FlipItem({required Key super.key, required this.child});

  @override
  State<FlipItem> createState() => _FlipItemState();
}

class _FlipItemState extends State<FlipItem> with TickerProviderStateMixin {
  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: flipMoveDuration,
  );
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: flipFadeDuration,
  );
  late final _FlipScopeState? _scope;

  double? _lastY;
  double? _lastWidth;
  Offset _lastPos = Offset.zero;
  Size _lastSize = Size.zero;
  double _fromDy = 0;

  double get _dy =>
      _fromDy * (1 - Curves.easeInOutCubic.transform(_move.value));

  @override
  void initState() {
    super.initState();
    _scope = context.getInheritedWidgetOfExactType<_FlipScopeData>()?.state;
    if (_scope?._settled == true) {
      _fade.forward();
    } else {
      _fade.value = 1;
    }
  }

  @override
  void deactivate() {
    if (_lastY != null) {
      _scope?._poof(
        _Ghost((_lastPos + Offset(0, _dy)) & _lastSize, widget.child),
      );
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _move.dispose();
    _fade.dispose();
    super.dispose();
  }

  /// Called while painting, once layout is final: start a glide if this row
  /// landed somewhere new. Returns the vertical offset to paint at.
  double _paintedAt(Offset pos, Size size, double width) {
    final y = pos.dy;
    _lastPos = pos;
    _lastSize = size;
    final lastY = _lastY;
    final moved = lastY != null && lastY != y && width == _lastWidth;
    if (moved) {
      // Keep it where it's drawn right now, then glide to zero.
      _fromDy = _dy + lastY - y;
      _move.value = 0; // no listener yet; we're mid-paint
      _move.forward();
    }
    _lastY = y;
    _lastWidth = width;
    return _dy;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _fade, curve: Curves.easeIn),
      child: _FlipPaint(item: this, child: widget.child),
    );
  }
}

class _FlipPaint extends SingleChildRenderObjectWidget {
  final _FlipItemState item;

  const _FlipPaint({required this.item, super.child});

  @override
  _RenderFlip createRenderObject(BuildContext context) => _RenderFlip(item);

  @override
  void updateRenderObject(BuildContext context, _RenderFlip renderObject) =>
      renderObject.item = item;
}

class _RenderFlip extends RenderProxyBox {
  _FlipItemState _item;

  _RenderFlip(this._item);

  set item(_FlipItemState v) {
    if (v == _item) return;
    _item._move.removeListener(markNeedsPaint);
    _item = v;
    if (attached) _item._move.addListener(markNeedsPaint);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _item._move.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _item._move.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final scopeBox = _item._scope?.context.findRenderObject();
    var dy = 0.0;
    if (scopeBox is RenderBox && scopeBox.attached) {
      final pos = localToGlobal(Offset.zero, ancestor: scopeBox);
      // Starting the glide must not repaint mid-paint.
      _item._move.removeListener(markNeedsPaint);
      dy = _item._paintedAt(pos, size, scopeBox.size.width);
      _item._move.addListener(markNeedsPaint);
    }
    super.paint(context, offset + Offset(0, dy));
  }
}
