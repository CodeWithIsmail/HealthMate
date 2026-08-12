import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';

/// Range chips shared by the reports and trends screens. `range` is one of
/// `DateRangeOption.value` from `core/utils/formatters.dart`; picking
/// "Custom range" prompts for [from]/[to] via [onCustomRange].
class DateRangeSelector extends StatelessWidget {
  const DateRangeSelector({
    super.key,
    required this.range,
    required this.onChanged,
    required this.onCustomRange,
  });

  final String range;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onCustomRange;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: dateRanges.map((option) {
          final selected = option.value == range;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(option.label),
              selected: selected,
              onSelected: (_) {
                if (option.value == 'custom') {
                  onCustomRange();
                } else {
                  onChanged(option.value);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
