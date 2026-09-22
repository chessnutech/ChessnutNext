import 'package:chessnut_flutter_export/services/easy_link_sdk_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identifies EasyLink HID product ranges for supported boards', () {
    expect(
        EasyLinkHidProducts.modelForProductId(0x8002), EasyLinkBoardModel.air);
    expect(
        EasyLinkHidProducts.modelForProductId(0x8120), EasyLinkBoardModel.pro);
    expect(EasyLinkHidProducts.modelForProductId(0x8201),
        EasyLinkBoardModel.airPlus);
    expect(
        EasyLinkHidProducts.modelForProductId(0x8500), EasyLinkBoardModel.go);
    expect(EasyLinkHidProducts.modelForProductId(0x9000), isNull);
    expect(EasyLinkHidProducts.isSupported(0x2d80, 0x8500), isTrue);
    expect(EasyLinkHidProducts.isSupported(0x1234, 0x8500), isFalse);
  });

  test('detects Air+ from EasyLink hardware text', () {
    expect(easyLinkBoardModelFromText('Chessnut Air+ v2.1'),
        EasyLinkBoardModel.airPlus);
    expect(easyLinkBoardModelFromText('Chessnut Air Plus BLE'),
        EasyLinkBoardModel.airPlus);
    expect(
        easyLinkBoardModelFromText('Chessnut Air II'), EasyLinkBoardModel.air);
    expect(easyLinkBoardModelFromText('Chessnut Air2'), EasyLinkBoardModel.air);
    expect(easyLinkBoardModelFromText('Chessnut Air'), EasyLinkBoardModel.air);
  });

  test('converts square set into EasyLink LED rows', () {
    final rows = EasyLinkLedMatrixCodec.rowsFromSquares({'a8', 'c4', 'h1'});

    expect(rows, [
      '10000000',
      '00000000',
      '00000000',
      '00000000',
      '00100000',
      '00000000',
      '00000000',
      '00000001',
    ]);
  });

  test('documents EasyLink C ABI symbols and buffer sizes', () {
    expect(EasyLinkCAbi.connect, 'cl_connect');
    expect(EasyLinkCAbi.disconnect, 'cl_disconnect');
    expect(EasyLinkCAbi.setRealtimeCallback, 'cl_set_readtime_callback');
    expect(EasyLinkCAbi.switchRealtimeMode, 'cl_switch_real_time_mode');
    expect(EasyLinkCAbi.led, 'cl_led');
    expect(EasyLinkCAbi.sdkVersionBufferLength, 20);
    expect(EasyLinkCAbi.hardwareVersionBufferLength, 100);
    expect(EasyLinkCAbi.fileCount, 'cl_get_file_count');
    expect(EasyLinkCAbi.getFileAndKeep, 'cl_get_file_and_keep');
    expect(EasyLinkCAbi.getFileAndDelete, 'cl_get_file_and_delete');
    expect(EasyLinkCAbi.recommendedGameFileBufferLength, 10 * 1024);
  });

  test('resolves platform dynamic library names', () {
    expect(
        EasyLinkDynamicLibrary.fileNameForPlatform('windows'), 'easylink.dll');
    expect(EasyLinkDynamicLibrary.fileNameForPlatform('macos'),
        'libeasylink.dylib');
    expect(
        EasyLinkDynamicLibrary.fileNameForPlatform('linux'), 'libeasylink.so');
  });
}
