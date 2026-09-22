import 'package:chessnut_flutter_export/services/physical_board_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes legacy board payload into board-only FEN', () {
    final data = List<int>.filled(34, 0);
    final pieces = {
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

    void setSquare(int boardIndex, String piece) {
      final dataIndex = boardIndex ~/ 2 + 2;
      final value = pieces[piece]!;
      if (boardIndex.isEven) {
        data[dataIndex] = (data[dataIndex] & 0xf0) | value;
      } else {
        data[dataIndex] = (data[dataIndex] & 0x0f) | (value << 4);
      }
    }

    setSquare(7, 'r');
    setSquare(6, 'n');
    setSquare(5, 'b');
    setSquare(4, 'q');
    setSquare(3, 'k');
    setSquare(2, 'b');
    setSquare(1, 'n');
    setSquare(0, 'r');
    for (var i = 8; i < 16; i++) {
      setSquare(i, 'p');
    }
    for (var i = 48; i < 56; i++) {
      setSquare(i, 'P');
    }
    setSquare(63, 'R');
    setSquare(62, 'N');
    setSquare(61, 'B');
    setSquare(60, 'Q');
    setSquare(59, 'K');
    setSquare(58, 'B');
    setSquare(57, 'N');
    setSquare(56, 'R');

    expect(
      ChessnutBoardFenCodec.decode(data),
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
    );
  });

  test('decodes headerless Air board payload into board-only FEN', () {
    final data = List<int>.filled(32, 0);

    void setSquare(int boardIndex, String piece) {
      final dataIndex = boardIndex ~/ 2;
      final value = ChessnutBoardFenCodec.pieceToCode[piece]!;
      if (boardIndex.isEven) {
        data[dataIndex] = (data[dataIndex] & 0xf0) | value;
      } else {
        data[dataIndex] = (data[dataIndex] & 0x0f) | (value << 4);
      }
    }

    setSquare(59, 'K');

    expect(
      ChessnutBoardFenCodec.decode(data),
      '8/8/8/8/8/8/8/4K3',
    );
  });

  test('encodes LED squares using legacy byte order', () {
    final command = ChessnutLedCodec.ledCommandFromSquares({'a1', 'h8'});

    expect(command, [0x0a, 0x08, 0x01, 0, 0, 0, 0, 0, 0, 0x80]);
  });

  test('encodes queen-pawn file LEDs without shifting to king-pawn file', () {
    final command = ChessnutLedCodec.ledCommandFromSquares({'d7', 'd5'});

    expect(command[3], 0x10);
    expect(command[5], 0x10);
  });

  test('stores general Air Pro Go board commands from the original app', () {
    expect(ChessnutGeneralCommands.enableRealtimeFen, [0x21, 0x01, 0x00]);
    expect(ChessnutGeneralCommands.enableFileUploadMode, [0x21, 0x01, 0x01]);
    expect(ChessnutGeneralCommands.batteryStatus, [0x29, 0x01, 0x00]);
    expect(ChessnutGeneralCommands.bleVersion, [0x27, 0x01, 0x00]);
    expect(ChessnutGeneralCommands.mcuVersion, [0x27, 0x01, 0x01]);
    expect(ChessnutGeneralCommands.fileCount, [0x31, 0x01, 0x00]);
    expect(ChessnutGeneralCommands.startFileRead, [0x33, 0x01, 0x00]);
    expect(ChessnutGeneralCommands.readNextFileChunk, [0x34, 0x01, 0x01]);
    expect(ChessnutGeneralCommands.deleteFiles, [0x39, 0x01, 0x00]);
    expect(ChessnutGeneralCommands.setBeep(true), [0x1b, 0x01, 0x01]);
    expect(ChessnutGeneralCommands.setBeep(false), [0x1b, 0x01, 0x00]);
    expect(ChessnutGeneralCommands.beep(frequency: 1000, duration: 200),
        [0x0b, 0x04, 0x03, 0xe8, 0x00, 0xc8]);
  });

  test('encodes Move firmware update commands using the legacy protocol', () {
    expect(ChessnutMoveCommands.firmwareUpdateSupport, [0x41, 0x01, 0x24]);
    expect(ChessnutMoveCommands.connectWifi, [0x41, 0x01, 0x05]);
    expect(ChessnutMoveCommands.startWifiFirmwareUpdate, [0x41, 0x01, 0x0a]);
    expect(ChessnutMoveCommands.firmwareFileStatus, [0x41, 0x01, 0x22]);
    expect(
      ChessnutMoveCommands.setWifiSsid('网络'),
      [0x41, 7, 0x03, 0xe7, 0xbd, 0x91, 0xe7, 0xbb, 0x9c],
    );
    expect(
      ChessnutMoveCommands.setWifiPassword('abc'),
      [0x41, 4, 0x04, 0x61, 0x62, 0x63],
    );
    expect(
      ChessnutMoveCommands.beginFirmwareFileTransfer(
        totalChunks: 0x010203,
        md5Ascii: 'abc'.codeUnits,
      ),
      [0x41, 7, 0x21, 0x01, 0x02, 0x03, 0x61, 0x62, 0x63],
    );
    expect(
      ChessnutMoveCommands.firmwareFileChunk(
        index: 0x010203,
        data: [0xaa, 0xbb],
        crc32: 0x12345678,
      ),
      [
        0x41,
        10,
        0x22,
        0x01,
        0x02,
        0x03,
        0xaa,
        0xbb,
        0x12,
        0x34,
        0x56,
        0x78,
      ],
    );
  });

  test('parses Move firmware missing-chunk and completion responses', () {
    expect(
      ChessnutMoveFirmwareTransferResponse.missingChunkIndices(
        [0x41, 0x07, 0x22, 0, 0, 1, 0, 1, 2],
      ),
      [1, 258],
    );
    expect(
      ChessnutMoveFirmwareTransferResponse.isSuccessful(
        [0x41, 0x02, 0x23, 0x00],
      ),
      isTrue,
    );
    expect(
      ChessnutMoveFirmwareTransferResponse.isSuccessful(
        [0x41, 0x02, 0x23, 0x01],
      ),
      isFalse,
    );
  });

  test('parses general board battery and firmware responses', () {
    final battery = ChessnutGeneralBatteryStatus.parse([0x2a, 0x02, 77, 1]);
    expect(battery.level, 77);
    expect(battery.isCharging, isTrue);

    final bleVersion = ChessnutGeneralVersionResponse.parse([
      0x28,
      0x07,
      0x00,
      ...'BLE-1.2'.codeUnits,
      0x00,
    ]);
    expect(bleVersion, 'BLE-1.2');
  });

  test('parses general board OTG file count response', () {
    expect(ChessnutGeneralFileCountResponse.parse([0x32, 0x01, 3]), 3);
  });

  test('encodes Move target board command from FEN', () {
    final command = ChessnutMoveBoardCodec.setBoardCommand(
      '8/8/8/8/4P3/8/8/4K3',
      strictMode: true,
    );

    expect(command.first, 0x42);
    expect(command[1], 33);
    expect(command.length, 35);
    expect(command.last, 1);
  });

  test('encodes Move target board reverse command using legacy order', () {
    final normal = ChessnutMoveBoardCodec.setBoardCommand(
      '8/8/8/8/4P3/8/8/4K3',
      strictMode: true,
    );
    final reverse = ChessnutMoveBoardCodec.setBoardCommand(
      '8/8/8/8/4P3/8/8/4K3',
      strictMode: true,
      isReverse: true,
    );

    expect(normal, isNot(reverse));
    expect(reverse.first, 0x42);
    expect(reverse[1], 33);
    expect(reverse.length, 35);
    expect(reverse.last, 1);
  });

  test('encodes Move standard start command in firmware board order', () {
    final command = ChessnutMoveBoardCodec.setBoardCommand(
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    );

    expect(command, [
      0x42,
      0x21,
      0x58,
      0x23,
      0x31,
      0x85,
      0x44,
      0x44,
      0x44,
      0x44,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x77,
      0x77,
      0x77,
      0x77,
      0xa6,
      0xc9,
      0x9b,
      0x6a,
      0x00,
    ]);
  });

  test('encodes reversed Move board by rotating squares only', () {
    final command = ChessnutMoveBoardCodec.setBoardCommand(
      '8/8/8/8/8/8/8/4K3',
      isReverse: true,
    );

    expect(command[2], 0x00);
    expect(command[3], 0x00);
    expect(command[4], 0x0c);
    expect(command.skip(5).take(29), everyElement(0));
    expect(command.last, 0);
  });

  test('encodes Move realtime, battery, and piece status commands', () {
    expect(ChessnutMoveCommands.enableRealtimeFen, [0x21, 0x01, 0x00]);
    expect(ChessnutMoveCommands.batteryStatus, [0x41, 0x01, 0x0c]);
    expect(ChessnutMoveCommands.pieceStatus, [0x41, 0x01, 0x0b]);
    expect(ChessnutMoveCommands.getChannel, [0x41, 0x01, 0x13]);
    expect(ChessnutMoveCommands.fileCount, [0x41, 0x01, 0x15]);
    expect(ChessnutMoveCommands.readStoredGameFile, [0x41, 0x01, 0x16]);
    expect(ChessnutMoveCommands.deleteStoredGameFile, [0x41, 0x01, 0x17]);
    expect(ChessnutMoveCommands.setChannel(3), [0x41, 0x02, 0x14, 0x03]);
    expect(ChessnutMoveCommands.startPiecePairing(2), [0x41, 0x02, 0x0f, 0x02]);
    expect(ChessnutMoveCommands.finishPiecePairing(), [0x41, 0x01, 0x10]);
    expect(ChessnutMoveCommands.exitPiecePairing(), [0x41, 0x01, 0x11]);
    expect(ChessnutMoveCommands.firmwareVersion, [0x41, 0x01, 0x09]);
    expect(
        ChessnutMoveCommands.setPieceAutoPoweroff(true), [0x41, 0x02, 0x28, 1]);
  });

  test('encodes Move RGB LED squares using packed board order', () {
    final command = ChessnutMoveLedCodec.commandFromSquares({
      'a1': ChessnutMoveLedColor.red,
      'h8': ChessnutMoveLedColor.orange,
      'e4': ChessnutMoveLedColor.darkGreen,
    });

    expect(command.length, 34);
    expect(command[0], 0x43);
    expect(command[1], 0x20);
    expect(command[2], 0x07);
    expect(command.last, 0x10);
    expect(command.where((byte) => byte != 0).length, 5);
  });

  test('encodes Move RGB command with 4-bit color values', () {
    final ledData = List<int>.filled(64, 0);
    ledData[0] = ChessnutMoveLedColor.yellow.code;
    ledData[1] = ChessnutMoveLedColor.orange.code;
    ledData[2] = 18;
    ledData[3] = 18;

    final command = ChessnutMoveLedCodec.command(ledData);

    expect(command.last, 0x67);
    expect(command[32], 0xff);
  });

  test('parses Move battery response from full BLE packet and payload', () {
    final full = ChessnutMoveBatteryStatus.parse([0x41, 0x03, 0x0c, 1, 87]);
    final payload = ChessnutMoveBatteryStatus.parse([0, 42]);

    expect(full.isCharging, isTrue);
    expect(full.level, 87);
    expect(payload.isCharging, isFalse);
    expect(payload.level, 42);
  });

  test('parses Move firmware version response', () {
    expect(
      ChessnutMoveFirmwareVersionResponse.parse([
        0x41,
        0x06,
        0x09,
        ...'2.1.8'.codeUnits,
        0,
      ]),
      '2.1.8',
    );
    expect(
      ChessnutMoveFirmwareVersionResponse.parse('2.2.0'.codeUnits),
      '2.2.0',
    );
  });

  test('parses Move piece status response into piece records', () {
    final pieces = <int>[];
    for (var i = 0; i < 34; i++) {
      final identity = i == 33 ? 0 : i % 12 + 1;
      pieces.addAll([identity, i + 1, 255 - i, 100 - i]);
    }
    final statuses =
        ChessnutMovePieceStatus.parseResponse([0x41, 0x89, 0x0b, ...pieces]);

    expect(statuses, hasLength(34));
    expect(statuses.first.identity, 1);
    expect(statuses.first.fenChar, 'P');
    expect(statuses.first.rawX, 1);
    expect(statuses.first.rawY, 255);
    expect(statuses.first.batteryLevel, 100);
    expect(statuses.last.index, 34);
    expect(statuses.last.fenChar, 'k');
  });

  test('exposes known Chessnut BLE UUID contract', () {
    expect(
        ChessnutBleUuids.boardService, '1b7e8261-2877-41c3-b46e-cf057c562023');
    expect(ChessnutBleUuids.boardCharacteristic,
        '1b7e8262-2877-41c3-b46e-cf057c562023');
    expect(
        ChessnutBleUuids.readService, '1b7e8271-2877-41c3-b46e-cf057c562023');
    expect(ChessnutBleUuids.writeCharacteristic,
        '1b7e8272-2877-41c3-b46e-cf057c562023');
    expect(ChessnutBleUuids.readFileService,
        '1b7e8281-2877-41c3-b46e-cf057c562023');
  });
}
