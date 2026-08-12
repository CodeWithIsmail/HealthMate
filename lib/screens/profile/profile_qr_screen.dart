import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../providers/auth_provider.dart';

const _steps = [
  'Someone scans this code, or searches for your username.',
  'They send you nothing — instead, you grant them access from the Connections screen.',
  'Once granted, they can view your reports and trends, but never edit them.',
  'You can revoke access at any moment, and it takes effect immediately.',
];

class ProfileQrScreen extends StatefulWidget {
  const ProfileQrScreen({super.key});

  @override
  State<ProfileQrScreen> createState() => _ProfileQrScreenState();
}

class _ProfileQrScreenState extends State<ProfileQrScreen> {
  bool _copied = false;

  Future<void> _copyUsername(String username) async {
    await Clipboard.setData(ClipboardData(text: username));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your QR code'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/people'),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text("Scan someone's"),
          ),
        ],
      ),
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  "Let someone scan this to find you instantly, instead of typing your username.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          // Deliberately fixed white, not theme-driven: a QR
                          // code needs light-background/dark-foreground
                          // contrast to stay scannable regardless of theme.
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: QrImageView(
                            data: 'healthmate:user/${user.username}',
                            version: QrVersions.auto,
                            size: 220,
                            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF14664A)),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF14664A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('@${user.username}', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => _copyUsername(user.username),
                          icon: Icon(_copied ? Icons.check : Icons.copy_outlined),
                          label: Text(_copied ? 'Copied' : 'Copy username'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('How sharing works', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        for (var i = 0; i < _steps.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(_steps[i])),
                              ],
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'This code contains only your username — no health data and nothing private.',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
