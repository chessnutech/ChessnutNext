import 'dart:convert';

class ChessnutBleUuids {
  const ChessnutBleUuids._();

  static const boardService = '1b7e8261-2877-41c3-b46e-cf057c562023';
  static const boardCharacteristic = '1b7e8262-2877-41c3-b46e-cf057c562023';
  static const readService = '1b7e8271-2877-41c3-b46e-cf057c562023';
  static const readCharacteristic = '1b7e8273-2877-41c3-b46e-cf057c562023';
  static const writeService = '1b7e8271-2877-41c3-b46e-cf057c562023';
  static const writeCharacteristic = '1b7e8272-2877-41c3-b46e-cf057c562023';
  static const readFileService = '1b7e8281-2877-41c3-b46e-cf057c562023';
  static const readFileCharacteristic = '1b7e8283-2877-41c3-b46e-cf057c562023';
}

class ChessnutMoveCommands {
  const ChessnutMoveCommands._();

  static const enableRealtimeFen = [0x21, 0x01, 0x00];
  static const batteryStatus = [0x41, 0x01, 0x0c];
  static const pieceStatus = [0x41, 0x01, 0x0b];
  static const getChannel = [0x41, 0x01, 0x13];
  static const fileCount = [0x41, 0x01, 0x15];
  static const readStoredGameFile = [0x41, 0x01, 0x16];
  static const deleteStoredGameFile = [0x41, 0x01, 0x17];
  static const discoverPieceChannel = [0x41, 0x01, 0x19];
  static const closeAllPieces = [0x41, 0x01, 0x18];
  static const getPieceData = [0x41, 0x01, 0x1b];
  static const pieceAutoPoweroffStatus = [0x41, 0x01, 0x27];
  static const firmwareVersion = [0x41, 0x01, 0x09];
  static const firmwareUpdateSupport = [0x41, 0x01, 0x24];
  static const connectWifi = [0x41, 0x01, 0x05];
  static const startWifiFirmwareUpdate = [0x41, 0x01, 0x0a];
  static const firmwareFileStatus = [0x41, 0x01, 0x22];

  static List<int> setWifiSsid(String ssid) {
    final bytes = utf8.encode(ssid);
    return [0x41, bytes.length + 1, 0x03, ...bytes];
  }

  static List<int> setWifiPassword(String password) {
    final bytes = utf8.encode(password);
    return [0x41, bytes.length + 1, 0x04, ...bytes];
  }

  static List<int> beginFirmwareFileTransfer({
    required int totalChunks,
    required List<int> md5Ascii,
  }) {
    return [
      0x41,
      md5Ascii.length + 4,
      0x21,
      (totalChunks >> 16) & 0xff,
      (totalChunks >> 8) & 0xff,
      totalChunks & 0xff,
      ...md5Ascii,
    ];
  }

  static List<int> firmwareFileChunk({
    required int index,
    required List<int> data,
    required int crc32,
  }) {
    return [
      0x41,
      data.length + 8,
      0x22,
      (index >> 16) & 0xff,
      (index >> 8) & 0xff,
      index & 0xff,
      ...data,
      (crc32 >> 24) & 0xff,
      (crc32 >> 16) & 0xff,
      (crc32 >> 8) & 0xff,
      crc32 & 0xff,
    ];
  }

  static List<int> setChannel(int channel) {
    final normalized = channel.clamp(0, 3);
    return [0x41, 0x02, 0x14, normalized];
  }

  static List<int> startPiecePairing(int channel) {
    final normalized = channel.clamp(0, 3);
    return [0x41, 0x02, 0x0f, normalized];
  }

  static List<int> finishPiecePairing() {
    return [0x41, 0x01, 0x10];
  }

  static List<int> exitPiecePairing() {
    return [0x41, 0x01, 0x11];
  }

  static List<int> setPieceAutoPoweroff(bool enabled) {
    return [0x41, 0x02, 0x28, enabled ? 1 : 0];
  }
}

class ChessnutGeneralCommands {
  const ChessnutGeneralCommands._();

  static const enableRealtimeFen = [0x21, 0x01, 0x00];
  static const enableFileUploadMode = [0x21, 0x01, 0x01];
  static const batteryStatus = [0x29, 0x01, 0x00];
  static const bleVersion = [0x27, 0x01, 0x00];
  static const mcuVersion = [0x27, 0x01, 0x01];
  static const fileCount = [0x31, 0x01, 0x00];
  static const startFileRead = [0x33, 0x01, 0x00];
  static const readNextFileChunk = [0x34, 0x01, 0x01];
  static const deleteFiles = [0x39, 0x01, 0x00];

  static List<int> setBeep(bool enabled) {
    return [0x1b, 0x01, enabled ? 0x01 : 0x00];
  }

  static List<int> beep({int frequency = 1000, int duration = 200}) {
    return [
      0x0b,
      0x04,
      (frequency >> 8) & 0xff,
      frequency & 0xff,
      (duration >> 8) & 0xff,
      duration & 0xff,
    ];
  }
}

class ChessnutMoveFirmwareVersionResponse {
  const ChessnutMoveFirmwareVersionResponse._();

  static String parse(List<int> data) {
    final payload = _stripMoveResponseHeader(data, 0x09);
    return String.fromCharCodes(
      payload.where((byte) => byte != 0),
    ).trim();
  }
}

class ChessnutMoveCommandResponse {
  const ChessnutMoveCommandResponse._();

  static List<int>? payload(List<int>? data, int commandCode) {
    if (data == null ||
        data.length < 3 ||
        data[0] != 0x41 ||
        data[2] != commandCode) {
      return null;
    }
    return data.sublist(3);
  }

  static bool isSuccess(List<int>? data, int commandCode) {
    final value = payload(data, commandCode);
    return value != null && value.isNotEmpty && value.first == 0;
  }
}

class ChessnutMoveFirmwareTransferResponse {
  const ChessnutMoveFirmwareTransferResponse._();

  static bool isChunkRequest(List<int>? data) {
    return data != null &&
        data.length >= 3 &&
        data[0] == 0x41 &&
        data[2] == 0x22;
  }

  static bool isComplete(List<int>? data) {
    return data != null &&
        data.length >= 3 &&
        data[0] == 0x41 &&
        data[2] == 0x23;
  }

  static bool isSuccessful(List<int>? data) {
    return isComplete(data) && data!.length >= 4 && data[3] == 0;
  }

  static List<int>? missingChunkIndices(List<int> data) {
    if (!isChunkRequest(data) || data.length < 3) return null;
    final count = (data[1] - 1) ~/ 3;
    if (count < 0 || data.length < 3 + count * 3) return null;
    return List<int>.generate(count, (index) {
      final offset = 3 + index * 3;
      return (data[offset] << 16) | (data[offset + 1] << 8) | data[offset + 2];
    }, growable: false);
  }
}

class ChessnutBoardFenCodec {
  const ChessnutBoardFenCodec._();

  static const pieces = [
    '0',
    'q',
    'k',
    'b',
    'p',
    'n',
    'R',
    'P',
    'r',
    'B',
    'N',
    'Q',
    'K',
    '0',
    '0',
    '0',
    '0',
    '0',
    '0',
    '0',
    '0',
    '0',
    '0',
    '0',
    '0',
    '0',
    '0',
    '0',
    '0',
    '0',
    '0',
  ];

  static const pieceToCode = {
    '0': 0,
    'q': 1,
    'k': 2,
    'b': 3,
    'p': 4,
    'n': 5,
    'R': 6,
    'P': 7,
    'r': 8,
    'B': 9,
    'N': 10,
    'Q': 11,
    'K': 12,
  };

  static String? tryDecode(List<int> data) {
    try {
      return decode(data);
    } catch (_) {
      return null;
    }
  }

  static String decode(List<int> data) {
    final payloadOffset = _fenPayloadOffset(data);
    if (payloadOffset == null) {
      throw const FormatException('Chessnut board payload is too short.');
    }

    final rows = <String>[];
    for (var rank = 0; rank < 8; rank++) {
      var empty = 0;
      final row = StringBuffer();
      for (var file = 7; file >= 0; file--) {
        final boardIndex = rank * 8 + file;
        final dataIndex = boardIndex ~/ 2 + payloadOffset;
        final encoded =
            file.isEven ? data[dataIndex] & 0x0f : data[dataIndex] >> 4;
        final piece = encoded < pieces.length ? pieces[encoded] : '0';
        if (piece == '0') {
          empty++;
        } else {
          if (empty > 0) {
            row.write(empty);
            empty = 0;
          }
          row.write(piece);
        }
      }
      if (empty > 0) {
        row.write(empty);
      }
      rows.add(row.toString());
    }
    return rows.join('/');
  }

  static int? _fenPayloadOffset(List<int> data) {
    if (data.length >= 34) return 2;
    if (data.length == 33) return 1;
    if (data.length == 32) return 0;
    return null;
  }
}

class ChessnutLedCodec {
  const ChessnutLedCodec._();

  static List<int> ledCommandFromSquares(Set<String> squares) {
    final ledData = List<int>.filled(64, 0);
    for (final square in squares) {
      final index = _squareToIndex(square);
      if (index != null) {
        ledData[index] = 1;
      }
    }
    return ledCommand(ledData);
  }

  static List<int> ledCommand(List<int> ledData) {
    if (ledData.length != 64) {
      throw ArgumentError.value(ledData.length, 'ledData.length');
    }

    final bytes = <int>[];
    for (var rank = 7; rank >= 0; rank--) {
      var byte = 0;
      for (var file = 0; file < 8; file++) {
        if (ledData[rank * 8 + file] != 0) {
          byte |= 1 << (7 - file);
        }
      }
      bytes.add(byte);
    }
    return [0x0a, 0x08, ...bytes];
  }
}

class ChessnutMoveBoardCodec {
  const ChessnutMoveBoardCodec._();

  static List<int> setBoardCommand(
    String fen, {
    bool strictMode = false,
    bool isReverse = false,
  }) {
    final boardOnlyFen = fen.trim().split(RegExp(r'\s+')).first;
    final squares = _expandFenBySquareIndex(boardOnlyFen);
    final data = <int>[];

    final range = isReverse
        ? Iterable<int>.generate(32)
        : Iterable<int>.generate(32, (index) => 31 - index);

    for (final index in range) {
      final lowIndex = isReverse ? index * 2 : index * 2 + 1;
      final highIndex = isReverse ? index * 2 + 1 : index * 2;
      final low = _pieceCodeForMoveBoard(squares[lowIndex]);
      final high = _pieceCodeForMoveBoard(squares[highIndex]);
      data.add(low + (high << 4));
    }

    data.add(strictMode ? 1 : 0);
    return [0x42, 33, ...data];
  }

  static List<int> stopCommand() {
    return [0x42, 33, ...List<int>.filled(33, 0)];
  }
}

enum ChessnutMoveLedColor {
  off(0),
  red(1),
  green(2),
  blue(3),
  darkGreen(4),
  brightGreen(5),
  yellow(6),
  orange(7);

  const ChessnutMoveLedColor(this.code);

  final int code;
}

class ChessnutMoveLedCodec {
  const ChessnutMoveLedCodec._();

  static List<int> commandFromSquares(
      Map<String, ChessnutMoveLedColor> colors) {
    final ledData = List<int>.filled(64, 0);
    for (final entry in colors.entries) {
      final index = _squareToIndex(entry.key);
      if (index != null) {
        ledData[index] = entry.value.code;
      }
    }
    return command(ledData);
  }

  static List<int> command(List<int> ledData) {
    if (ledData.length != 64) {
      throw ArgumentError.value(ledData.length, 'ledData.length');
    }

    final bytes = <int>[];
    for (var index = 31; index >= 0; index--) {
      final low = ledData[index * 2 + 1].clamp(0, 15);
      final high = ledData[index * 2].clamp(0, 15);
      bytes.add(low + (high << 4));
    }
    return [0x43, 0x20, ...bytes];
  }

  static List<int> offCommand() {
    return command(List<int>.filled(64, 0));
  }
}

class ChessnutMoveBatteryStatus {
  const ChessnutMoveBatteryStatus({
    required this.level,
    required this.isCharging,
  });

  final int level;
  final bool isCharging;

  static ChessnutMoveBatteryStatus parse(List<int> data) {
    final payload = _stripMoveResponseHeader(data, 0x0c);
    if (payload.length < 2) {
      throw const FormatException('Move battery response is too short.');
    }
    return ChessnutMoveBatteryStatus(
      isCharging: payload[0] == 1,
      level: payload[1].clamp(0, 100),
    );
  }
}

class ChessnutGeneralBatteryStatus {
  const ChessnutGeneralBatteryStatus({
    required this.level,
    required this.isCharging,
  });

  final int level;
  final bool isCharging;

  static ChessnutGeneralBatteryStatus parse(List<int> data) {
    if (data.length < 4 || data[0] != 0x2a) {
      throw const FormatException(
          'General board battery response is malformed.');
    }
    return ChessnutGeneralBatteryStatus(
      level: data[2].clamp(0, 100),
      isCharging: data[3] == 1,
    );
  }
}

class ChessnutGeneralVersionResponse {
  const ChessnutGeneralVersionResponse._();

  static String parse(List<int> data) {
    if (data.length < 4 || data[0] != 0x28) {
      throw const FormatException(
          'General board version response is malformed.');
    }
    final payloadLength = data[1];
    final end = (3 + payloadLength).clamp(3, data.length);
    return String.fromCharCodes(
      data.sublist(3, end).where((byte) => byte != 0),
    );
  }
}

class ChessnutGeneralFileCountResponse {
  const ChessnutGeneralFileCountResponse._();

  static int parse(List<int> data) {
    if (data.length < 3 || data[0] != 0x32) {
      throw const FormatException(
          'General board file count response is malformed.');
    }
    return data[2];
  }
}

class ChessnutMovePieceStatus {
  const ChessnutMovePieceStatus({
    required this.index,
    required this.identity,
    required this.rawX,
    required this.rawY,
    required this.batteryLevel,
  });

  final int index;
  final int identity;
  final int rawX;
  final int rawY;
  final int batteryLevel;

  bool get isOutOfBoard => rawX == 0 && rawY == 0;

  bool get isOnBoard => !isOutOfBoard;

  double get boardX => isOnBoard ? (255 - rawY).toDouble() : rawY.toDouble();

  double get boardY => isOnBoard ? (255 - rawX).toDouble() : rawX.toDouble();

  String get fenChar => pieceIdentityToFen[identity] ?? pieceOrder[index - 1];

  static const pieceIdentityToFen = {
    1: 'P',
    2: 'R',
    3: 'N',
    4: 'B',
    5: 'Q',
    6: 'K',
    7: 'p',
    8: 'r',
    9: 'n',
    10: 'b',
    11: 'q',
    12: 'k',
  };

  static const pieceOrder = [
    'P',
    'P',
    'P',
    'P',
    'P',
    'P',
    'P',
    'P',
    'R',
    'R',
    'N',
    'N',
    'B',
    'B',
    'Q',
    'Q',
    'K',
    'p',
    'p',
    'p',
    'p',
    'p',
    'p',
    'p',
    'p',
    'r',
    'r',
    'n',
    'n',
    'b',
    'b',
    'q',
    'q',
    'k',
  ];

  static List<ChessnutMovePieceStatus> parseResponse(List<int> data) {
    final payload = _stripMoveResponseHeader(data, 0x0b);
    if (payload.length < 4 || payload.length % 4 != 0) {
      throw const FormatException('Move piece status response is malformed.');
    }

    final count = payload.length ~/ 4;
    return [
      for (var i = 0; i < count; i++)
        ChessnutMovePieceStatus(
          index: i + 1,
          identity: payload[i * 4],
          rawX: payload[i * 4 + 1],
          rawY: payload[i * 4 + 2],
          batteryLevel: payload[i * 4 + 3].clamp(0, 100),
        ),
    ];
  }
}

List<String> _expandFenBySquareIndex(String boardOnlyFen) {
  final rows = boardOnlyFen.split('/');
  if (rows.length != 8) {
    throw FormatException('Invalid board FEN: $boardOnlyFen');
  }

  final squares = List<String>.filled(64, '0');
  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    final rank = 7 - rowIndex;
    var file = 0;
    for (final char in rows[rowIndex].split('')) {
      final digit = int.tryParse(char);
      if (digit != null) {
        file += digit;
      } else {
        if (file >= 8) {
          throw FormatException('Invalid board FEN: $boardOnlyFen');
        }
        squares[rank * 8 + file] = char;
        file += 1;
      }
    }
    if (file != 8) {
      throw FormatException('Invalid board FEN: $boardOnlyFen');
    }
  }
  return squares;
}

int _pieceCodeForMoveBoard(String piece) {
  return ChessnutBoardFenCodec.pieceToCode[piece] ?? 0;
}

int? _squareToIndex(String square) {
  if (square.length != 2) {
    return null;
  }
  final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = square.codeUnitAt(1) - '1'.codeUnitAt(0);
  if (file < 0 || file > 7 || rank < 0 || rank > 7) {
    return null;
  }
  return rank * 8 + file;
}

List<int> _stripMoveResponseHeader(List<int> data, int commandCode) {
  if (data.length >= 3 && data[0] == 0x41 && data[2] == commandCode) {
    return data.sublist(3);
  }
  return data;
}
