import 'package:flutter/material.dart';

class HighlightedSwitch extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool dense;

  const HighlightedSwitch({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: value
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SwitchListTile(
        title: Text(title),
        value: value,
        dense: dense,
        contentPadding: dense ? const EdgeInsets.only(left: 32, right: 16) : null,
        onChanged: onChanged,
      ),
    );
  }
}
