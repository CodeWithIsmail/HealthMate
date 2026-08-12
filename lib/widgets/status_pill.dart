import 'package:flutter/material.dart';

import '../core/theme/chart_palette.dart';
import '../core/utils/formatters.dart';

/// Renders a [RangeStatus] as colour + icon + text — never colour alone,
/// since light-mode amber falls under 3:1 contrast on white.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final RangeStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final (Color color, IconData icon) = switch (status) {
      RangeStatus.low => (palette.belowRange, Icons.arrow_downward),
      RangeStatus.high => (palette.aboveRange, Icons.arrow_upward),
      RangeStatus.normal => (palette.series, Icons.check),
      RangeStatus.unknown => (Theme.of(context).colorScheme.onSurfaceVariant, Icons.remove),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            statusLabel[status]!,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
