import 'dart:async';

class NativeEngineQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) {
    final previous = _tail;
    final release = Completer<void>();
    _tail = release.future;

    return previous.catchError((_) {}).then((_) async {
      try {
        return await action();
      } finally {
        release.complete();
      }
    });
  }
}

final nativeEngineQueue = NativeEngineQueue();
