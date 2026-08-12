import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/user_profile.dart';
import '../../providers/connections_provider.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';

enum _Tab { access, viewers }

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  _Tab _tab = _Tab.access;
  final _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConnectionsProvider>().load();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _grant() async {
    final username = _usernameController.text.trim().toLowerCase();
    if (username.isEmpty) return;
    final provider = context.read<ConnectionsProvider>();
    final ok = await provider.grant(username);
    if (ok) {
      _usernameController.clear();
      setState(() => _tab = _Tab.viewers);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConnectionsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connections'),
        actions: [
          IconButton(icon: const Icon(Icons.search), tooltip: 'Find people', onPressed: () => context.push('/people')),
        ],
      ),
      body: provider.loading
          ? const LoadingView()
          : provider.error != null
          ? ErrorView(message: provider.error!, onRetry: provider.load)
          : provider.data == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              onRefresh: provider.load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Who can see your health data, and whose data you can see.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Give someone access to your data'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _usernameController,
                                  decoration: const InputDecoration(hintText: 'their username'),
                                  onSubmitted: (_) => _grant(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: provider.granting ? null : _grant,
                                child: provider.granting
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Grant'),
                              ),
                            ],
                          ),
                          if (provider.grantError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              provider.grantError!,
                              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<_Tab>(
                    segments: [
                      ButtonSegment(
                        value: _Tab.access,
                        label: Text('My access (${provider.data!.access.length})'),
                        icon: const Icon(Icons.visibility_outlined),
                      ),
                      ButtonSegment(
                        value: _Tab.viewers,
                        label: Text('My viewers (${provider.data!.viewers.length})'),
                        icon: const Icon(Icons.people_outline),
                      ),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) => setState(() => _tab = s.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tab == _Tab.access
                        ? 'People who have shared their health data with you.'
                        : 'People you have allowed to view your health data. Revoking takes effect immediately.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _List(tab: _tab, provider: provider),
                ],
              ),
            ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.tab, required this.provider});
  final _Tab tab;
  final ConnectionsProvider provider;

  @override
  Widget build(BuildContext context) {
    final list = tab == _Tab.access ? provider.data!.access : provider.data!.viewers;

    if (list.isEmpty) {
      return EmptyState(
        icon: tab == _Tab.access ? Icons.visibility_outlined : Icons.people_outline,
        title: tab == _Tab.access ? 'Nobody has shared with you yet' : 'Nobody can see your data',
        description: tab == _Tab.access
            ? 'When someone grants you access, their profile appears here and you can browse their reports and trends.'
            : 'Grant access above, and the person will be able to view — but never edit — your reports.',
        action: tab == _Tab.viewers
            ? FilledButton(onPressed: () => context.push('/people'), child: const Text('Find someone to share with'))
            : null,
      );
    }

    return Column(children: list.map((p) => _PersonCard(person: p, tab: tab, provider: provider)).toList());
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person, required this.tab, required this.provider});
  final PersonCard person;
  final _Tab tab;
  final ConnectionsProvider provider;

  @override
  Widget build(BuildContext context) {
    final busy = provider.busyUsernames.contains(person.username);
    final name = fullName(firstName: person.firstName, lastName: person.lastName, username: person.username);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(name: name, imageUrl: person.imageUrl, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleSmall),
                      Text('@${person.username}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            if (person.grantedAt != null) ...[
              const SizedBox(height: 8),
              Text('Since ${formatDate(person.grantedAt!)}', style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tab == _Tab.access
                  ? [
                      OutlinedButton.icon(
                        onPressed: () => context.push('/reports?username=${person.username}'),
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: const Text('Reports'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/trends?username=${person.username}'),
                        icon: const Icon(Icons.show_chart, size: 16),
                        label: const Text('Trends'),
                      ),
                      TextButton.icon(
                        onPressed: busy ? null : () => provider.leave(person.username),
                        icon: busy
                            ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.logout, size: 16),
                        label: const Text('Leave'),
                      ),
                    ]
                  : [
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => provider.revoke(person.username),
                        icon: busy
                            ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.close, size: 16),
                        label: const Text('Revoke access'),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}
