import 'course_lesson_service.dart';

class CourseLessonEngine {
  CourseLessonEngine({required List<CourseScriptItem> scriptItems})
      : scriptItems = List.unmodifiable(scriptItems);

  static const triggerWindow = Duration(milliseconds: 300);
  static const _unlockedOrientationMargin = 2;

  final List<CourseScriptItem> scriptItems;
  final Set<CourseScriptItem> checkedCheckpoints = {};
  int? _runningIndex;
  int? _preventIndex;
  String? _currentBoardFen;
  bool? _physicalBoardReversed;
  Duration? _lastAdvancePosition;

  CourseScriptItem? get runningCheckpoint =>
      _runningIndex == null ? null : scriptItems[_runningIndex!];

  Set<int> get checkedCheckpointIndexes => {
        for (var index = 0; index < scriptItems.length; index += 1)
          if (checkedCheckpoints.contains(scriptItems[index])) index,
      };

  void restoreCheckedCheckpoints(Iterable<int> indexes) {
    for (final index in indexes) {
      if (index >= 0 && index < scriptItems.length) {
        checkedCheckpoints.add(scriptItems[index]);
      }
    }
  }

  bool canConfirmExistingBoardFen(CourseScriptItem item, String boardFen) {
    final destination = item.destFen;
    if (destination == null || destination.isEmpty) return false;
    if (!checkedCheckpoints.any(
      (checked) => checked.destFen == destination,
    )) {
      return false;
    }
    return _matchingExpectedFenForPhysical(boardFen, destination) != null;
  }

  CourseLessonEngineEvent advance(Duration position) {
    final previousPosition = _lastAdvancePosition;
    final preventIndex = _preventIndex;
    if (preventIndex != null &&
        scriptItems[preventIndex].startTime > position) {
      _preventIndex = null;
    }
    final boardFen = boardFenAt(position);
    final boardFenChanged = boardFen != _currentBoardFen;
    if (boardFenChanged) _currentBoardFen = boardFen;

    var shouldResumeVideo = false;
    if (_runningIndex != null) {
      final running = runningCheckpoint!;
      final delta = position - running.startTime;
      if (delta.isNegative) {
        _runningIndex = null;
      } else if (_waitsForBoardFen(running) &&
          !_crossedLaterPauseCheckpoint(
            runningIndex: _runningIndex!,
            previousPosition: previousPosition,
            position: position,
          )) {
        return _recordPosition(
          position,
          CourseLessonEngineEvent(
            runningCheckpoint: running,
            boardFen: boardFenChanged ? boardFen : null,
            boardFenChanged: boardFenChanged,
          ),
        );
      } else if (delta < triggerWindow) {
        return _recordPosition(
          position,
          CourseLessonEngineEvent(
            runningCheckpoint: running,
            boardFen: boardFenChanged ? boardFen : null,
            boardFenChanged: boardFenChanged,
          ),
        );
      } else {
        _runningIndex = null;
        shouldResumeVideo = true;
      }
    }

    for (var index = 0; index < scriptItems.length; index += 1) {
      if (_preventIndex == index) continue;
      final item = scriptItems[index];
      final delta = position - item.startTime;
      final crossedFromPrevious = previousPosition != null &&
          previousPosition < item.startTime &&
          position >= item.startTime;
      if (delta.isNegative ||
          (delta >= triggerWindow && !crossedFromPrevious)) {
        continue;
      }
      if (item.startTimePause) {
        _runningIndex = index;
        _preventIndex = index;
      }
      return _recordPosition(
        position,
        CourseLessonEngineEvent(
          shouldPauseVideo: item.startTimePause,
          shouldResumeVideo: shouldResumeVideo && !item.startTimePause,
          runningCheckpoint: runningCheckpoint,
          boardFen: boardFenChanged ? boardFen : null,
          boardFenChanged: boardFenChanged,
          ledSquares: _initialLedSquaresForCheckpoint(index, item),
          physicalLedSquares: _initialPhysicalLedSquaresForCheckpoint(
            index,
            item,
          ),
          boardFlipped: _physicalBoardReversed,
        ),
      );
    }
    return _recordPosition(
      position,
      CourseLessonEngineEvent(
        shouldResumeVideo: shouldResumeVideo,
        boardFen: boardFenChanged ? boardFen : null,
        boardFenChanged: boardFenChanged,
      ),
    );
  }

  CourseLessonEngineEvent _recordPosition(
    Duration position,
    CourseLessonEngineEvent event,
  ) {
    _lastAdvancePosition = position;
    return event;
  }

  bool _crossedLaterPauseCheckpoint({
    required int runningIndex,
    required Duration? previousPosition,
    required Duration position,
  }) {
    if (previousPosition == null) return false;
    for (var index = runningIndex + 1; index < scriptItems.length; index += 1) {
      final item = scriptItems[index];
      if (!item.startTimePause) continue;
      if (previousPosition < item.startTime && position >= item.startTime) {
        return true;
      }
    }
    return false;
  }

  CourseLessonEngineEvent handleBoardFen(String boardFen) {
    final index = _runningIndex;
    if (index == null) return const CourseLessonEngineEvent();
    final item = scriptItems[index];
    final destFen = item.destFen;
    if (!_waitsForBoardFen(item) || destFen == null || destFen.isEmpty) {
      return CourseLessonEngineEvent(runningCheckpoint: item);
    }

    if (_matchingExpectedFenForPhysical(boardFen, destFen) != null) {
      final reversed = _shouldUseReversedOrientationFor(boardFen, destFen);
      final ledSquares = squaresFromLedArray(item.ledWhenContinue);
      checkedCheckpoints.add(item);
      _runningIndex = null;
      return CourseLessonEngineEvent(
        shouldResumeVideo: true,
        ledSquares: ledSquares,
        physicalLedSquares: _physicalSquaresForDisplay(
          ledSquares,
          reversed: reversed,
        ),
        boardFlipped: reversed,
      );
    }

    final reversed = _shouldUseReversedOrientationFor(boardFen, destFen);
    final displayBoardFen = reversed ? reverseBoardFen(boardFen) : boardFen;
    final expectedForBoard = closestExpectedFen(displayBoardFen, destFen);
    final ledSquares = mismatchSquares(displayBoardFen, expectedForBoard);
    final hintSquares = squaresFromLedArray(item.led);
    ledSquares.addAll(_activeHintSquares(hintSquares, ledSquares));
    return CourseLessonEngineEvent(
      runningCheckpoint: item,
      ledSquares: ledSquares,
      physicalLedSquares: _physicalSquaresForDisplay(
        ledSquares,
        reversed: reversed,
      ),
      boardFlipped: reversed,
    );
  }

  CourseLessonEngineEvent jumpToCheckpoint(CourseScriptItem checkpoint) {
    final index = scriptItems.indexOf(checkpoint);
    if (index < 0) return const CourseLessonEngineEvent();
    _runningIndex = index;
    _preventIndex = index;
    _currentBoardFen = checkpoint.destFen;
    _lastAdvancePosition = checkpoint.startTime;
    return CourseLessonEngineEvent(
      shouldPauseVideo: true,
      runningCheckpoint: checkpoint,
      boardFen: checkpoint.destFen,
      boardFenChanged: true,
      ledSquares: _initialLedSquaresForCheckpoint(index, checkpoint),
      physicalLedSquares: _initialPhysicalLedSquaresForCheckpoint(
        index,
        checkpoint,
      ),
      boardFlipped: _physicalBoardReversed,
    );
  }

  void seek(Duration position) {
    _runningIndex = null;
    _preventIndex = null;
    _currentBoardFen = null;
    _lastAdvancePosition = position;
    for (var index = 0; index < scriptItems.length; index += 1) {
      if (scriptItems[index].startTime <= position) {
        _preventIndex = index;
      }
    }
  }

  void reset() {
    _runningIndex = null;
    _preventIndex = null;
    _currentBoardFen = null;
    _physicalBoardReversed = null;
    _lastAdvancePosition = null;
    checkedCheckpoints.clear();
  }

  String? boardFenAt(Duration position) {
    CourseScriptItem? latest;
    for (final item in scriptItems) {
      final destFen = item.destFen;
      if (destFen == null || destFen.isEmpty || item.startTime > position) {
        continue;
      }
      if (latest == null || item.startTime >= latest.startTime) {
        latest = item;
      }
    }
    return latest?.destFen;
  }

  static bool _waitsForBoardFen(CourseScriptItem item) {
    final destFen = item.destFen;
    return (item.destFenMatchToContinue || item.startTimePause) &&
        destFen != null &&
        destFen.isNotEmpty;
  }

  static bool fenBoardEquals(String a, String b) {
    final boardA = boardOnlyFen(a);
    return expectedBoardVariants(b).contains(boardA);
  }

  Set<String> ledSquaresForBoard(
    List<int>? led, {
    String? physicalFen,
    String? expectedFen,
  }) {
    final squares = squaresFromLedArray(led);
    if (squares.isEmpty ||
        !_shouldUseReversedOrientationFor(physicalFen, expectedFen)) {
      return squares;
    }
    return {for (final square in squares) reverseSquare(square)};
  }

  Set<String> _initialLedSquaresForCheckpoint(
    int index,
    CourseScriptItem item,
  ) {
    final rawSquares = squaresFromLedArray(item.led);
    if (rawSquares.isNotEmpty || !_waitsForBoardFen(item)) return rawSquares;
    return _checkpointFocusSquares(index, item);
  }

  Set<String> _initialPhysicalLedSquaresForCheckpoint(
    int index,
    CourseScriptItem item,
  ) {
    if (!item.startTimePause) return const {};
    final rawSquares = ledSquaresForBoard(item.led, expectedFen: item.destFen);
    if (!_waitsForBoardFen(item)) return rawSquares;
    final focusSquares = _checkpointFocusSquares(index, item);
    if (rawSquares.isEmpty) {
      return _physicalSquaresForDisplay(
        focusSquares,
        reversed: _physicalBoardReversed ?? false,
      );
    }
    if (focusSquares.isEmpty || rawSquares.length <= focusSquares.length + 4) {
      return rawSquares;
    }
    return _physicalSquaresForDisplay(
      focusSquares,
      reversed: _physicalBoardReversed ?? false,
    );
  }

  Set<String> _checkpointFocusSquares(int index, CourseScriptItem item) {
    final destFen = item.destFen;
    if (destFen == null || destFen.isEmpty) return const {};
    final previousFen = _previousDestFenBefore(index);
    if (previousFen == null) return occupiedSquares(destFen);
    final changed = changedSquares(previousFen, destFen);
    return changed.isEmpty ? occupiedSquares(destFen) : changed;
  }

  String? _previousDestFenBefore(int index) {
    for (var i = index - 1; i >= 0; i -= 1) {
      final fen = scriptItems[i].destFen;
      if (fen != null && fen.isNotEmpty) return fen;
    }
    return null;
  }

  static Set<String> _physicalSquaresForDisplay(
    Set<String> squares, {
    required bool reversed,
  }) {
    if (!reversed || squares.isEmpty) return squares;
    return {for (final square in squares) reverseSquare(square)};
  }

  String closestExpectedFenForBoard(String physicalFen, String expectedFen) {
    final lockedOrientation = _physicalBoardReversed;
    if (lockedOrientation != null) {
      return _closestExpectedFen(
        physicalFen,
        _expectedBoardVariantsForOrientation(
          expectedFen,
          reversed: lockedOrientation,
        ),
      );
    }
    return _closestExpectedFen(
      physicalFen,
      expectedBoardVariants(
        expectedFen,
        includeReversed: _canResolveReversedOrientationFor(expectedFen),
      ),
    );
  }

  String? _matchingExpectedFenForPhysical(
    String physicalFen,
    String expectedFen,
  ) {
    final physicalBoard = boardOnlyFen(physicalFen);
    final lockedOrientation = _physicalBoardReversed;
    if (lockedOrientation != null) {
      return _matchingExpectedVariant(
        physicalBoard,
        expectedFen,
        reversed: lockedOrientation,
      );
    }

    final normalMatch = _matchingExpectedVariant(
      physicalBoard,
      expectedFen,
      reversed: false,
    );
    if (normalMatch != null) {
      _physicalBoardReversed = false;
      return normalMatch;
    }

    if (!_canResolveReversedOrientationFor(expectedFen)) return null;
    final reversedMatch = _matchingExpectedVariant(
      physicalBoard,
      expectedFen,
      reversed: true,
    );
    if (reversedMatch != null) {
      _physicalBoardReversed = true;
      return reversedMatch;
    }
    return null;
  }

  bool _shouldUseReversedOrientationFor(
    String? physicalFen,
    String? expectedFen,
  ) {
    final lockedOrientation = _physicalBoardReversed;
    if (lockedOrientation != null) return lockedOrientation;
    if (physicalFen == null ||
        expectedFen == null ||
        !_canResolveReversedOrientationFor(expectedFen)) {
      return false;
    }
    final normalDifference = _closestBoardDifference(
      physicalFen,
      _expectedBoardVariantsForOrientation(expectedFen, reversed: false),
    );
    final reversedDifference = _closestBoardDifference(
      physicalFen,
      _expectedBoardVariantsForOrientation(expectedFen, reversed: true),
    );
    return reversedDifference + _unlockedOrientationMargin < normalDifference;
  }

  static String? _matchingExpectedVariant(
    String physicalBoard,
    String expectedFen, {
    required bool reversed,
  }) {
    for (final candidate in _expectedBoardVariantsForOrientation(
      expectedFen,
      reversed: reversed,
    )) {
      if (physicalBoard == candidate) return candidate;
    }
    return null;
  }

  static String closestExpectedFen(String physicalFen, String expectedFen) {
    return _closestExpectedFen(physicalFen, expectedBoardVariants(expectedFen));
  }

  static String _closestExpectedFen(
    String physicalFen,
    Iterable<String> expectedFens,
  ) {
    final iterator = expectedFens.iterator;
    if (!iterator.moveNext()) return boardOnlyFen(physicalFen);
    var closest = boardOnlyFen(iterator.current);
    var closestDifference = boardDifference(physicalFen, closest);
    while (iterator.moveNext()) {
      final candidate = iterator.current;
      final difference = boardDifference(physicalFen, candidate);
      if (difference < closestDifference) {
        closest = candidate;
        closestDifference = difference;
      }
    }
    return closest;
  }

  static int _closestBoardDifference(
    String physicalFen,
    Iterable<String> expectedFens,
  ) {
    var closestDifference = 64;
    for (final candidate in expectedFens) {
      final difference = boardDifference(physicalFen, candidate);
      if (difference < closestDifference) {
        closestDifference = difference;
      }
    }
    return closestDifference;
  }

  static Set<String> expectedBoardVariants(
    String fen, {
    bool includeReversed = false,
  }) {
    final board = boardOnlyFen(fen);
    final variants = {board, invertFenColors(board)};
    if (includeReversed) {
      final reversed = reverseBoardFen(board);
      variants
        ..add(reversed)
        ..add(invertFenColors(reversed));
    }
    return variants;
  }

  static Set<String> _expectedBoardVariantsForOrientation(
    String fen, {
    required bool reversed,
  }) {
    final orientedBoard = reversed ? reverseBoardFen(fen) : boardOnlyFen(fen);
    return {orientedBoard, invertFenColors(orientedBoard)};
  }

  static bool _canResolveReversedOrientationFor(String fen) {
    return expandBoard(
      boardOnlyFen(fen),
    ).any((piece) => piece != '1' && piece.toLowerCase() != 'p');
  }

  static Set<String> mismatchSquares(String physicalFen, String expectedFen) {
    final physical = expandBoard(boardOnlyFen(physicalFen));
    final expected = expandBoard(boardOnlyFen(expectedFen));
    if (physical.length != 64 || expected.length != 64) return {};
    final squares = <String>{};
    for (var index = 0; index < 64; index += 1) {
      if (physical[index] != expected[index]) {
        squares.add(squareForBoardIndex(index));
      }
    }
    return squares;
  }

  static Set<String> changedSquares(String beforeFen, String afterFen) {
    final before = expandBoard(boardOnlyFen(beforeFen));
    final after = expandBoard(boardOnlyFen(afterFen));
    if (before.length != 64 || after.length != 64) return {};
    final squares = <String>{};
    for (var index = 0; index < 64; index += 1) {
      if (before[index] != after[index]) {
        squares.add(squareForBoardIndex(index));
      }
    }
    return squares;
  }

  static Set<String> occupiedSquares(String fen) {
    final board = expandBoard(boardOnlyFen(fen));
    if (board.length != 64) return {};
    final squares = <String>{};
    for (var index = 0; index < 64; index += 1) {
      if (board[index] != '1') {
        squares.add(squareForBoardIndex(index));
      }
    }
    return squares;
  }

  static int boardDifference(String a, String b) {
    final boardA = expandBoard(boardOnlyFen(a));
    final boardB = expandBoard(boardOnlyFen(b));
    if (boardA.length != 64 || boardB.length != 64) return 64;
    var difference = 0;
    for (var index = 0; index < 64; index += 1) {
      if (boardA[index] != boardB[index]) difference += 1;
    }
    return difference;
  }

  static String boardOnlyFen(String fen) {
    return fen.trim().split(RegExp(r'\s+')).first;
  }

  static List<String> expandBoard(String boardFen) {
    final squares = <String>[];
    for (final char in boardFen.replaceAll('/', '').split('')) {
      final empty = int.tryParse(char);
      if (empty != null) {
        squares.addAll(List<String>.filled(empty, '1'));
      } else {
        squares.add(char);
      }
    }
    return squares;
  }

  static String invertFenColors(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    final board = parts.first.split('').map((char) {
      if (RegExp(r'[a-z]').hasMatch(char)) return char.toUpperCase();
      if (RegExp(r'[A-Z]').hasMatch(char)) return char.toLowerCase();
      return char;
    }).join();
    if (parts.length == 1) return board;
    return [board, ...parts.skip(1)].join(' ');
  }

  static Set<String> _activeHintSquares(
    Set<String> hintSquares,
    Set<String> mismatchSquares,
  ) {
    if (hintSquares.isEmpty || mismatchSquares.isEmpty) return {};
    return hintSquares.intersection(mismatchSquares);
  }

  static String reverseBoardFen(String fen) {
    return boardOnlyFen(fen).split('').reversed.join();
  }

  static String reverseSquare(String square) {
    if (square.length != 2) return square;
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.tryParse(square[1]);
    if (file < 0 || file > 7 || rank == null || rank < 1 || rank > 8) {
      return square;
    }
    final index = (8 - rank) * 8 + file;
    return squareForBoardIndex(63 - index);
  }

  static Set<String> squaresFromLedArray(List<int>? led) {
    if (led == null || led.isEmpty) return {};
    final squares = <String>{};
    for (var index = 0; index < led.length && index < 64; index += 1) {
      if (led[index] != 0) {
        squares.add(squareForBoardIndex(index));
      }
    }
    return squares;
  }

  static String squareForBoardIndex(int index) {
    final rankFromTop = index ~/ 8;
    final file = index % 8;
    return '${String.fromCharCode('a'.codeUnitAt(0) + file)}${8 - rankFromTop}';
  }
}

class CourseLessonEngineEvent {
  const CourseLessonEngineEvent({
    this.shouldPauseVideo = false,
    this.shouldResumeVideo = false,
    this.runningCheckpoint,
    this.boardFen,
    this.boardFenChanged = false,
    Set<String>? ledSquares,
    Set<String>? physicalLedSquares,
    this.boardFlipped,
  })  : ledSquares = ledSquares ?? const {},
        physicalLedSquares = physicalLedSquares ?? ledSquares ?? const {};

  final bool shouldPauseVideo;
  final bool shouldResumeVideo;
  final CourseScriptItem? runningCheckpoint;
  final String? boardFen;
  final bool boardFenChanged;
  final Set<String> ledSquares;
  final Set<String> physicalLedSquares;
  final bool? boardFlipped;
}
