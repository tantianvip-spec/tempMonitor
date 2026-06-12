// Integration test for the temp_monitor app.
// Run with:
//   flutter test integration_test/app_test.dart
//
// Requires a connected Android/iOS device or emulator — does NOT work
// in a headless `flutter test` (the host runner) because main.dart
// initializes plugins (BLE, notifications, background service) that
// need platform binding.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:temp_monitor/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches and shows devices page', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('设备列表'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('调试'), findsOneWidget);
  });
}

// TODO: add tests for
//   - tapping a device tile navigates to dashboard
//   - settings page toggles are interactive
//   - debug log page shows entries