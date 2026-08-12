import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../core/app_dependencies.dart';
import '../../core/utils/formatters.dart';
import '../../models/connections.dart';
import '../../models/news_article.dart';
import '../../models/report.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/news_repository.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';

class _DashboardData {
  const _DashboardData({
    required this.profile,
    required this.reports,
    required this.news,
    required this.connections,
  });

  final UserProfile profile;
  final List<ReportSummary> reports;
  final NewsHeadlines news;
  final ConnectionsResponse connections;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final deps = context.read<AppDependencies>();
    final results = await Future.wait([
      deps.userRepository.profile(),
      deps.reportRepository.list(),
      deps.newsRepository.headlines(),
      deps.connectionsRepository.list(),
    ]);
    return _DashboardData(
      profile: results[0] as UserProfile,
      reports: (results[1] as ReportsListResponse).reports,
      news: results[2] as NewsHeadlines,
      connections: results[3] as ConnectionsResponse,
    );
  }

  Future<void> _refresh() async {
    final data = await _load();
    if (mounted) setState(() => _future = Future.value(data));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HealthMate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            final message = snapshot.error is ApiException
                ? (snapshot.error as ApiException).message
                : "Couldn't load your dashboard.";
            return ErrorView(message: message, onRetry: () => setState(() => _future = _load()));
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Hello, ${data.profile.firstName ?? data.profile.username}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Here is where your health data stands today.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                _StatsGrid(profile: data.profile, viewerCount: data.connections.viewers.length),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Recent reports',
                  actionLabel: 'View all',
                  onAction: () => context.go('/reports'),
                ),
                const SizedBox(height: 8),
                _RecentReports(reports: data.reports.take(4).toList()),
                if (data.connections.access.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Shared with you', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _SharedWithYou(people: data.connections.access),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text('Health news', style: Theme.of(context).textTheme.titleMedium),
                    if (!data.news.live) ...[
                      const SizedBox(width: 8),
                      _OfflineTag(),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                _NewsList(articles: data.news.articles.take(6).toList()),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.profile, required this.viewerCount});

  final UserProfile profile;
  final int viewerCount;

  @override
  Widget build(BuildContext context) {
    final stats = [
      (Icons.description_outlined, 'Reports', '${profile.stats.reportCount}', '/reports'),
      (Icons.show_chart, 'Values tracked', '${profile.stats.valueCount}', '/trends'),
      (Icons.people_outline, 'People with access', '$viewerCount', '/connections'),
      (
        Icons.add_circle_outline,
        'Last report',
        profile.stats.lastReportDate != null ? relativeDate(profile.stats.lastReportDate!) : '—',
        '/reports',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: stats.map((s) {
        final (icon, label, value, route) = s;
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.go(route),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
                    ],
                  ),
                  const Spacer(),
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.actionLabel, required this.onAction});
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _RecentReports extends StatelessWidget {
  const _RecentReports({required this.reports});
  final List<ReportSummary> reports;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.description_outlined, size: 32),
              const SizedBox(height: 8),
              const Text('No reports yet'),
              const SizedBox(height: 4),
              Text(
                'Upload a photo of a lab report and HealthMate will pull the values out for you.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: reports.map((r) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
            title: Text(r.title ?? 'Health report', maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${formatDate(r.reportDate)} · ${r.valueCount} values'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/reports/${r.id}'),
          );
        }).toList(),
      ),
    );
  }
}

class _SharedWithYou extends StatelessWidget {
  const _SharedWithYou({required this.people});
  final List<PersonCard> people;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: people.map((p) {
        return ActionChip(
          avatar: const Icon(Icons.people_outline, size: 16),
          label: Text(p.username),
          onPressed: () => context.push('/reports?username=${p.username}'),
        );
      }).toList(),
    );
  }
}

class _OfflineTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text('offline', style: TextStyle(fontSize: 11)),
    );
  }
}

class _NewsList extends StatelessWidget {
  const _NewsList({required this.articles});
  final List<NewsArticle> articles;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No headlines right now')),
        ),
      );
    }

    return Card(
      child: Column(
        children: articles.map((a) {
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: a.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: a.imageUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const Icon(Icons.newspaper),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.newspaper),
                    ),
            ),
            title: Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(a.source),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () => launchUrl(Uri.parse(a.url), mode: LaunchMode.externalApplication),
          );
        }).toList(),
      ),
    );
  }
}
