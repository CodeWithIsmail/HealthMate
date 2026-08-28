import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/brand_mark.dart';

/// Shared shell for the login and signup screens: a branded hero at the top,
/// and a rounded sheet below it holding the form.
///
/// The hero carries the identity (logo, name, one line of positioning) so the
/// form itself can stay quiet — heading, fields, one primary action. It shrinks
/// when the keyboard opens, so a small phone mid-typing still shows the whole
/// form rather than a wall of branding.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
    this.onBack,
  });

  final String title;
  final String subtitle;

  /// Form contents.
  final List<Widget> children;

  /// Sits below the form — the "switch to the other screen" action.
  final Widget? footer;

  /// Shows a back arrow in the hero when provided.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The hero is dark, so the status bar icons have to be light in both
      // themes — otherwise they vanish into the gradient in light mode.
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: Column(
          children: [
            _BrandHero(compact: keyboardOpen, onBack: onBack),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                clipBehavior: Clip.antiAlias,
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: _FadeInUp(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subtitle,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 28),
                              ...children,
                              if (footer != null) ...[const SizedBox(height: 20), footer!],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gradient header carrying the brand. Uses the brand green directly rather
/// than a scheme role, so it looks identical in light and dark — a brand
/// surface should not change colour with the system theme.
class _BrandHero extends StatelessWidget {
  const _BrandHero({required this.compact, this.onBack});

  final bool compact;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      height: compact ? 148 : 268,
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            if (onBack != null)
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: 'Back',
                  ),
                ),
              ),
            Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: compact ? 12 : 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BrandMark(size: compact ? 56 : 82),
                    SizedBox(height: compact ? 10 : 18),
                    Text(
                      'HealthMate',
                      style: (compact ? theme.textTheme.titleMedium : theme.textTheme.headlineSmall)?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Your health reports, tracked over time',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A short fade-and-rise on first build. Enough to make the sheet feel placed
/// rather than dumped; short enough that nobody waits for it.
class _FadeInUp extends StatelessWidget {
  const _FadeInUp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: child),
      ),
      child: child,
    );
  }
}

/// Failure message shown above the form. Used by both auth screens.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled divider between the primary action and the alternative one.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
      ],
    );
  }
}
