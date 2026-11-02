import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// US state and Canadian province outlines, plus North American lakes
/// (keys `lake:NAME`; state shapes include their lake waters), from
/// assets/maps.
class MapShapes {
  // Path units: x = longitude, y = -latitude.
  final Map<String, ({Path path, Rect bounds})> regions;
  MapShapes(this.regions);

  static Future<MapShapes>? _loading;
  static Future<MapShapes> load() => _loading ??= _load();

  static Future<MapShapes> _load() async {
    final json = jsonDecode(
        await rootBundle.loadString('assets/maps/us_ca_states.json')) as Map;
    final regions = <String, ({Path path, Rect bounds})>{};
    json.forEach((code, value) {
      final path = Path();
      for (final ring in (value['rings'] as List)) {
        final pts = (ring as List).cast<num>();
        path.moveTo(pts[0].toDouble(), -pts[1].toDouble());
        for (var i = 2; i < pts.length; i += 2) {
          path.lineTo(pts[i].toDouble(), -pts[i + 1].toDouble());
        }
        path.close();
      }
      regions[code as String] = (path: path, bounds: path.getBounds());
    });
    return MapShapes(regions);
  }
}

/// A place on the map, colored like its choice button.
class MapPoint {
  final double lat;
  final double lng;
  final Color color;
  final String label;
  const MapPoint(this.lat, this.lng, this.color, this.label);
}

/// The event's state (and its neighbors) with a colored dot per choice.
/// Once [revealed], the other dots fade away and the answer pulses.
class HometownMap extends StatefulWidget {
  final String? homeState;
  final List<MapPoint> points;
  final int answer;
  final bool revealed;

  const HometownMap({
    super.key,
    required this.homeState,
    required this.points,
    required this.answer,
    required this.revealed,
  });

  @override
  State<HometownMap> createState() => _HometownMapState();
}

class _HometownMapState extends State<HometownMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (widget.revealed) _pulse.repeat();
  }

  @override
  void didUpdateWidget(HometownMap old) {
    super.didUpdateWidget(old);
    if (widget.revealed && !old.revealed) {
      _pulse.repeat();
    } else if (!widget.revealed && old.revealed) {
      _pulse.reset();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// What to show, in degrees: the three dots with room around them (at
  /// least a couple of degrees, so the state's outline gives context), or
  /// the event's state when there are no dots.
  Rect _view(MapShapes shapes) {
    if (widget.points.isEmpty) {
      final home = shapes.regions[widget.homeState]?.bounds;
      if (home == null) return const Rect.fromLTRB(-125, 24, -66, 50);
      return Rect.fromLTRB(home.left, -home.bottom, home.right, -home.top);
    }
    var minLng = double.infinity, maxLng = -double.infinity;
    var minLat = double.infinity, maxLat = -double.infinity;
    for (final p in widget.points) {
      minLng = min(minLng, p.lng);
      maxLng = max(maxLng, p.lng);
      minLat = min(minLat, p.lat);
      maxLat = max(maxLat, p.lat);
    }
    final midLat = (minLat + maxLat) / 2;
    final midLng = (minLng + maxLng) / 2;
    final k = cos(midLat * pi / 180);
    final halfLat = max(1.5, (maxLat - minLat) * 0.7);
    final halfLng = max(1.5 / k, (maxLng - minLng) * 0.7);
    return Rect.fromLTRB(
        midLng - halfLng, midLat - halfLat, midLng + halfLng, midLat + halfLat);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MapShapes>(
      future: MapShapes.load(),
      builder: (context, snap) {
        final shapes = snap.data;
        if (shapes == null) return const SizedBox.expand();
        return LayoutBuilder(builder: (context, box) {
          final proj = _Projection(_view(shapes), box.biggest);
          final answer = widget.answer >= 0 &&
                  widget.answer < widget.points.length
              ? widget.points[widget.answer].label
              : null;
          return Semantics(
            container: true,
            image: true,
            label: widget.revealed && answer != null
                ? 'Map with $answer marked'
                : 'Map with the ${widget.points.length} choices marked',
            excludeSemantics: true,
            child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ShapesPainter(shapes, proj, widget.homeState,
                        Theme.of(context).colorScheme),
                  ),
                ),
                for (var i = 0; i < widget.points.length; i++)
                  if (i != widget.answer) _dot(proj, i),
                // The answer last, so it's on top.
                if (widget.answer >= 0 && widget.answer < widget.points.length)
                  _dot(proj, widget.answer),
              ],
            ),
          ),
          );
        });
      },
    );
  }

  Widget _dot(_Projection proj, int i) {
    final p = widget.points[i];
    final at = proj.project(p.lat, p.lng);
    final isAnswer = i == widget.answer;
    const size = 18.0;
    const ring = 64.0;
    return Positioned(
      left: at.dx - ring / 2,
      top: at.dy - ring / 2,
      width: ring,
      height: ring,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: widget.revealed && !isAnswer ? 0 : 1,
          duration: const Duration(milliseconds: 500),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (isAnswer && widget.revealed)
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    final t = _pulse.value;
                    final d = size + (ring - size) * t;
                    return Container(
                      width: d,
                      height: d,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: p.color.withValues(alpha: 1 - t), width: 3),
                      ),
                    );
                  },
                ),
              AnimatedScale(
                scale: isAnswer && widget.revealed ? 1.3 : 1,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: p.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(blurRadius: 3, color: Colors.black38),
                    ],
                  ),
                ),
              ),
              if (isAnswer && widget.revealed)
                Positioned(
                  bottom: ring / 2 + size / 2 + 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: p.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      p.label,
                      softWrap: false,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Equirectangular, squeezed by cos(latitude) so a state looks right.
class _Projection {
  final Rect view;
  final double _sx, _sy, _ox, _oy;

  factory _Projection(Rect view, Size size) {
    final k = cos((view.top + view.bottom) / 2 * pi / 180);
    final s = min(size.width / (view.width * k), size.height / view.height);
    return _Projection._(view, s * k, s, (size.width - view.width * k * s) / 2,
        (size.height - view.height * s) / 2);
  }
  _Projection._(this.view, this._sx, this._sy, this._ox, this._oy);

  Offset project(double lat, double lng) =>
      Offset(_ox + (lng - view.left) * _sx, _oy + (view.bottom - lat) * _sy);

  /// Path units (lng, -lat) to screen.
  Matrix4 get matrix => Matrix4.identity()
    ..translateByDouble(_ox - view.left * _sx, _oy + view.bottom * _sy, 0, 1)
    ..scaleByDouble(_sx, _sy, 1, 1);

  @override
  bool operator ==(Object other) =>
      other is _Projection &&
      other.view == view &&
      other._sx == _sx &&
      other._ox == _ox &&
      other._oy == _oy;

  @override
  int get hashCode => Object.hash(view, _sx, _ox, _oy);
}

class _ShapesPainter extends CustomPainter {
  final MapShapes shapes;
  final _Projection proj;
  final String? homeState;
  final ColorScheme scheme;

  _ShapesPainter(this.shapes, this.proj, this.homeState, this.scheme);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size,
        Paint()..color = scheme.surfaceContainerLow);
    final m = proj.matrix.storage;
    // Everything on screen, in path units.
    final topLeft = Offset(
        proj.view.left - proj.view.width, -proj.view.bottom - proj.view.height);
    final visible = Rect.fromLTWH(topLeft.dx, topLeft.dy,
        proj.view.width * 3, proj.view.height * 3);
    final water = Paint()..color = scheme.surfaceContainerLow;
    final land = Paint()..color = scheme.surfaceContainerHighest;
    final home = Paint()..color = scheme.primaryContainer;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = scheme.outline;
    // States first, then lakes over them.
    for (final lakes in [false, true]) {
      for (final entry in shapes.regions.entries) {
        if (entry.key.startsWith('lake:') != lakes) continue;
        if (!entry.value.bounds.overlaps(visible)) continue;
        final path = entry.value.path.transform(m);
        canvas.drawPath(
            path, lakes ? water : (entry.key == homeState ? home : land));
        canvas.drawPath(path, edge);
      }
    }
  }

  @override
  bool shouldRepaint(_ShapesPainter old) =>
      old.proj != proj || old.homeState != homeState || old.scheme != scheme;
}
