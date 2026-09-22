import 'package:chessnut_flutter_export/services/board_settings_service.dart';
import 'package:chessnut_flutter_export/services/physical_board_orientation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const logicalStart =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  const reversedStart = 'RNBKQBNR/PPPPPPPP/8/8/8/8/pppppppp/rnbkqbnr';

  test('normalizes reversed physical FEN and maps output squares', () {
    final resolver = PhysicalBoardOrientationResolver();

    expect(
      resolver.normalize(reversedStart, referenceFens: [logicalStart]),
      logicalStart.split(' ').first,
    );
    expect(resolver.isReversed, isTrue);
    expect(resolver.toPhysicalSquares({'e2', 'e4'}), {'d7', 'd5'});
  });

  test('auto flip and flip permission settings are respected', () {
    final manual = PhysicalBoardOrientationResolver(
      settings: const BoardSettingsState(autoFlip: false),
    );
    final disabled = PhysicalBoardOrientationResolver(
      settings: const BoardSettingsState(allowFlip: false),
    );

    expect(
      manual.normalize(reversedStart, referenceFens: [logicalStart]),
      reversedStart,
    );
    expect(
      disabled.normalize(reversedStart, referenceFens: [logicalStart]),
      reversedStart,
    );
    expect(manual.isReversed, isFalse);
    expect(disabled.isReversed, isFalse);
  });

  test('manual Move action sets the physical orientation explicitly', () {
    final resolver = PhysicalBoardOrientationResolver(
      settings: const BoardSettingsState(allowFlip: false),
    );

    expect(
      resolver.setManualMapping(PhysicalBoardFenMapping.reversed),
      isTrue,
    );
    expect(
      resolver.normalize(reversedStart, referenceFens: [logicalStart]),
      logicalStart.split(' ').first,
    );
    expect(resolver.isReversed, isTrue);
  });

  test('locked mapping is not replaced by automatic FEN detection', () {
    final resolver = PhysicalBoardOrientationResolver();
    resolver.setManualMapping(PhysicalBoardFenMapping.reversed);

    expect(
      resolver.normalizeWithLockedMapping(
        logicalStart,
        referenceFens: [logicalStart],
      ),
      logicalStart.split(' ').first,
    );
    expect(resolver.isReversed, isTrue);
  });

  test('keeps a resolved mapping for lifted-piece intermediate FENs', () {
    final resolver = PhysicalBoardOrientationResolver();
    resolver.normalize(reversedStart, referenceFens: [logicalStart]);
    const reversedWithoutE2Pawn = 'RNBKQBNR/PPP1PPPP/8/8/8/8/pppppppp/rnbkqbnr';

    expect(
      resolver.normalize(
        reversedWithoutE2Pawn,
        referenceFens: [logicalStart],
      ),
      'rnbqkbnr/pppppppp/8/8/8/8/PPPP1PPP/RNBQKBNR',
    );
  });

  test('keeps identity mapping for ordinary setup differences', () {
    const wrongE5 = 'rnbqkbnr/pppppppp/8/4P3/8/8/PPPP1PPP/RNBQKBNR';

    expect(
      closestPhysicalBoardFenMapping(
        physicalFen: wrongE5,
        referenceFens: [logicalStart],
      ),
      PhysicalBoardFenMapping.identity,
    );
  });
}
