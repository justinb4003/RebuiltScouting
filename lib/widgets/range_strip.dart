import 'package:flutter/material.dart';

/// A value in a dimension's own units: 2 decimals under 1, else 1.
String formatValue(double? v) => v == null ? '–' : v.toStringAsFixed(v.abs() < 1 ? 2 : 1);

class StripDot {
  final double value;
  final double size;
  final Color color;
  const StripDot(this.value, this.size, this.color);
}

/// One dimension drawn in real units across its range at the event (the
/// lowest and highest team, labelled at the ends): an event-average line,
/// an optional shaded band and dots painted in order (last on top).
class RangeStrip extends StatelessWidget {
  final double min;
  final double max;
  final double eventAvg;
  final (double, double)? band;
  final Color? bandColor;
  final double? tick;
  final List<StripDot> dots;

  const RangeStrip({
    super.key,
    required this.min,
    required this.max,
    required this.eventAvg,
    this.band,
    this.bandColor,
    this.tick,
    this.dots = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surface = theme.cardTheme.color ?? scheme.surface;
    final ends = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontSize: 10);
    final span = max - min;

    return Row(children: [
      SizedBox(width: 34, child: Text(formatValue(min), style: ends, textAlign: TextAlign.right)),
      const SizedBox(width: 8),
      Expanded(
        child: SizedBox(
          height: 14,
          child: LayoutBuilder(builder: (context, c) {
            const inset = 6.0;
            final w = c.maxWidth - inset * 2;
            double x(double v) => inset + (span > 0 ? ((v - min) / span).clamp(0.0, 1.0) * w : w / 2);
            return Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: inset,
                right: inset,
                top: 6.5,
                height: 1,
                child: ColoredBox(color: scheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              if (band != null)
                Positioned(
                  left: x(band!.$1) - 3,
                  width: x(band!.$2) - x(band!.$1) + 6,
                  top: 3,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: bandColor ?? scheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              Positioned(
                left: x(eventAvg) - 0.5,
                top: 0,
                bottom: 0,
                width: 1,
                child: ColoredBox(color: scheme.outline),
              ),
              if (tick != null)
                Positioned(
                  left: x(tick!) - 1,
                  top: 1,
                  bottom: 1,
                  width: 2,
                  child: ColoredBox(color: scheme.onSurface),
                ),
              for (final d in dots)
                Positioned(
                  left: x(d.value) - d.size / 2,
                  top: 7 - d.size / 2,
                  width: d.size,
                  height: d.size,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: d.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: surface, width: 1.5),
                    ),
                  ),
                ),
            ]);
          }),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(width: 34, child: Text(formatValue(max), style: ends)),
    ]);
  }
}

/// Legend swatches for [RangeStrip] marks.
class StripLegend extends StatelessWidget {
  final List<(Widget, String)> items;
  const StripLegend(this.items, {super.key});

  static Widget dot(Color c, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  static Widget line(Color c, double width) => Container(width: width, height: 12, color: c);

  static Widget band(Color c) => Container(
        width: 16,
        height: 8,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Wrap(spacing: 14, runSpacing: 4, children: [
      for (final (mark, label) in items)
        Row(mainAxisSize: MainAxisSize.min, children: [mark, const SizedBox(width: 4), Text(label, style: style)]),
    ]);
  }
}
