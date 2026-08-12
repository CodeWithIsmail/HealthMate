import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/capture_provider.dart';
import '../../providers/report_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/capture/capture_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/placeholder_screen.dart';
import '../../screens/reports/report_detail_screen.dart';
import '../../screens/reports/reports_screen.dart';
import '../../screens/shell/app_shell.dart';
import '../../screens/splash_screen.dart';
import '../app_dependencies.dart';

GoRouter buildRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) {
      final status = auth.status;
      final location = state.matchedLocation;

      if (status == AuthStatus.unknown) {
        return location == '/splash' ? null : '/splash';
      }

      final loggingIn = location == '/login' || location == '/signup';
      if (status == AuthStatus.unauthenticated) {
        return loggingIn ? null : '/login';
      }

      // authenticated
      if (loggingIn || location == '/splash') return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(
        path: '/capture',
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => CaptureProvider(
            reportRepository: context.read<AppDependencies>().reportRepository,
            testsRepository: context.read<AppDependencies>().testsRepository,
          ),
          child: const CaptureScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                // Scoped per-route (not app-wide) so a pushed "shared user's
                // reports" instance can't clobber the state of the
                // underlying own-reports tab kept alive by the IndexedStack.
                builder: (context, state) => ChangeNotifierProvider(
                  create: (context) =>
                      ReportProvider(reportRepository: context.read<AppDependencies>().reportRepository),
                  child: ReportsScreen(username: state.uri.queryParameters['username']),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        ReportDetailScreen(reportId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trends',
                builder: (context, state) =>
                    const PlaceholderScreen(title: 'Trends', icon: Icons.show_chart),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/connections',
                builder: (context, state) =>
                    const PlaceholderScreen(title: 'Connections', icon: Icons.people_outline),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) =>
                    const PlaceholderScreen(title: 'Profile', icon: Icons.person_outline),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
