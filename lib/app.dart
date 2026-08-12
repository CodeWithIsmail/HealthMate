import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

class HealthMateApp extends StatelessWidget {
  const HealthMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      // Replaced by go_router auth-gated routing in the next slice.
      home: const _Placeholder(),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text('HealthMate', style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
    );
  }
}
