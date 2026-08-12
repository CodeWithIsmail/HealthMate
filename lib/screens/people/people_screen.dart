import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/user_profile.dart';
import '../../providers/people_search_provider.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/empty_state.dart';

final _qrSchemePattern = RegExp(r'^healthmate:user/(.+)$');
final _usernamePattern = RegExp(r'^[a-z0-9._-]{3,30}$');

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final _searchController = TextEditingController();
  bool _scanning = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final raw = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (raw == null) return;
    final match = _qrSchemePattern.firstMatch(raw);
    final username = (match?.group(1) ?? raw).trim().toLowerCase();
    if (!_usernamePattern.hasMatch(username)) return;

    setState(() => _scanning = false);
    _searchController.text = username;
    context.read<PeopleSearchProvider>().setTerm(username);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PeopleSearchProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find people'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _scanning = !_scanning),
            icon: Icon(_scanning ? Icons.close : Icons.qr_code_scanner),
            label: Text(_scanning ? 'Stop' : 'Scan QR'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Search by username, or scan a QR code, then choose who may see your data.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (provider.notice != null) ...[
            _Banner(message: provider.notice!, tone: _Tone.success),
            const SizedBox(height: 12),
          ],
          if (provider.error != null) ...[
            _Banner(message: provider.error!, tone: _Tone.error),
            const SizedBox(height: 12),
          ],
          if (_scanning) ...[
            Card(
              clipBehavior: Clip.antiAlias,
              child: SizedBox(height: 280, child: MobileScanner(onDetect: _onDetect)),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _searchController,
            autofocus: !_scanning,
            decoration: const InputDecoration(
              hintText: 'Search by username…',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: provider.setTerm,
          ),
          const SizedBox(height: 16),
          _Results(provider: provider, term: _searchController.text),
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.provider, required this.term});
  final PeopleSearchProvider provider;
  final String term;

  @override
  Widget build(BuildContext context) {
    final trimmed = term.trim();

    if (provider.searching && provider.results == null) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: CircularProgressIndicator()));
    }
    if (trimmed.isNotEmpty && trimmed.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Keep typing — at least two characters.', style: Theme.of(context).textTheme.bodySmall),
      );
    }
    if (provider.results != null && provider.results!.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline,
        title: 'No one matches "$trimmed"',
        description: 'Usernames are exact-ish — check the spelling, or ask them to share their QR code.',
      );
    }
    if (provider.results == null) return const SizedBox.shrink();

    return Column(children: provider.results!.map((p) => _PersonResultCard(person: p, provider: provider)).toList());
  }
}

class _PersonResultCard extends StatelessWidget {
  const _PersonResultCard({required this.person, required this.provider});
  final PersonCard person;
  final PeopleSearchProvider provider;

  @override
  Widget build(BuildContext context) {
    final name = fullName(firstName: person.firstName, lastName: person.lastName, username: person.username);
    final colorScheme = Theme.of(context).colorScheme;

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
            const SizedBox(height: 8),
            if (person.iCanViewThem == true)
              _StatusLine(icon: Icons.visibility_outlined, label: 'You can view their data', color: colorScheme.primary),
            if (person.theyCanViewMe == true)
              _StatusLine(icon: Icons.check, label: 'They can view your data', color: colorScheme.primary),
            if (person.iCanViewThem != true && person.theyCanViewMe != true)
              Text('No connection yet', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (person.theyCanViewMe == true)
                  OutlinedButton.icon(
                    onPressed: () => provider.revoke(person.username),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Revoke access'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => provider.grant(person.username),
                    icon: const Icon(Icons.person_add_outlined, size: 16),
                    label: const Text('Give access'),
                  ),
                if (person.iCanViewThem == true)
                  OutlinedButton(
                    onPressed: () => context.push('/reports?username=${person.username}'),
                    child: const Text('View reports'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

enum _Tone { success, error }

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.tone});
  final String message;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = tone == _Tone.success ? colorScheme.secondaryContainer : colorScheme.errorContainer;
    final fg = tone == _Tone.success ? colorScheme.onSecondaryContainer : colorScheme.onErrorContainer;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(tone == _Tone.success ? Icons.check_circle_outline : Icons.error_outline, color: fg, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: fg))),
        ],
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
