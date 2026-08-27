import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/core/theme/app_theme.dart';
import 'package:healthmate/widgets/stat_card.dart';

/// The dashboard tiles hold two variable-length strings in a fixed box. Before
/// this, "People with access" ellipsized to "People with acc…" and a relative
/// date wrapped to a line that fell outside the card. These pump the card at
/// the size the grid actually gives it.
void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required String label,
    required String value,
    double width = 154,
    double height = 104,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: textScaler),
            child: Center(
              child: SizedBox(
                width: width,
                height: height,
                child: StatCard(icon: Icons.people_outline, label: label, value: value, onTap: () {}),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a long label and a long value both fit', (tester) async {
    await pumpCard(tester, label: 'People with access', value: '22 days ago');

    expect(find.text('People with access'), findsOneWidget);
    expect(find.text('22 days ago'), findsOneWidget);
  });

  testWidgets('holds up at a narrow grid cell', (tester) async {
    await pumpCard(tester, label: 'People with access', value: '22 days ago', width: 132);

    expect(find.text('People with access'), findsOneWidget);
  });

  testWidgets('holds up at a large system font', (tester) async {
    await pumpCard(
      tester,
      label: 'People with access',
      value: '22 days ago',
      height: 156,
      textScaler: const TextScaler.linear(1.5),
    );

    expect(find.text('22 days ago'), findsOneWidget);
  });

  testWidgets('a short value renders plainly', (tester) async {
    await pumpCard(tester, label: 'Reports', value: '7');

    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });
}
