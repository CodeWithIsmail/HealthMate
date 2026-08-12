import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/app_dependencies.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';

class HealthMateApp extends StatefulWidget {
  const HealthMateApp({super.key});

  @override
  State<HealthMateApp> createState() => _HealthMateAppState();
}

class _HealthMateAppState extends State<HealthMateApp> {
  late final AppDependencies _deps;
  late final AuthProvider _authProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _deps = AppDependencies();
    _authProvider = AuthProvider(authRepository: _deps.authRepository);
    _deps.apiClient.onUnauthorized = _authProvider.forceLogout;
    _router = buildRouter(_authProvider);
    _authProvider.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDependencies>.value(value: _deps),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
      ],
      child: MaterialApp.router(
        title: 'HealthMate',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: _router,
      ),
    );
  }
}
