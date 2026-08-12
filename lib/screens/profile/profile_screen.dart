import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../models/user_profile.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.username});

  final String? username;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().load(username: widget.username);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final profile = provider.profile;

    return Scaffold(
      appBar: AppBar(
        title: Text(profile == null || profile.isSelf ? 'Your profile' : "${profile.username}'s profile"),
        actions: profile != null && profile.isSelf
            ? [
                IconButton(
                  icon: const Icon(Icons.qr_code),
                  tooltip: 'My QR code',
                  onPressed: () => context.push('/profile/qr'),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit profile',
                  onPressed: () async {
                    await context.push('/profile/edit');
                    if (context.mounted) context.read<ProfileProvider>().load();
                  },
                ),
              ]
            : null,
      ),
      body: provider.loading
          ? const LoadingView()
          : provider.error != null
          ? ErrorView(message: provider.error!, onRetry: () => provider.load(username: widget.username))
          : profile == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              onRefresh: () => provider.load(username: widget.username),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Header(profile: profile),
                  const SizedBox(height: 16),
                  _DetailsCard(profile: profile),
                  if (profile.isSelf && _detailCount(profile) <= 2) ...[
                    const SizedBox(height: 16),
                    _NearlyEmptyBanner(onEdit: () => context.push('/profile/edit')),
                  ],
                ],
              ),
            ),
    );
  }
}

int _detailCount(UserProfile p) {
  var n = 2; // full name + email are always present
  if (p.phone != null) n++;
  if (p.city != null || p.country != null) n++;
  if (p.age != null) n++;
  if (p.heightCm != null) n++;
  if (p.weightKg != null) n++;
  if (p.bmi != null) n++;
  return n;
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final name = fullName(firstName: profile.firstName, lastName: profile.lastName, username: profile.username);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            AppAvatar(name: name, imageUrl: profile.imageUrl, size: 88),
            const SizedBox(height: 12),
            Text(name, style: Theme.of(context).textTheme.titleLarge),
            Text('@${profile.username}', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.description_outlined,
                    value: '${profile.stats.reportCount}',
                    label: 'Reports',
                    onTap: () => context.go(profile.isSelf ? '/reports' : '/reports?username=${profile.username}'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.show_chart,
                    value: '${profile.stats.valueCount}',
                    label: 'Values',
                    onTap: () => context.go(profile.isSelf ? '/trends' : '/trends?username=${profile.username}'),
                  ),
                ),
              ],
            ),
            if (profile.stats.lastReportDate != null) ...[
              const SizedBox(height: 12),
              Text(
                'Last report ${formatDate(profile.stats.lastReportDate!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.value, required this.label, required this.onTap});
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

const _genderLabel = {
  Gender.male: 'Male',
  Gender.female: 'Female',
  Gender.other: 'Other',
  Gender.undisclosed: 'Not specified',
};

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String?)>[
      (
        Icons.person_outline,
        'Full name',
        fullName(firstName: profile.firstName, lastName: profile.lastName, username: profile.username),
      ),
      (Icons.mail_outline, 'Email', profile.email),
      (Icons.phone_outlined, 'Phone', profile.phone),
      (
        Icons.location_on_outlined,
        'Location',
        [profile.city, profile.country].where((s) => s != null && s.isNotEmpty).join(', ').let(
          (s) => s.isEmpty ? null : s,
        ),
      ),
      (Icons.calendar_today_outlined, 'Age', profile.age != null ? '${profile.age} years' : null),
      (Icons.wc_outlined, 'Gender', _genderLabel[profile.gender]),
      (Icons.water_drop_outlined, 'Blood group', profile.bloodGroup.label),
      (Icons.straighten_outlined, 'Height', profile.heightCm != null ? '${profile.heightCm} cm' : null),
      (Icons.monitor_weight_outlined, 'Weight', profile.weightKg != null ? '${profile.weightKg} kg' : null),
      (Icons.bar_chart, 'BMI', profile.bmi != null ? '${profile.bmi}' : null),
    ].where((r) => r.$3 != null).toList();

    return Card(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [Text('Details', style: TextStyle(fontWeight: FontWeight.w600))]),
          ),
          const Divider(height: 1),
          ...rows.map(
            (r) => ListTile(
              leading: Icon(r.$1, color: Theme.of(context).colorScheme.primary),
              title: Text(r.$2, style: Theme.of(context).textTheme.bodySmall),
              subtitle: Text(r.$3!, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ),
        ],
      ),
    );
  }
}

class _NearlyEmptyBanner extends StatelessWidget {
  const _NearlyEmptyBanner({required this.onEdit});
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colorScheme.onSecondaryContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Adding your date of birth, height and weight lets HealthMate compute age and BMI.',
              style: TextStyle(color: colorScheme.onSecondaryContainer),
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('Fill it in')),
        ],
      ),
    );
  }
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
