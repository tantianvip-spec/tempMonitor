// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures to the child widget in the widget tree, read text, and verify that
// the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:temp_monitor/app.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TempMonitorApp());

    // Verify that our app renders.
    expect(find.text('Temp Monitor'), findsOneWidget);
  });
}
