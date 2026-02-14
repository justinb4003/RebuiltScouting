import 'package:flutter/material.dart';

class CounterButton extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool showBulkButtons;
  final VoidCallback? onIncrement;

  const CounterButton({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.showBulkButtons = false,
    this.onIncrement,
  });

  void _change(int newValue) {
    final clamped = newValue.clamp(min, max);
    if (clamped != value) {
      onChanged(clamped);
      if (clamped > value) {
        onIncrement?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonal(
              onPressed: value > min ? () => _change(value - 1) : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.remove),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '$value',
                style: theme.textTheme.headlineSmall,
              ),
            ),
            FilledButton.tonal(
              onPressed: value < max ? () => _change(value + 1) : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.add),
            ),
            if (showBulkButtons) ...[
              const SizedBox(width: 4),
              FilledButton(
                onPressed: value + 5 <= max ? () => _change(value + 5) : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('+5'),
              ),
              FilledButton(
                onPressed: value + 10 <= max ? () => _change(value + 10) : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('+10'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
