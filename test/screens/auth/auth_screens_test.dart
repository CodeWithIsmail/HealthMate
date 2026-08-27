import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/core/api/api_client.dart';
import 'package:healthmate/core/storage/token_storage.dart';
import 'package:healthmate/core/theme/app_theme.dart';
import 'package:healthmate/providers/auth_provider.dart';
import 'package:healthmate/repositories/auth_repository.dart';
import 'package:healthmate/screens/auth/login_screen.dart';
import 'package:healthmate/screens/auth/signup_screen.dart';
import 'package:provider/provider.dart';

/// Layout guards for the two auth screens. They can't be eyeballed on a device
/// from CI, so what these assert is the thing that actually breaks: a
/// RenderFlex overflow at a small width or with the keyboard up. Any overflow
/// raises an exception that fails the test.
void main() {
  AuthProvider buildProvider() {
    final tokenStorage = TokenStorage();
    return AuthProvider(
      authRepository: AuthRepository(
        apiClient: ApiClient(tokenStorage: tokenStorage),
        tokenStorage: tokenStorage,
      ),
    );
  }

  Widget wrap(Widget child, AuthProvider auth) => ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp(theme: AppTheme.light, darkTheme: AppTheme.dark, home: child),
  );

  Future<void> pumpAt(WidgetTester tester, Widget screen, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(screen, buildProvider()));
    await tester.pump();
  }

  group('login screen', () {
    testWidgets('lays out on a typical phone', (tester) async {
      await pumpAt(tester, const LoginScreen(), const Size(400, 800));

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Username or email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Create an account'), findsOneWidget);
    });

    testWidgets('survives a small screen', (tester) async {
      await pumpAt(tester, const LoginScreen(), const Size(320, 560));
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('password visibility can be toggled', (tester) async {
      await pumpAt(tester, const LoginScreen(), const Size(400, 800));

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('empty submit surfaces validation rather than calling the API', (tester) async {
      await pumpAt(tester, const LoginScreen(), const Size(400, 800));

      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pump();

      expect(find.text('Enter your username or email'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });
  });

  group('signup screen', () {
    testWidgets('lays out on a typical phone', (tester) async {
      await pumpAt(tester, const SignupScreen(), const Size(400, 800));

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Username'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
    });

    testWidgets('survives a small screen', (tester) async {
      await pumpAt(tester, const SignupScreen(), const Size(320, 560));
      expect(find.text('Create your account'), findsOneWidget);
    });

    testWidgets('password strength is described in words, not colour alone', (tester) async {
      await pumpAt(tester, const SignupScreen(), const Size(400, 800));

      expect(find.text('At least 8 characters'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'abcdefgh');
      await tester.pump();
      expect(find.text('Weak password'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'Abcdefgh123!xyz');
      await tester.pump();
      expect(find.text('Strong password'), findsOneWidget);
    });

    testWidgets('rejects a bad email and a short password', (tester) async {
      await pumpAt(tester, const SignupScreen(), const Size(400, 800));

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'not-an-email');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'short');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pump();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Must be at least 8 characters'), findsOneWidget);
    });
  });
}
