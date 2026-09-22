import 'package:chessnut_flutter_export/services/native_engine_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native engine queue serializes overlapping tasks', () async {
    final queue = NativeEngineQueue();
    final events = <String>[];

    final first = queue.run(() async {
      events.add('first-start');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      events.add('first-end');
      return 1;
    });
    final second = queue.run(() async {
      events.add('second-start');
      events.add('second-end');
      return 2;
    });

    expect(await Future.wait([first, second]), [1, 2]);
    expect(events, [
      'first-start',
      'first-end',
      'second-start',
      'second-end',
    ]);
  });

  test('native engine queue continues after a failed task', () async {
    final queue = NativeEngineQueue();

    final failed = queue.run<int>(() async => throw StateError('boom'));
    final recovered = queue.run(() async => 42);

    await expectLater(failed, throwsStateError);
    expect(await recovered, 42);
  });
}
