import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/core/theme/app_theme.dart';
import 'package:healthmate/providers/capture_provider.dart';
import 'package:healthmate/screens/capture/value_row.dart';

/// Layout guards for the "Review and save" test rows.
///
/// What shipped before was a single Row with an 84dp field whose `suffixText`
/// held the unit — a long unit like `cells/uL` left no room for the number, so
/// the value the user was being asked to confirm was invisible. These tests
/// pump the row at real phone widths; a RenderFlex overflow throws and fails.
void main() {
  Widget wrap(Widget child, {TextScaler textScaler = TextScaler.noScaling}) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: SingleChildScrollView(child: child),
      ),
    ),
  );

  Future<void> pumpRow(
    WidgetTester tester,
    CaptureRow row,
    Size size, {
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrap(
        CaptureValueRow(row: row, onChanged: (_) {}, onRemove: () {}),
        textScaler: textScaler,
      ),
    );
    await tester.pump();
  }

  CaptureRow buildRow({
    String name = 'Haemoglobin',
    String? unit = 'g/dL',
    String value = '12.1',
    double? refLow = 12,
    double? refHigh = 16.5,
  }) => CaptureRow(
    testId: 't1',
    name: name,
    unit: unit,
    valueText: value,
    refLow: refLow,
    refHigh: refHigh,
  );

  testWidgets('shows the name, value, unit and status together', (tester) async {
    await pumpRow(tester, buildRow(), const Size(400, 800));

    expect(find.text('Haemoglobin'), findsOneWidget);
    expect(find.text('g/dL'), findsOneWidget);
    expect(find.text('Reference 12 – 16.5'), findsOneWidget);
    expect(find.text('In range'), findsOneWidget);
    // The number lives in the field, not squeezed out by the unit.
    expect(find.widgetWithText(TextField, '12.1'), findsOneWidget);
  });

  testWidgets('a long name and a long unit fit on a narrow phone', (tester) async {
    await pumpRow(
      tester,
      buildRow(name: 'Total WBC Count (Leukocytes)', unit: 'cells/uL', value: '3800', refLow: 4000, refHigh: 11000),
      const Size(320, 560),
    );

    expect(find.text('Total WBC Count (Leukocytes)'), findsOneWidget);
    expect(find.text('cells/uL'), findsOneWidget);
    expect(find.widgetWithText(TextField, '3800'), findsOneWidget);
    expect(find.text('Below range'), findsOneWidget);
  });

  testWidgets('an ESR-style unit does not push the value out of the field', (tester) async {
    await pumpRow(
      tester,
      buildRow(name: 'ESR', unit: 'mm in 1st hr', value: '28', refLow: 0, refHigh: 20),
      const Size(320, 560),
    );

    expect(find.widgetWithText(TextField, '28'), findsOneWidget);
    expect(find.text('Above range'), findsOneWidget);
  });

  testWidgets('an empty value reads as "Not entered", not "No reference"', (tester) async {
    await pumpRow(tester, buildRow(value: ''), const Size(400, 800));

    expect(find.text('Not entered'), findsOneWidget);
    expect(find.text('No reference'), findsNothing);
  });

  testWidgets('typing a value updates the status without a provider', (tester) async {
    await pumpRow(tester, buildRow(value: ''), const Size(400, 800));

    await tester.enterText(find.byType(TextField), '9');
    await tester.pump();

    expect(find.text('Below range'), findsOneWidget);
    expect(find.text('Not entered'), findsNothing);
  });

  testWidgets('a one-sided range is described, not called "No reference range"', (tester) async {
    await pumpRow(tester, buildRow(refLow: null, refHigh: 20, value: '5'), const Size(400, 800));
    expect(find.text('Reference up to 20'), findsOneWidget);

    await pumpRow(tester, buildRow(refLow: 40, refHigh: null, value: '55'), const Size(400, 800));
    expect(find.text('Reference from 40'), findsOneWidget);
  });

  testWidgets('a test with no reference range and no unit still lays out', (tester) async {
    await pumpRow(
      tester,
      buildRow(name: 'Blood Group', unit: null, value: '', refLow: null, refHigh: null),
      const Size(320, 560),
    );

    expect(find.text('No reference range'), findsOneWidget);
    expect(find.text('Not entered'), findsOneWidget);
  });

  testWidgets('survives a large system font', (tester) async {
    await pumpRow(
      tester,
      buildRow(name: 'Total WBC Count (Leukocytes)', unit: 'cells/uL', value: '3800', refLow: 4000, refHigh: 11000),
      const Size(360, 800),
      textScaler: const TextScaler.linear(1.6),
    );

    expect(find.text('cells/uL'), findsOneWidget);
  });
}
