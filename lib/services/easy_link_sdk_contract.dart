import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

enum EasyLinkBoardModel {
  air,
  pro,
  airPlus,
  evo,
  go,
}

extension EasyLinkBoardModelInfo on EasyLinkBoardModel {
  String get displayName {
    switch (this) {
      case EasyLinkBoardModel.air:
        return 'Chessnut Air';
      case EasyLinkBoardModel.pro:
        return 'Chessnut Pro';
      case EasyLinkBoardModel.airPlus:
        return 'Chessnut Air Plus';
      case EasyLinkBoardModel.evo:
        return 'Chessnut Evo';
      case EasyLinkBoardModel.go:
        return 'Chessnut Go';
    }
  }
}

EasyLinkBoardModel? easyLinkBoardModelFromText(String? text) {
  final normalized = text?.toLowerCase() ?? '';
  if (normalized.trim().isEmpty) return null;
  final compact = normalized.replaceAll(RegExp(r'[^a-z0-9+]'), '');
  if (compact.contains('air+') ||
      compact.contains('airplus') ||
      compact.contains('chessnutplus')) {
    return EasyLinkBoardModel.airPlus;
  }
  if (normalized.contains('pro')) return EasyLinkBoardModel.pro;
  if (normalized.contains('evo')) return EasyLinkBoardModel.evo;
  if (normalized.contains('go')) return EasyLinkBoardModel.go;
  if (normalized.contains('air')) return EasyLinkBoardModel.air;
  return null;
}

class EasyLinkHidProducts {
  const EasyLinkHidProducts._();

  static const vendorId = 0x2d80;

  static bool isSupported(int vendorId, int productId) {
    return vendorId == EasyLinkHidProducts.vendorId &&
        modelForProductId(productId) != null;
  }

  static EasyLinkBoardModel? modelForProductId(int productId) {
    final family = (productId >> 8) & 0xff;
    switch (family) {
      case 0x80:
        return EasyLinkBoardModel.air;
      case 0x81:
        return EasyLinkBoardModel.pro;
      case 0x82:
        return EasyLinkBoardModel.airPlus;
      case 0x83:
        return EasyLinkBoardModel.evo;
      case 0x85:
        return EasyLinkBoardModel.go;
    }
    return null;
  }
}

class EasyLinkCAbi {
  const EasyLinkCAbi._();

  static const version = 'cl_version';
  static const connect = 'cl_connect';
  static const disconnect = 'cl_disconnect';
  static const switchRealtimeMode = 'cl_switch_real_time_mode';
  static const switchUploadMode = 'cl_switch_upload_mode';
  static const setRealtimeCallback = 'cl_set_readtime_callback';
  static const beep = 'cl_beep';
  static const led = 'cl_led';
  static const mcuVersion = 'cl_get_mcu_version';
  static const bleVersion = 'cl_get_ble_version';
  static const battery = 'cl_get_battery';
  static const fileCount = 'cl_get_file_count';
  static const getFile = 'cl_get_file';
  static const getFileAndDelete = 'cl_get_file_and_delete';
  static const getFileAndKeep = 'cl_get_file_and_keep';

  static const sdkVersionBufferLength = 20;
  static const hardwareVersionBufferLength = 100;
  static const recommendedGameFileBufferLength = 10 * 1024;
}

class EasyLinkDynamicLibrary {
  const EasyLinkDynamicLibrary._();

  static String fileNameForCurrentPlatform() {
    if (Platform.isWindows) {
      return fileNameForPlatform('windows');
    }
    if (Platform.isMacOS) {
      return fileNameForPlatform('macos');
    }
    if (Platform.isAndroid) {
      return fileNameForPlatform('android');
    }
    if (Platform.isLinux) {
      return fileNameForPlatform('linux');
    }
    throw UnsupportedError(
        'EasyLinkSDK HID is not available on this platform.');
  }

  static String fileNameForPlatform(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return 'easylink.dll';
      case 'macos':
      case 'darwin':
        return 'libeasylink.dylib';
      case 'android':
      case 'linux':
        return 'libeasylink.so';
    }
    throw UnsupportedError('Unsupported EasyLink platform: $platform');
  }

  static ffi.DynamicLibrary open({String? path}) {
    return ffi.DynamicLibrary.open(path ?? fileNameForCurrentPlatform());
  }
}

typedef EasyLinkRealtimeFenCallback = void Function(String boardOnlyFen);

class EasyLinkSdkBindings {
  EasyLinkSdkBindings(ffi.DynamicLibrary dylib)
      : _clVersion = dylib.lookupFunction<_ClVersionNative, _ClVersionDart>(
          EasyLinkCAbi.version,
        ),
        _clConnect = dylib.lookupFunction<_ClConnectNative, _ClConnectDart>(
          EasyLinkCAbi.connect,
        ),
        _clDisconnect =
            dylib.lookupFunction<_ClDisconnectNative, _ClDisconnectDart>(
          EasyLinkCAbi.disconnect,
        ),
        _clSwitchRealtimeMode = dylib.lookupFunction<
            _ClSwitchRealtimeModeNative,
            _ClSwitchRealtimeModeDart>(EasyLinkCAbi.switchRealtimeMode),
        _clSwitchUploadMode = dylib.lookupFunction<_ClSwitchUploadModeNative,
            _ClSwitchUploadModeDart>(EasyLinkCAbi.switchUploadMode),
        _clSetRealtimeCallback = dylib.lookupFunction<
            _ClSetRealtimeCallbackNative,
            _ClSetRealtimeCallbackDart>(EasyLinkCAbi.setRealtimeCallback),
        _clBeep = dylib.lookupFunction<_ClBeepNative, _ClBeepDart>(
          EasyLinkCAbi.beep,
        ),
        _clLed = dylib.lookupFunction<_ClLedNative, _ClLedDart>(
          EasyLinkCAbi.led,
        ),
        _clGetMcuVersion =
            dylib.lookupFunction<_ClGetMcuVersionNative, _ClGetMcuVersionDart>(
                EasyLinkCAbi.mcuVersion),
        _clGetBleVersion =
            dylib.lookupFunction<_ClGetBleVersionNative, _ClGetBleVersionDart>(
                EasyLinkCAbi.bleVersion),
        _clGetBattery =
            dylib.lookupFunction<_ClGetBatteryNative, _ClGetBatteryDart>(
          EasyLinkCAbi.battery,
        ),
        _clGetFileCount =
            dylib.lookupFunction<_ClGetFileCountNative, _ClGetFileCountDart>(
          EasyLinkCAbi.fileCount,
        ),
        _clGetFileAndKeep = dylib.lookupFunction<_ClGetFileAndKeepNative,
            _ClGetFileAndKeepDart>(EasyLinkCAbi.getFileAndKeep),
        _clGetFileAndDelete = dylib.lookupFunction<_ClGetFileAndDeleteNative,
            _ClGetFileAndDeleteDart>(EasyLinkCAbi.getFileAndDelete);

  factory EasyLinkSdkBindings.open({String? path}) {
    return EasyLinkSdkBindings(EasyLinkDynamicLibrary.open(path: path));
  }

  final _ClVersionDart _clVersion;
  final _ClConnectDart _clConnect;
  final _ClDisconnectDart _clDisconnect;
  final _ClSwitchRealtimeModeDart _clSwitchRealtimeMode;
  final _ClSwitchUploadModeDart _clSwitchUploadMode;
  final _ClSetRealtimeCallbackDart _clSetRealtimeCallback;
  final _ClBeepDart _clBeep;
  final _ClLedDart _clLed;
  final _ClGetMcuVersionDart _clGetMcuVersion;
  final _ClGetBleVersionDart _clGetBleVersion;
  final _ClGetBatteryDart _clGetBattery;
  final _ClGetFileCountDart _clGetFileCount;
  final _ClGetFileAndKeepDart _clGetFileAndKeep;
  final _ClGetFileAndDeleteDart _clGetFileAndDelete;

  ffi.NativeCallable<_RealtimeCallbackNative>? _callbackHandle;
  EasyLinkBoardModel? _boardModel;

  EasyLinkBoardModel? get boardModel => _boardModel;

  String? sdkVersion() {
    return _readStringBuffer(
      EasyLinkCAbi.sdkVersionBufferLength,
      _clVersion,
    );
  }

  bool connect() {
    final connected = _clConnect() == 1;
    if (connected) {
      _boardModel = _detectBoardModel() ?? _boardModel;
    }
    return connected;
  }

  void disconnect() {
    _clDisconnect();
  }

  bool switchRealtimeMode() => _clSwitchRealtimeMode() == 1;

  bool switchUploadMode() => _clSwitchUploadMode() == 1;

  void setRealtimeFenCallback(EasyLinkRealtimeFenCallback? onFen) {
    _callbackHandle?.close();
    _callbackHandle = null;
    if (onFen == null) {
      _clSetRealtimeCallback(ffi.nullptr);
      return;
    }
    _callbackHandle = ffi.NativeCallable<_RealtimeCallbackNative>.listener(
      (ffi.Pointer<ffi.Char> fenPointer, int length) {
        final fen = fenPointer.cast<Utf8>().toDartString(length: length);
        onFen(fen.split(RegExp(r'\s+')).first);
      },
    );
    _clSetRealtimeCallback(_callbackHandle!.nativeFunction);
  }

  bool beep({int frequencyHz = 1000, int durationMs = 200}) {
    return _clBeep(frequencyHz, durationMs) == 1;
  }

  bool setLedSquares(Set<String> squares) {
    return setLedRows(EasyLinkLedMatrixCodec.rowsFromSquares(squares));
  }

  bool setLedRows(List<String> rows) {
    if (rows.length != 8 || rows.any((row) => row.length != 8)) {
      throw ArgumentError.value(rows, 'rows');
    }

    final rowPointers = calloc<ffi.Pointer<Utf8>>(8);
    final nativeRows = <ffi.Pointer<Utf8>>[];
    try {
      for (var i = 0; i < rows.length; i++) {
        final pointer = rows[i].toNativeUtf8();
        nativeRows.add(pointer);
        rowPointers[i] = pointer;
      }
      return _clLed(rowPointers) == 1;
    } finally {
      for (final pointer in nativeRows) {
        calloc.free(pointer);
      }
      calloc.free(rowPointers);
    }
  }

  String? mcuVersion() {
    return _readStringBuffer(
      EasyLinkCAbi.hardwareVersionBufferLength,
      _clGetMcuVersion,
    );
  }

  String? bleVersion() {
    return _readStringBuffer(
      EasyLinkCAbi.hardwareVersionBufferLength,
      _clGetBleVersion,
    );
  }

  EasyLinkBoardModel? _detectBoardModel() {
    return easyLinkBoardModelFromText(mcuVersion()) ??
        easyLinkBoardModelFromText(bleVersion()) ??
        easyLinkBoardModelFromText(sdkVersion());
  }

  int? batteryLevel() {
    final battery = _clGetBattery();
    return battery < 0 ? null : battery.clamp(0, 100);
  }

  int? fileCount() {
    final count = _clGetFileCount();
    return count < 0 ? null : count;
  }

  String? peekGameFile({
    int bufferLength = EasyLinkCAbi.recommendedGameFileBufferLength,
  }) {
    return _readSizedStringBuffer(bufferLength, _clGetFileAndKeep);
  }

  String? readAndDeleteGameFile({
    int bufferLength = EasyLinkCAbi.recommendedGameFileBufferLength,
  }) {
    return _readSizedStringBuffer(bufferLength, _clGetFileAndDelete);
  }

  void dispose() {
    setRealtimeFenCallback(null);
  }
}

class EasyLinkLedMatrixCodec {
  const EasyLinkLedMatrixCodec._();

  static List<String> rowsFromSquares(Set<String> squares) {
    final rows = List.generate(8, (_) => List<String>.filled(8, '0'));
    for (final square in squares) {
      final file = _fileIndex(square);
      final rank = _rankIndex(square);
      if (file == null || rank == null) {
        continue;
      }
      rows[7 - rank][file] = '1';
    }
    return [for (final row in rows) row.join()];
  }

  static List<String> emptyRows() {
    return List<String>.filled(8, '00000000');
  }
}

typedef _ClVersionNative = ffi.UintPtr Function(ffi.Pointer<ffi.Char>);
typedef _ClVersionDart = int Function(ffi.Pointer<ffi.Char>);

typedef _ClConnectNative = ffi.Int Function();
typedef _ClConnectDart = int Function();

typedef _ClDisconnectNative = ffi.Void Function();
typedef _ClDisconnectDart = void Function();

typedef _ClSwitchRealtimeModeNative = ffi.Int Function();
typedef _ClSwitchRealtimeModeDart = int Function();

typedef _ClSwitchUploadModeNative = ffi.Int Function();
typedef _ClSwitchUploadModeDart = int Function();

typedef _RealtimeCallbackNative = ffi.Void Function(
  ffi.Pointer<ffi.Char>,
  ffi.UintPtr,
);
typedef _ClSetRealtimeCallbackNative = ffi.Void Function(
  ffi.Pointer<ffi.NativeFunction<_RealtimeCallbackNative>>,
);
typedef _ClSetRealtimeCallbackDart = void Function(
  ffi.Pointer<ffi.NativeFunction<_RealtimeCallbackNative>>,
);

typedef _ClBeepNative = ffi.Int Function(ffi.Uint16, ffi.Uint16);
typedef _ClBeepDart = int Function(int, int);

typedef _ClLedNative = ffi.Int Function(ffi.Pointer<ffi.Pointer<Utf8>>);
typedef _ClLedDart = int Function(ffi.Pointer<ffi.Pointer<Utf8>>);

typedef _ClGetMcuVersionNative = ffi.UintPtr Function(ffi.Pointer<ffi.Char>);
typedef _ClGetMcuVersionDart = int Function(ffi.Pointer<ffi.Char>);

typedef _ClGetBleVersionNative = ffi.UintPtr Function(ffi.Pointer<ffi.Char>);
typedef _ClGetBleVersionDart = int Function(ffi.Pointer<ffi.Char>);

typedef _ClGetBatteryNative = ffi.Int Function();
typedef _ClGetBatteryDart = int Function();

typedef _ClGetFileCountNative = ffi.Int Function();
typedef _ClGetFileCountDart = int Function();

typedef _ClGetFileAndKeepNative = ffi.Int Function(
  ffi.Pointer<ffi.Char>,
  ffi.UintPtr,
);
typedef _ClGetFileAndKeepDart = int Function(ffi.Pointer<ffi.Char>, int);

typedef _ClGetFileAndDeleteNative = ffi.Int Function(
  ffi.Pointer<ffi.Char>,
  ffi.UintPtr,
);
typedef _ClGetFileAndDeleteDart = int Function(ffi.Pointer<ffi.Char>, int);

String? _readStringBuffer(
    int length, int Function(ffi.Pointer<ffi.Char>) read) {
  final pointer = calloc<ffi.Char>(length);
  try {
    final written = read(pointer);
    if (written <= 0) {
      return null;
    }
    return pointer.cast<Utf8>().toDartString(length: written);
  } finally {
    calloc.free(pointer);
  }
}

String? _readSizedStringBuffer(
  int length,
  int Function(ffi.Pointer<ffi.Char>, int) read,
) {
  final pointer = calloc<ffi.Char>(length);
  try {
    final written = read(pointer, length);
    if (written <= 0) {
      return null;
    }
    return pointer.cast<Utf8>().toDartString(length: written);
  } finally {
    calloc.free(pointer);
  }
}

int? _fileIndex(String square) {
  if (square.length != 2) {
    return null;
  }
  final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
  if (file < 0 || file > 7) {
    return null;
  }
  return file;
}

int? _rankIndex(String square) {
  if (square.length != 2) {
    return null;
  }
  final rank = square.codeUnitAt(1) - '1'.codeUnitAt(0);
  if (rank < 0 || rank > 7) {
    return null;
  }
  return rank;
}
