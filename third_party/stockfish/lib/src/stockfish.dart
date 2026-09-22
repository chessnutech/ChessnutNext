import 'dart:async';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'ffi.dart';
import 'stockfish_state.dart';

final _logger = Logger('Stockfish');

/// A wrapper for C++ engine.
class Stockfish {
  final Completer<Stockfish>? completer;

  final _state = _StockfishState();
  final _stdoutController = StreamController<String>.broadcast();
  final _doneCompleter = Completer<void>();
  final _mainPort = ReceivePort();
  final _stdoutPort = ReceivePort();

  late StreamSubscription _mainSubscription;
  late StreamSubscription _stdoutSubscription;
  bool _closed = false;

  Stockfish._({this.completer}) {
    _mainSubscription =
        _mainPort.listen((message) => _cleanUp(message is int ? message : 1));
    _stdoutSubscription = _stdoutPort.listen((message) {
      if (message is String) {
        _logger.finest('The stdout isolate sent $message');
        _stdoutController.sink.add(message);
      } else {
        _logger.fine('The stdout isolate sent $message');
      }
    });
    compute(_spawnIsolates, [_mainPort.sendPort, _stdoutPort.sendPort]).then(
      (success) {
        if (_closed) {
          _completeStartupError(StateError('Stockfish exited during startup'));
          return;
        }
        final state = success ? StockfishState.ready : StockfishState.error;
        _logger.fine('The init isolate reported $state');
        _state._setValue(state);
        if (state == StockfishState.ready) {
          completer?.complete(this);
        } else {
          _completeStartupError(StateError('Stockfish failed to initialize'));
          _cleanUp(1);
        }
      },
      onError: (error, stackTrace) {
        _logger.severe('The init isolate encountered an error $error');
        _completeStartupError(error, stackTrace);
        _cleanUp(1);
      },
    );
  }

  static Stockfish? _instance;

  /// Creates a C++ engine.
  ///
  /// This may throws a [StateError] if an active instance is being used.
  /// Owner must [dispose] it before a new instance can be created.
  factory Stockfish() {
    if (_instance != null) {
      throw StateError('Multiple instances are not supported, yet.');
    }

    _instance = Stockfish._();
    return _instance!;
  }

  /// The current state of the underlying C++ engine.
  ValueListenable<StockfishState> get state => _state;

  /// The standard output stream.
  Stream<String> get stdout => _stdoutController.stream;

  /// Completes when the native engine loop has exited and Dart state is reset.
  Future<void> get done => _doneCompleter.future;

  /// The standard input sink.
  set stdin(String line) {
    final stateValue = _state.value;
    if (stateValue != StockfishState.ready) {
      throw StateError('Stockfish is not ready ($stateValue)');
    }

    _writeLineUnchecked(line);
  }

  void _writeLineUnchecked(String line) {
    final pointer = '$line\n'.toNativeUtf8();
    try {
      nativeStdinWrite(pointer);
    } finally {
      calloc.free(pointer);
    }
  }

  /// Stops the C++ engine.
  void dispose() {
    if (_closed) return;
    if (_state.value != StockfishState.ready) {
      try {
        _writeLineUnchecked('quit');
      } catch (error, stackTrace) {
        _logger.warning(
          'Failed to request Stockfish startup abort',
          error,
          stackTrace,
        );
        _cleanUp(1);
      }
      return;
    }
    try {
      stdin = 'quit';
    } catch (error, stackTrace) {
      _logger.warning('Failed to send quit to Stockfish', error, stackTrace);
      _cleanUp(1);
    }
  }

  void _cleanUp(int exitCode) {
    if (_closed) return;
    _closed = true;

    _stdoutController.close();
    _mainSubscription.cancel();
    _stdoutSubscription.cancel();

    final nextState =
        exitCode == 0 ? StockfishState.disposed : StockfishState.error;
    _state._setValue(nextState);
    if (nextState == StockfishState.error) {
      _completeStartupError(
          StateError('Stockfish exited before becoming ready'));
    }
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }

    if (identical(_instance, this)) {
      _instance = null;
    }
  }

  void _completeStartupError(Object error, [StackTrace? stackTrace]) {
    final startupCompleter = completer;
    if (startupCompleter == null || startupCompleter.isCompleted) return;
    if (stackTrace == null) {
      startupCompleter.completeError(error);
    } else {
      startupCompleter.completeError(error, stackTrace);
    }
  }
}

/// Creates a C++ engine asynchronously.
///
/// This method is different from the factory method [Stockfish.new] that
/// it will wait for the engine to be ready before returning the instance.
Future<Stockfish> stockfishAsync() {
  if (Stockfish._instance != null) {
    return Future.error(StateError('Only one instance can be used at a time'));
  }

  final completer = Completer<Stockfish>();
  Stockfish._instance = Stockfish._(completer: completer);
  return completer.future;
}

/// Disposes the current engine instance, if one is still held by this isolate.
Future<void> disposeCurrentStockfish() async {
  final instance = Stockfish._instance;
  if (instance == null) return;
  instance.dispose();
  try {
    await instance.done.timeout(const Duration(seconds: 3));
  } catch (_) {
    if (identical(Stockfish._instance, instance)) {
      Stockfish._instance = null;
    }
  }
}

class _StockfishState extends ChangeNotifier
    implements ValueListenable<StockfishState> {
  StockfishState _value = StockfishState.starting;

  @override
  StockfishState get value => _value;

  _setValue(StockfishState v) {
    if (v == _value) return;
    _value = v;
    notifyListeners();
  }
}

void _isolateMain(SendPort mainPort) {
  final exitCode = nativeMain();
  mainPort.send(exitCode);

  _logger.fine('nativeMain returns $exitCode');
}

void _isolateStdout(SendPort stdoutPort) {
  String previous = '';

  while (true) {
    final pointer = nativeStdoutRead();

    if (pointer.address == 0) {
      _logger.fine('nativeStdoutRead returns NULL');
      return;
    }

    final data = previous + pointer.toDartString();
    final lines = data.split('\n');
    previous = lines.removeLast();
    for (final line in lines) {
      stdoutPort.send(line);
    }
  }
}

Future<bool> _spawnIsolates(List<SendPort> mainAndStdout) async {
  final initResult = nativeInit();
  if (initResult != 0) {
    _logger.severe('initResult=$initResult');
    return false;
  }

  try {
    await Isolate.spawn(_isolateStdout, mainAndStdout[1]);
  } catch (error) {
    _logger.severe('Failed to spawn stdout isolate: $error');
    return false;
  }

  try {
    await Isolate.spawn(_isolateMain, mainAndStdout[0]);
  } catch (error) {
    _logger.severe('Failed to spawn main isolate: $error');
    return false;
  }

  return true;
}
