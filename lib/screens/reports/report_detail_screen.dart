import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/app_dependencies.dart';
import '../../core/utils/formatters.dart';
import '../../models/report.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/bilingual_summary.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/status_pill.dart';

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late Future<ReportDetail> _future;
  final _shareController = TextEditingController();
  bool _sharing = false;
  String? _shareError;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _shareController.dispose();
    super.dispose();
  }

  Future<ReportDetail> _load() {
    return context.read<AppDependencies>().reportRepository.detail(widget.reportId);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _delete() async {
    final reportRepository = context.read<AppDependencies>().reportRepository;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this report?'),
        content: const Text('This report and all of its values will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await reportRepository.remove(widget.reportId);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'Could not delete this report.')));
      }
    }
  }

  Future<void> _share() async {
    final username = _shareController.text.trim().toLowerCase();
    if (username.isEmpty) return;
    setState(() {
      _sharing = true;
      _shareError = null;
    });
    try {
      await context.read<AppDependencies>().reportRepository.share(widget.reportId, username);
      _shareController.clear();
      _reload();
    } catch (e) {
      setState(() => _shareError = e is ApiException ? e.message : 'Could not share this report.');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _unshare(String username) async {
    try {
      await context.read<AppDependencies>().reportRepository.unshare(widget.reportId, username);
      _reload();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: FutureBuilder<ReportDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : "Couldn't load this report.";
            return ErrorView(message: message, onRetry: _reload);
          }
          final report = snapshot.data!;
          final abnormal = report.values
              .where((v) => v.refLow != null && rangeStatus(v.value, v.refLow, v.refHigh) != RangeStatus.normal)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(report.title ?? 'Health report', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text(
                          '${formatDateLong(report.reportDate)}'
                          '${report.isOwner ? '' : ' · shared by ${report.owner}'}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (report.isOwner)
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                      tooltip: 'Delete',
                      onPressed: _delete,
                    ),
                ],
              ),
              if (abnormal.isNotEmpty) ...[
                const SizedBox(height: 16),
                _WarningBanner(
                  title: '${abnormal.length} value${abnormal.length == 1 ? '' : 's'} outside the reference range',
                  message:
                      '${abnormal.map((v) => v.name).join(', ')}. Reference ranges vary between labs — '
                      'discuss anything concerning with a clinician.',
                ),
              ],
              const SizedBox(height: 20),
              Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Text('Results', style: Theme.of(context).textTheme.titleMedium),
                          const Spacer(),
                          Text('${report.values.length} values', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ...report.values.map((v) => _ValueRow(value: v)),
                  ],
                ),
              ),
              if ((report.summary != null && report.summary!.isNotEmpty) ||
                  (report.summaryBn != null && report.summaryBn!.isNotEmpty)) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Analysis', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        BilingualSummary(textEn: report.summary, textBn: report.summaryBn),
                      ],
                    ),
                  ),
                ),
              ],
              if (report.imageUrl != null) ...[
                const SizedBox(height: 16),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: CachedNetworkImage(imageUrl: report.imageUrl!, fit: BoxFit.contain),
                ),
              ],
              if (report.isOwner) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.share_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('Shared with', style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'People here can view this one report, even without full profile access.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _shareController,
                                decoration: const InputDecoration(hintText: 'username'),
                                onSubmitted: (_) => _share(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _sharing ? null : _share,
                              icon: _sharing
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.person_add_outlined),
                            ),
                          ],
                        ),
                        if (_shareError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _shareError!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (report.sharedWith.isEmpty)
                          Text('Not shared with anyone yet.', style: Theme.of(context).textTheme.bodySmall)
                        else
                          ...report.sharedWith.map(
                            (p) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: AppAvatar(name: p.username, imageUrl: p.imageUrl, size: 32),
                              title: Text(p.username),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => _unshare(p.username),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.value});
  final ReportValue value;

  @override
  Widget build(BuildContext context) {
    final status = rangeStatus(value.value, value.refLow, value.refHigh);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(value.name, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${formatValue(value.value)}${value.unit != null ? ' ${value.unit}' : ''}',
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

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: colorScheme.onTertiaryContainer, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(message, style: TextStyle(color: colorScheme.onTertiaryContainer, fontSize: 13)),
        ],
      ),
    );
  }
}
