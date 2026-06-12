import 'package:flutter_test/flutter_test.dart';
import 'package:temp_monitor/infrastructure/debug_logger.dart';

void main() {
  group('DebugLogger', () {
    setUp(() => DebugLogger().clear());

    test('stores log entries', () {
      DebugLogger().i('test message', tag: 'Test');
      expect(DebugLogger().entries.length, 1);
      expect(DebugLogger().entries.first.message, 'test message');
    });

    test('exports logs as text', () {
      DebugLogger().i('hello');
      final exported = DebugLogger().export();
      expect(exported.contains('hello'), true);
      expect(exported.contains('INFO'), true);
    });

    test('drops oldest entries when max is exceeded', () {
      for (var i = 0; i < 1005; i++) {
        DebugLogger().i('entry $i');
      }
      expect(DebugLogger().entries.length, 1000);
      expect(DebugLogger().entries.first.message, 'entry 5');
    });
  });
}
