import 'package:chessnut_flutter_export/services/course_lesson_engine.dart';
import 'package:chessnut_flutter_export/services/course_lesson_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CourseScriptItem checkpoint({
    int startTime = 1000,
    String? destFen,
    bool waitForFen = false,
    List<int>? led,
    List<int>? ledWhenContinue,
  }) {
    return CourseScriptItem(
      startTime: Duration(milliseconds: startTime),
      checkpointTitle: 'Checkpoint',
      startTimePause: true,
      destFen: destFen,
      destFenMatchToContinue: waitForFen,
      led: led,
      ledWhenContinue: ledWhenContinue,
    );
  }

  CourseScriptItem scriptItem({
    required int startTime,
    required String destFen,
  }) {
    return CourseScriptItem(
      startTime: Duration(milliseconds: startTime),
      destFen: destFen,
    );
  }

  List<int> ledForSquares(Iterable<String> squares) {
    final led = List<int>.filled(64, 0);
    for (final square in squares) {
      final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rank = int.parse(square[1]);
      led[(8 - rank) * 8 + file] = 1;
    }
    return led;
  }

  test('advance starts a pause checkpoint exactly once in trigger window', () {
    final item = checkpoint(destFen: '8/8/8/8/8/8/8/8 w - - 0 1');
    final engine = CourseLessonEngine(scriptItems: [item]);

    final first = engine.advance(const Duration(milliseconds: 1100));
    final second = engine.advance(const Duration(milliseconds: 1150));

    expect(first.shouldPauseVideo, isTrue);
    expect(first.runningCheckpoint, item);
    expect(first.boardFen, item.destFen);
    expect(first.boardFenChanged, isTrue);
    expect(second.shouldPauseVideo, isFalse);
    expect(second.runningCheckpoint, item);
  });

  test('advance starts a pause checkpoint when playback crosses it', () {
    final item = checkpoint(
      startTime: 1000,
      destFen: '8/8/8/8/8/8/8/8 w - - 0 1',
      led: ledForSquares({'e4'}),
    );
    final engine = CourseLessonEngine(scriptItems: [item]);

    engine.advance(const Duration(milliseconds: 900));
    final crossed = engine.advance(const Duration(milliseconds: 1400));

    expect(crossed.shouldPauseVideo, isTrue);
    expect(crossed.runningCheckpoint, item);
    expect(crossed.ledSquares, contains('e4'));
    expect(crossed.physicalLedSquares, contains('e4'));
  });

  test('advance keeps lesson board at latest dest fen on the timeline', () {
    const firstFen = '8/8/8/8/8/8/8/8 w - - 0 1';
    const secondFen = '8/8/8/8/4N3/8/8/8 w - - 0 1';
    final engine = CourseLessonEngine(
      scriptItems: [
        scriptItem(startTime: 1000, destFen: firstFen),
        scriptItem(startTime: 3000, destFen: secondFen),
      ],
    );

    final before = engine.advance(const Duration(milliseconds: 500));
    final first = engine.advance(const Duration(milliseconds: 2500));
    final repeat = engine.advance(const Duration(milliseconds: 2600));
    final second = engine.advance(const Duration(milliseconds: 3500));

    expect(before.boardFenChanged, isFalse);
    expect(first.boardFen, firstFen);
    expect(first.boardFenChanged, isTrue);
    expect(repeat.boardFenChanged, isFalse);
    expect(second.boardFen, secondFen);
    expect(second.boardFenChanged, isTrue);
  });

  test('non-pause lesson highlights do not light the physical board', () {
    final highlight = CourseScriptItem(
      startTime: const Duration(milliseconds: 1000),
      led: ledForSquares({'a7', 'b7', 'c7', 'd7'}),
    );
    final checkpointItem = checkpoint(
      startTime: 2000,
      destFen: '8/8/8/8/8/5N2/8/8 w - - 0 1',
      waitForFen: true,
      led: ledForSquares({'f3'}),
    );
    final engine = CourseLessonEngine(
      scriptItems: [highlight, checkpointItem],
    );

    final highlightEvent = engine.advance(const Duration(milliseconds: 1100));
    final checkpointEvent = engine.advance(const Duration(milliseconds: 2100));

    expect(highlightEvent.shouldPauseVideo, isFalse);
    expect(highlightEvent.ledSquares, containsAll(['a7', 'd7']));
    expect(highlightEvent.physicalLedSquares, isEmpty);
    expect(checkpointEvent.shouldPauseVideo, isTrue);
    expect(checkpointEvent.physicalLedSquares, contains('f3'));
  });

  test(
    'manual playback past a checkpoint releases it for later checkpoints',
    () {
      final first = checkpoint(startTime: 1000);
      final second = checkpoint(startTime: 3000);
      final engine = CourseLessonEngine(scriptItems: [first, second]);

      final firstPause = engine.advance(const Duration(milliseconds: 1000));
      final released = engine.advance(const Duration(milliseconds: 1400));
      final secondPause = engine.advance(const Duration(milliseconds: 3000));

      expect(firstPause.shouldPauseVideo, isTrue);
      expect(firstPause.runningCheckpoint, first);
      expect(released.shouldResumeVideo, isTrue);
      expect(released.runningCheckpoint, isNull);
      expect(secondPause.shouldPauseVideo, isTrue);
      expect(secondPause.runningCheckpoint, second);
    },
  );

  test('repeated destination checkpoint recognizes an already matched board',
      () {
    const destination = '8/8/8/8/8/8/PPPPPPPP/8 w - - 0 1';
    final first = checkpoint(
      startTime: 1000,
      destFen: destination,
      waitForFen: true,
    );
    final second = checkpoint(
      startTime: 3000,
      destFen: destination,
      waitForFen: true,
    );
    final engine = CourseLessonEngine(scriptItems: [first, second]);

    engine.advance(const Duration(milliseconds: 1000));
    engine.handleBoardFen(destination);
    engine.advance(const Duration(milliseconds: 3000));

    expect(engine.canConfirmExistingBoardFen(second, destination), isTrue);
  });

  test(
    'board-matching checkpoint waits past trigger window until FEN matches',
    () {
      final item = checkpoint(
        destFen: '8/8/8/8/8/5N2/8/8 w - - 0 1',
        waitForFen: true,
      );
      final engine = CourseLessonEngine(scriptItems: [item]);

      final firstPause = engine.advance(const Duration(milliseconds: 1000));
      final stillWaiting = engine.advance(const Duration(milliseconds: 1400));
      final event = engine.handleBoardFen('8/8/8/8/8/5N2/8/8');

      expect(firstPause.shouldPauseVideo, isTrue);
      expect(stillWaiting.shouldResumeVideo, isFalse);
      expect(stillWaiting.runningCheckpoint, item);
      expect(event.shouldResumeVideo, isTrue);
      expect(engine.checkedCheckpoints, contains(item));
    },
  );

  test(
    'pause checkpoint with a target FEN keeps waiting until the board matches',
    () {
      final item = checkpoint(
        destFen: '8/8/8/8/8/5N2/8/8 w - - 0 1',
      );
      final engine = CourseLessonEngine(scriptItems: [item]);

      final firstPause = engine.advance(const Duration(milliseconds: 1000));
      final stillWaiting = engine.advance(const Duration(milliseconds: 1800));
      final matched = engine.handleBoardFen('8/8/8/8/8/5N2/8/8');

      expect(firstPause.shouldPauseVideo, isTrue);
      expect(stillWaiting.shouldResumeVideo, isFalse);
      expect(stillWaiting.runningCheckpoint, item);
      expect(matched.shouldResumeVideo, isTrue);
      expect(engine.checkedCheckpoints, contains(item));
    },
  );

  test(
    'waiting checkpoint yields when playback crosses a later checkpoint',
    () {
      final first = checkpoint(
        startTime: 1000,
        destFen: '8/8/8/8/8/5N2/8/8 w - - 0 1',
        led: ledForSquares({'f3'}),
      );
      final second = checkpoint(
        startTime: 3000,
        destFen: '8/8/3N4/8/8/8/8/8 w - - 0 1',
        led: ledForSquares({'d6'}),
      );
      final engine = CourseLessonEngine(scriptItems: [first, second]);

      final firstPause = engine.advance(const Duration(milliseconds: 1000));
      final secondPause = engine.advance(const Duration(milliseconds: 3500));

      expect(firstPause.shouldPauseVideo, isTrue);
      expect(firstPause.runningCheckpoint, first);
      expect(secondPause.shouldPauseVideo, isTrue);
      expect(secondPause.runningCheckpoint, second);
      expect(secondPause.ledSquares, contains('d6'));
    },
  );

  test('rook lesson setup checkpoint narrows broad route LEDs on the board',
      () {
    final item = checkpoint(
      destFen: '8/8/8/8/8/3R4/8/8 w - - 0 1',
      waitForFen: true,
      led: ledForSquares({
        'd8',
        'd7',
        'd6',
        'd5',
        'd4',
        'a3',
        'b3',
        'c3',
        'd3',
        'e3',
        'f3',
        'g3',
        'h3',
        'd2',
        'd1',
      }),
    );
    final engine = CourseLessonEngine(scriptItems: [item]);

    final event = engine.advance(const Duration(milliseconds: 1000));

    expect(event.ledSquares, containsAll(['d8', 'a3', 'h3', 'd1']));
    expect(event.physicalLedSquares, {'d3'});
  });

  test('move checkpoint keeps compact source and target LEDs on the board', () {
    final first = checkpoint(
      startTime: 1000,
      destFen: 'r6r/8/8/8/8/8/8/R6R w - - 0 1',
      waitForFen: true,
      led: ledForSquares({'a8', 'h8', 'a1', 'h1'}),
    );
    final second = checkpoint(
      startTime: 2000,
      destFen: 'r6r/8/8/8/8/8/8/3R3R w - - 0 1',
      waitForFen: true,
      led: ledForSquares({'a1', 'd1'}),
    );
    final engine = CourseLessonEngine(scriptItems: [first, second]);
    engine.seek(const Duration(milliseconds: 1500));

    final event = engine.advance(const Duration(milliseconds: 2000));

    expect(event.physicalLedSquares, {'a1', 'd1'});
  });

  test('pause checkpoint without LED data falls back to target squares', () {
    final item = checkpoint(
      destFen: '8/pppppppp/8/8/8/8/PPPPPPPP/8 w - - 0 1',
      waitForFen: true,
    );
    final engine = CourseLessonEngine(scriptItems: [item]);

    final event = engine.advance(const Duration(milliseconds: 1000));

    expect(event.shouldPauseVideo, isTrue);
    expect(event.ledSquares, containsAll(['a2', 'h2', 'a7', 'h7']));
    expect(event.physicalLedSquares, containsAll(['a2', 'h2', 'a7', 'h7']));
  });

  test('later checkpoint without LED data falls back to changed squares', () {
    final first = checkpoint(
      startTime: 1000,
      destFen: '8/pppppppp/8/8/8/8/PPPPPPPP/8 w - - 0 1',
      waitForFen: true,
      led: ledForSquares({'a2'}),
    );
    final second = checkpoint(
      startTime: 2000,
      destFen: '8/pppp1ppp/8/4p3/8/8/PPPPPPPP/8 w - - 0 1',
      waitForFen: true,
    );
    final engine = CourseLessonEngine(scriptItems: [first, second]);

    final event = engine.jumpToCheckpoint(second);

    expect(event.shouldPauseVideo, isTrue);
    expect(event.ledSquares, containsAll(['e7', 'e5']));
    expect(event.physicalLedSquares, containsAll(['e7', 'e5']));
    expect(event.ledSquares, isNot(contains('a2')));
  });

  test('seeking before a checkpoint lets it pause again', () {
    final item = checkpoint(startTime: 1000);
    final engine = CourseLessonEngine(scriptItems: [item]);

    final firstPause = engine.advance(const Duration(milliseconds: 1000));
    final before = engine.advance(const Duration(milliseconds: 500));
    final secondPause = engine.advance(const Duration(milliseconds: 1000));

    expect(firstPause.shouldPauseVideo, isTrue);
    expect(before.runningCheckpoint, isNull);
    expect(secondPause.shouldPauseVideo, isTrue);
    expect(secondPause.runningCheckpoint, item);
  });

  test('handleBoardFen resumes checkpoint when board-only FEN matches', () {
    final item = checkpoint(
      destFen: '8/8/8/8/8/5N2/8/8 w - - 0 1',
      waitForFen: true,
    );
    final engine = CourseLessonEngine(scriptItems: [item]);
    engine.advance(const Duration(milliseconds: 1000));

    final event = engine.handleBoardFen('8/8/8/8/8/5N2/8/8');

    expect(event.shouldResumeVideo, isTrue);
    expect(event.runningCheckpoint, isNull);
    expect(engine.checkedCheckpoints, contains(item));
  });

  test('handleBoardFen accepts inverted piece colors for swapped sets', () {
    final item = checkpoint(
      destFen: '8/8/8/8/8/5N2/8/8 w - - 0 1',
      waitForFen: true,
    );
    final engine = CourseLessonEngine(scriptItems: [item]);
    engine.advance(const Duration(milliseconds: 1000));

    final event = engine.handleBoardFen('8/8/8/8/8/5n2/8/8');

    expect(event.shouldResumeVideo, isTrue);
  });

  test('handleBoardFen accepts a physically reversed board orientation', () {
    final item = checkpoint(
      destFen: '8/1k6/2p1r3/1p6/8/PP1N4/8/1K6 w - - 0 1',
      waitForFen: true,
    );
    final engine = CourseLessonEngine(scriptItems: [item]);
    engine.advance(const Duration(milliseconds: 1000));

    final reversedFen = CourseLessonEngine.reverseBoardFen(item.destFen!);
    final event = engine.handleBoardFen(reversedFen);

    expect(event.shouldResumeVideo, isTrue);
    expect(event.boardFlipped, isTrue);
  });

  test('pawn-only checkpoints do not accept a reversed board as correct', () {
    final item = checkpoint(
      destFen: '8/pppp4/8/8/8/8/PPPP4/8 w - - 0 1',
      waitForFen: true,
    );
    final engine = CourseLessonEngine(scriptItems: [item]);
    engine.advance(const Duration(milliseconds: 1000));

    final event = engine.handleBoardFen(
      CourseLessonEngine.reverseBoardFen(item.destFen!),
    );

    expect(event.shouldResumeVideo, isFalse);
    expect(engine.checkedCheckpoints, isNot(contains(item)));
  });

  test('closestExpectedFenForBoard follows locked reversed orientation', () {
    final item = checkpoint(
      destFen: '8/1k6/2p1r3/1p6/8/PP1N4/8/1K6 w - - 0 1',
      waitForFen: true,
    );
    final engine = CourseLessonEngine(scriptItems: [item]);
    engine.advance(const Duration(milliseconds: 1000));

    final reversedFen = CourseLessonEngine.reverseBoardFen(item.destFen!);
    final event = engine.handleBoardFen(reversedFen);

    expect(event.shouldResumeVideo, isTrue);
    expect(
      engine.closestExpectedFenForBoard(reversedFen, item.destFen!),
      reversedFen,
    );
  });

  test('lesson-style LED hints stay unchanged for normal orientation', () {
    final item = checkpoint(
      destFen: 'r7/8/8/8/8/R7/8/8 w - - 0 1',
      waitForFen: true,
      led: ledForSquares(['a8', 'a6']),
    );
    final engine = CourseLessonEngine(scriptItems: [item]);

    final ledSquares = engine.ledSquaresForBoard(
      item.led,
      physicalFen: item.destFen,
      expectedFen: item.destFen,
    );

    expect(ledSquares, containsAll(['a8', 'a6']));
    expect(ledSquares, isNot(contains('h1')));
    expect(ledSquares, isNot(contains('h3')));
  });

  test('setup LEDs do not flip for a weak unlocked orientation guess', () {
    const previousLesson20Fen = '1r1k2R1/7p/pP6/2n5/6K1/6P1/2P4P/8 w - - 0 1';
    const lesson20SetupFen =
        '3R4/3Pkp2/8/1p2b1p1/1P2p1P1/2PbK3/1P6/8 w - - 0 1';
    final item = checkpoint(
      destFen: lesson20SetupFen,
      waitForFen: true,
      led: ledForSquares(['d8', 'd7', 'e7', 'f7']),
    );
    final engine = CourseLessonEngine(scriptItems: [item]);

    final ledSquares = engine.ledSquaresForBoard(
      item.led,
      physicalFen: previousLesson20Fen,
      expectedFen: lesson20SetupFen,
    );

    expect(ledSquares, containsAll(['d8', 'd7', 'e7', 'f7']));
    expect(ledSquares, isNot(contains('e1')));
    expect(ledSquares, isNot(contains('e2')));
    expect(ledSquares, isNot(contains('d2')));
    expect(ledSquares, isNot(contains('c2')));
  });

  test('lesson-style LED hints follow locked reversed board orientation', () {
    final item = checkpoint(
      destFen: 'r7/8/8/8/8/R7/8/8 w - - 0 1',
      waitForFen: true,
      led: ledForSquares(['a8', 'a6']),
    );
    final engine = CourseLessonEngine(scriptItems: [item]);
    engine.advance(const Duration(milliseconds: 1000));

    final reversedFen = CourseLessonEngine.reverseBoardFen(item.destFen!);
    final event = engine.handleBoardFen(reversedFen);
    final ledSquares = engine.ledSquaresForBoard(
      item.led,
      physicalFen: reversedFen,
      expectedFen: item.destFen,
    );

    expect(event.shouldResumeVideo, isTrue);
    expect(ledSquares, containsAll(['h1', 'h3']));
    expect(ledSquares, isNot(contains('a8')));
    expect(ledSquares, isNot(contains('a6')));
  });

  test(
    'jumped checkpoint keeps display and physical LED coordinates separate',
    () {
      final first = checkpoint(
        startTime: 1000,
        destFen: '8/1k6/2p1r3/1p6/8/PP1N4/8/1K6 w - - 0 1',
        waitForFen: true,
      );
      final second = checkpoint(
        startTime: 2000,
        destFen: 'r7/8/8/8/8/R7/8/8 w - - 0 1',
        waitForFen: true,
        led: ledForSquares(['a8', 'a6']),
      );
      final engine = CourseLessonEngine(scriptItems: [first, second]);
      engine.advance(const Duration(milliseconds: 1000));
      engine.handleBoardFen(CourseLessonEngine.reverseBoardFen(first.destFen!));

      final jump = engine.jumpToCheckpoint(second);

      expect(jump.boardFlipped, isTrue);
      expect(jump.ledSquares, containsAll(['a8', 'a6']));
      expect(jump.ledSquares, isNot(contains('h1')));
      expect(jump.ledSquares, isNot(contains('h3')));
      expect(jump.physicalLedSquares, containsAll(['h1', 'h3']));
      expect(jump.physicalLedSquares, isNot(contains('a8')));
      expect(jump.physicalLedSquares, isNot(contains('a6')));
    },
  );

  test('mismatch LEDs split display hints from reversed physical hints', () {
    final first = checkpoint(
      startTime: 1000,
      destFen: '8/1k6/2p1r3/1p6/8/PP1N4/8/1K6 w - - 0 1',
      waitForFen: true,
    );
    final second = checkpoint(
      startTime: 2000,
      destFen: 'r7/8/8/8/8/R7/8/8 w - - 0 1',
      waitForFen: true,
      led: ledForSquares(['a8', 'a6']),
    );
    final engine = CourseLessonEngine(scriptItems: [first, second]);
    engine.advance(const Duration(milliseconds: 1000));
    engine.handleBoardFen(CourseLessonEngine.reverseBoardFen(first.destFen!));
    engine.jumpToCheckpoint(second);

    final event = engine.handleBoardFen('8/8/8/8/8/8/8/8');

    expect(event.shouldResumeVideo, isFalse);
    expect(event.boardFlipped, isTrue);
    expect(event.ledSquares, containsAll(['a8', 'a3']));
    expect(event.ledSquares, isNot(contains('h1')));
    expect(event.ledSquares, isNot(contains('h3')));
    expect(event.ledSquares, isNot(contains('a6')));
    expect(event.physicalLedSquares, containsAll(['h1', 'h6']));
  });

  test(
    'lesson 20 setup keeps screen squares while reversing physical LEDs',
    () {
      final orientationLock = checkpoint(
        startTime: 1000,
        destFen: '8/1k6/2p1r3/1p6/8/PP1N4/8/1K6 w - - 0 1',
        waitForFen: true,
      );
      final lesson20Setup = checkpoint(
        startTime: 2000,
        destFen: '6r1/8/8/6k1/8/8/5R2/5K2 w - - 0 1',
        waitForFen: true,
        led: ledForSquares(['g8', 'g5', 'f2', 'f1']),
      );
      final engine = CourseLessonEngine(
        scriptItems: [orientationLock, lesson20Setup],
      );
      engine.advance(const Duration(milliseconds: 1000));
      engine.handleBoardFen(
        CourseLessonEngine.reverseBoardFen(orientationLock.destFen!),
      );

      final jump = engine.jumpToCheckpoint(lesson20Setup);

      expect(jump.boardFlipped, isTrue);
      expect(jump.ledSquares, containsAll(['g8', 'g5', 'f2', 'f1']));
      expect(jump.ledSquares, isNot(contains('b1')));
      expect(jump.ledSquares, isNot(contains('c4')));
      expect(jump.ledSquares, isNot(contains('c7')));
      expect(jump.ledSquares, isNot(contains('c8')));
      expect(jump.physicalLedSquares, containsAll(['b1', 'b4', 'c7', 'c8']));
    },
  );

  test(
    'lesson 18 move hints turn off once source and target squares match',
    () {
      final item = checkpoint(
        destFen: '1r3r1k/pp4Q1/7P/2pP1pn1/2P5/7P/5PK1/3q4 w - - 0 1',
        waitForFen: true,
        led: ledForSquares(['g7', 'g6']),
      );
      final engine = CourseLessonEngine(scriptItems: [item]);
      engine.advance(const Duration(milliseconds: 1000));

      final event = engine.handleBoardFen(
        '1r3r1k/pp4Q1/7P/2pP1pn1/2P5/7P/5PK1/8 w - - 0 1',
      );

      expect(event.shouldResumeVideo, isFalse);
      expect(event.ledSquares, isNot(contains('g7')));
      expect(event.ledSquares, isNot(contains('g6')));
      expect(event.ledSquares, contains('d1'));
    },
  );

  test(
    'setup checkpoint LEDs turn off for squares already placed correctly',
    () {
      final item = checkpoint(
        destFen: '8/8/8/8/1k6/6R1/7R/7K w - - 0 1',
        waitForFen: true,
        led: ledForSquares(['b4', 'g3', 'h2', 'h1']),
      );
      final engine = CourseLessonEngine(scriptItems: [item]);
      engine.advance(const Duration(milliseconds: 1000));

      final event = engine.handleBoardFen('8/8/8/8/8/8/7R/7K w - - 0 1');

      expect(event.shouldResumeVideo, isFalse);
      expect(event.ledSquares, containsAll(['b4', 'g3']));
      expect(event.ledSquares, isNot(contains('h2')));
      expect(event.ledSquares, isNot(contains('h1')));
    },
  );

  test('handleBoardFen marks mismatch squares when checkpoint is wrong', () {
    final item = checkpoint(
      destFen: '8/8/8/8/8/5N2/8/8 w - - 0 1',
      waitForFen: true,
    );
    final engine = CourseLessonEngine(scriptItems: [item]);
    engine.advance(const Duration(milliseconds: 1000));

    final event = engine.handleBoardFen('8/8/8/8/8/4N3/8/8');

    expect(event.shouldResumeVideo, isFalse);
    expect(event.ledSquares, containsAll(['e3', 'f3']));
  });

  test('jumpToCheckpoint resumes after matching board FEN', () {
    final item = checkpoint(
      destFen: '8/8/8/8/8/5N2/8/8 w - - 0 1',
      waitForFen: true,
    );
    final engine = CourseLessonEngine(scriptItems: [item]);

    final jump = engine.jumpToCheckpoint(item);
    final event = engine.handleBoardFen('8/8/8/8/8/5N2/8/8');

    expect(jump.shouldPauseVideo, isTrue);
    expect(jump.runningCheckpoint, item);
    expect(event.shouldResumeVideo, isTrue);
    expect(engine.checkedCheckpoints, contains(item));
  });

  test('squaresFromLedArray converts non-zero EVO LED indexes to squares', () {
    final led = List<int>.filled(64, 0);
    led[0] = 0xff0000;
    led[7] = 0x00ff00;
    led[63] = 0x0000ff;

    expect(
      CourseLessonEngine.squaresFromLedArray(led),
      containsAll(['a8', 'h8', 'h1']),
    );
  });
}
