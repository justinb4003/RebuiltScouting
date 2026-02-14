import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CounterButton extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool showBulkButtons;
  final VoidCallback? onTap;
  final bool enableHaptic;

  const CounterButton({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.showBulkButtons = false,
    this.onTap,
    this.enableHaptic = true,
  });

  void _change(int newValue) {
    final clamped = newValue.clamp(min, max);
    if (clamped != value) {
      onChanged(clamped);
      if (enableHaptic) HapticFeedback.lightImpact();
      onTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const btnSize = Size(56, 56);
    const bulkBtnSize = Size(64, 48);

    return Column(
      children: [
        Text(label, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.tonal(
              onPressed: value > min ? () => _change(value - 1) : null,
              style: FilledButton.styleFrom(
                minimumSize: btnSize,
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.remove, size: 28),
            ),
            SizedBox(
              width: 80,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            FilledButton.tonal(
              onPressed: value < max ? () => _change(value + 1) : null,
              style: FilledButton.styleFrom(
                minimumSize: btnSize,
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.add, size: 28),
            ),
          ],
        ),
        if (showBulkButtons) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton(
                onPressed:
                    value + 5 <= max ? () => _change(value + 5) : null,
                style: FilledButton.styleFrom(
                  minimumSize: bulkBtnSize,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('+5', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed:
                    value + 10 <= max ? () => _change(value + 10) : null,
                style: FilledButton.styleFrom(
                  minimumSize: bulkBtnSize,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('+10', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}
