import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/chart_palette.dart';
import '../core/utils/formatters.dart';
import '../models/trend.dart';

/// Line chart + reference-range band, mirroring the web app's `TrendChart`
/// component: shaded band for the reference range, dashed bounds, and
/// per-point colour by status — with the band named and abnormal readings
/// still listed in text below, since colour is never the only channel.
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.series});

  final TrendSeries series;

  @override
  Widget build(BuildContext context) {
    final points = series.points;
    final test = series.test;

    if (points.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: Text('No data points in this range.')),
      );
    }

    final palette = ChartPalette.of(context);
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final gridColor = Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4);

    Color statusColor(RangeStatus s) => switch (s) {
      RangeStatus.low => palette.belowRange,
      RangeStatus.high => palette.aboveRange,
      _ => palette.series,
    };

    final statuses = points.map((p) => rangeStatus(p.value, test.refLow, test.refHigh)).toList();

    final values = points.map((p) => p.value).toList();
    final lo = [...values, if (test.refLow != null) test.refLow!].reduce((a, b) => a < b ? a : b);
    final hi = [...values, if (test.refHigh != null) test.refHigh!].reduce((a, b) => a > b ? a : b);
    final span = (hi - lo) == 0 ? (hi.abs() == 0 ? 1.0 : hi.abs()) : (hi - lo);
    final pad = span * 0.15;
    final minY = (lo - pad) < 0 ? 0.0 : lo - pad;
    final maxY = hi + pad;

    final labelInterval = (points.length / 5).ceil().clamp(1, points.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 260,
          child: Semantics(
            label: '${test.name} over time, ${points.length} readings',
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (points.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 1),
                ),
                rangeAnnotations: RangeAnnotations(
                  horizontalRangeAnnotations: [
                    if (test.refLow != null && test.refHigh != null)
                      HorizontalRangeAnnotation(
                        y1: test.refLow!,
                        y2: test.refHigh!,
                        color: palette.series.withValues(alpha: 0.08),
                      ),
                  ],
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    if (test.refLow != null)
                      HorizontalLine(
                        y: test.refLow!,
                        color: palette.series.withValues(alpha: 0.35),
                        strokeWidth: 1,
                        dashArray: const [4, 4],
                      ),
                    if (test.refHigh != null)
                      HorizontalLine(
                        y: test.refHigh!,
                        color: palette.series.withValues(alpha: 0.35),
                        strokeWidth: 1,
                        dashArray: const [4, 4],
                      ),
                  ],
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          formatValue(value),
                          style: TextStyle(color: onSurfaceVariant, fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 || index >= points.length || index % labelInterval != 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            formatDate(points[index].date),
                            style: TextStyle(color: onSurfaceVariant, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Theme.of(context).colorScheme.inverseSurface,
                    getTooltipItems: (spots) => spots.map((s) {
                      final index = s.x.toInt();
                      final status = statuses[index];
                      return LineTooltipItem(
                        '${formatDate(points[index].date)}\n'
                        '${formatValue(points[index].value)}${test.unit != null ? ' ${test.unit}' : ''}\n'
                        '${statusLabel[status]}',
                        TextStyle(color: Theme.of(context).colorScheme.onInverseSurface, fontSize: 12),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].value)],
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: palette.series,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      getDotPainter: (spot, percent, bar, index) {
                        final status = statuses[index];
                        final abnormal = status == RangeStatus.low || status == RangeStatus.high;
                        return FlDotCirclePainter(
                          radius: abnormal ? 5.5 : 4,
                          color: statusColor(status),
                          strokeColor: Theme.of(context).colorScheme.surface,
                          strokeWidth: 2,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 20,
          runSpacing: 6,
          children: [
            if (test.refLow != null && test.refHigh != null)
              _LegendEntry(
                swatch: palette.series.withValues(alpha: 0.25),
                label:
                    'Reference range ${formatValue(test.refLow!)}–${formatValue(test.refHigh!)}'
                    '${test.unit != null ? ' ${test.unit}' : ''}',
              ),
            for (final status in [RangeStatus.low, RangeStatus.high])
              if (statuses.where((s) => s == status).length case final n when n > 0)
                _LegendEntry(
                  swatch: statusColor(status),
                  circular: true,
                  label: '$n reading${n == 1 ? '' : 's'} ${status == RangeStatus.low ? 'below' : 'above'} the range',
                ),
          ],
        ),
      ],
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.swatch, required this.label, this.circular = false});

  final Color swatch;
  final String label;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: circular ? 10 : 16,
          height: circular ? 10 : 10,
          decoration: BoxDecoration(
            color: swatch,
            shape: circular ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circular ? null : BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
