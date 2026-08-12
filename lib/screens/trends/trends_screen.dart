import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/trend.dart';
import '../../providers/trends_provider.dart';
import '../../widgets/date_range_selector.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/trend_chart.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key, this.username});

  final String? username;

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrendsProvider>().loadTests(username: widget.username);
    });
  }

  Future<void> _pickCustomRange(TrendsProvider provider) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      initialDateRange: DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );
    if (range != null) {
      await provider.setRange('custom', from: range.start, to: range.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrendsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.username != null ? "${widget.username}'s trends" : 'Health trends'),
      ),
      body: _Body(provider: provider, onCustomRange: () => _pickCustomRange(provider)),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider, required this.onCustomRange});

  final TrendsProvider provider;
  final Future<void> Function() onCustomRange;

  @override
  Widget build(BuildContext context) {
    if (provider.testsLoading) return const LoadingView();
    if (provider.testsError != null) {
      return ErrorView(message: provider.testsError!, onRetry: () => provider.loadTests(username: provider.username));
    }
    if (provider.tests.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart,
        title: 'Nothing to chart yet',
        description: 'Once you have saved a couple of reports, every test will be plotted here over time.',
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadSeries,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: provider.selectedTestId,
            decoration: const InputDecoration(labelText: 'Test'),
            items: provider.tests
                .map((t) => DropdownMenuItem(value: t.id, child: Text('${t.name} (${t.pointCount})')))
                .toList(),
            onChanged: (id) {
              if (id != null) provider.selectTest(id);
            },
          ),
          const SizedBox(height: 12),
          DateRangeSelector(range: provider.range, onChanged: provider.setRange, onCustomRange: onCustomRange),
          const SizedBox(height: 16),
          if (provider.seriesLoading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: LoadingView())
          else if (provider.seriesError != null)
            ErrorView(message: provider.seriesError!, onRetry: () => provider.loadSeries())
          else if (provider.series != null) ...[
            if (provider.series!.stats != null) _StatsRow(stats: provider.series!.stats!),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(provider.series!.test.name, style: Theme.of(context).textTheme.titleMedium),
                        if (provider.series!.test.unit != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(${provider.series!.test.unit})',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${provider.series!.points.length} reading${provider.series!.points.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TrendChart(series: provider.series!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(child: Text('All readings', style: TextStyle(fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ...provider.series!.points.reversed.map(
                    (p) => _ReadingRow(point: p, test: provider.series!.test),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final TrendStats stats;

  @override
  Widget build(BuildContext context) {
    final entries = [
      ('Latest', formatValue(stats.latest)),
      ('Average', formatValue(stats.average)),
      ('Lowest', formatValue(stats.min)),
      ('Highest', formatValue(stats.max)),
      ('Change', '${stats.change > 0 ? '+' : ''}${formatValue(stats.change)}'),
    ];

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (label, value) = entries[i];
          return Card(
            child: Container(
              width: 110,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.point, required this.test});
  final TrendPoint point;
  final TrendTestRef test;

  @override
  Widget build(BuildContext context) {
    final status = rangeStatus(point.value, test.refLow, test.refHigh);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(formatDate(point.date))),
          Expanded(
            child: Text(
              '${formatValue(point.value)}${test.unit != null ? ' ${test.unit}' : ''}',
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(status: status),
        ],
      ),
    );
  }
}
