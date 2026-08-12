import 'package:flutter/material.dart';

/// Chart colours validated (in the web app) for colour-vision-deficiency
/// separation, lightness banding and contrast. Reused as-is — do not
/// substitute other colours for series/out-of-range readings.
///
/// Light-mode [belowRange] falls under 3:1 contrast on white, so an
/// out-of-range reading must never rely on colour alone: always pair it with
/// a text label (see `RangeStatus` in `core/utils/formatters.dart`).
class ChartPalette {
  const ChartPalette({
    required this.series,
    required this.belowRange,
    required this.aboveRange,
    required this.onBackground,
  });

  final Color series;
  final Color belowRange;
  final Color aboveRange;
  final Color onBackground;

  static const light = ChartPalette(
    series: Color(0xFF17805B),
    belowRange: Color(0xFFE6A01E),
    aboveRange: Color(0xFFC02434),
    onBackground: Color(0xFFFFFFFF),
  );

  static const dark = ChartPalette(
    series: Color(0xFF1F9E6F),
    belowRange: Color(0xFFC08A1C),
    aboveRange: Color(0xFFCC3B4A),
    onBackground: Color(0xFF141B1E),
  );

  static ChartPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
