import 'package:flutter/material.dart';

class FixedSegmentedButton<T extends Object> extends StatelessWidget {
  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;

  const FixedSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      expandedInsets: EdgeInsets.zero,
      segments: segments,
      selected: selected,
      onSelectionChanged: onSelectionChanged,
    );
  }
}
