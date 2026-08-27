import 'package:flutter/material.dart';

import '../widgets/brand_mark.dart';

/// Shown only while `AuthProvider.restoreSession()` is resolving at launch.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(),
            const SizedBox(height: 20),
            Text('HealthMate', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 32),
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
