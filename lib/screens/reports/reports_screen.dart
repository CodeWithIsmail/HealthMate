import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/report.dart';
import '../../providers/report_provider.dart';
import '../../widgets/date_range_selector.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.username});

  final String? username;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().load(username: widget.username);
    });
  }

  Future<void> _pickCustomRange(ReportProvider provider) async {
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

  Future<void> _openReport(BuildContext context, String id) async {
    await context.push('/reports/$id');
    if (context.mounted) context.read<ReportProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();
    final isSelf = provider.owner?.isSelf ?? true;

    return Scaffold(
      appBar: AppBar(
        title: Text(isSelf ? 'Report history' : "${provider.owner?.username ?? ''}'s reports"),
        actions: [
          if (isSelf)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add report',
              onPressed: () async {
                await context.push('/capture');
                if (context.mounted) context.read<ReportProvider>().load();
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.load(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: DateRangeSelector(
                range: provider.range,
                onChanged: provider.setRange,
                onCustomRange: () => _pickCustomRange(provider),
              ),
            ),
            Expanded(child: _Body(provider: provider, onOpenReport: (id) => _openReport(context, id))),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider, required this.onOpenReport});

  final ReportProvider provider;
  final ValueChanged<String> onOpenReport;

  @override
  Widget build(BuildContext context) {
    if (provider.loading && provider.reports.isEmpty && provider.error == null) {
      return const LoadingView();
    }
    if (provider.error != null) {
      return ErrorView(message: provider.error!, onRetry: () => provider.load());
    }
    if (provider.reports.isEmpty) {
      return EmptyState(
        icon: Icons.description_outlined,
        title: 'No reports in this range',
        description: provider.range == 'all' ? 'Nothing here yet.' : 'Try widening the date range to see more.',
      );
    }

    return ListView.separated(
      // Clearance for the FAB and the nav bar.
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      itemCount: provider.reports.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final r = provider.reports[index];
        return _ReportCard(report: r, onTap: () => onOpenReport(r.id));
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});

  final ReportSummary report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  report.source == ReportSource.ocr ? Icons.document_scanner_outlined : Icons.keyboard_outlined,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title ?? 'Health report',
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatDate(report.reportDate)} · ${report.valueCount} values',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (report.shareCount > 0) ...[
                Icon(Icons.share_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('${report.shareCount}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
