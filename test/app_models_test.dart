import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/services/app_preferences_store.dart';

void main() {
  test('opening library includes detailed ECO variations', () {
    expect(botOpeningScenarios.length, greaterThan(3000));
    expect(
      botOpeningScenarios.any(
        (opening) => opening.name.contains('Najdorf'),
      ),
      isTrue,
    );
    expect(
      botOpeningScenarios.where((opening) => opening.id == 'italian').length,
      1,
    );
  });

  test('Maia defaults to balanced search with adjustable depth', () {
    const config = BotGameConfig.defaultConfig();

    expect(config.maiaSearchStyle, MaiaSearchStyle.balanced);
    expect(config.maiaSearchDepth, 1);

    final pure = config.copyWith(
      maiaSearchStyle: MaiaSearchStyle.pure,
      maiaSearchDepth: 3,
    );

    expect(pure.maiaSearchStyle, MaiaSearchStyle.pure);
    expect(pure.maiaSearchDepth, 3);
  });

  test('connected board product images use boardpics assets', () {
    expect(
        ChessnutBoardModel.air.imageAsset, 'assets/images/boardpics/air.png');
    expect(
      ChessnutBoardModel.airPlus.imageAsset,
      'assets/images/boardpics/air_plus.png',
    );
    expect(
        ChessnutBoardModel.move.imageAsset, 'assets/images/boardpics/move.png');
    expect(
        ChessnutBoardModel.pro.imageAsset, 'assets/images/boardpics/pro.png');
    expect(ChessnutBoardModel.go.imageAsset, 'assets/images/boardpics/go.png');
  });

  test('Chess.com records display time from PGN speed header', () {
    const record = GameRecord(
      result: '1-0',
      title: 'Alice vs Bob',
      subtitle: 'Chess.com / 2 moves',
      playMode: 'chesscom',
      whiteName: 'Alice',
      blackName: 'Bob',
      pgn: '[Event "Live Chess"]\n'
          '[Site "https://www.chess.com/game/live/123"]\n'
          '[White "Alice"]\n'
          '[Black "Bob"]\n'
          '[Result "1-0"]\n'
          '[Speed "Blitz"]\n'
          '[TimeControl "300+0"]\n\n'
          '1. e4 e5 1-0',
    );

    expect(record.speed, 'blitz');
    expect(record.timeLabel, 'Blitz');
    expect(record.timeSummary, 'Time: Blitz');
  });

  test('ten minute time controls classify as rapid records', () {
    const tenMinute = GameRecord(
      result: '1-0',
      title: 'Alice vs Bob',
      subtitle: 'Chess.com / 2 moves',
      playMode: 'chesscom',
      whiteName: 'Alice',
      blackName: 'Bob',
      pgn: '[Site "https://www.chess.com/game/live/10"]\n'
          '[White "Alice"]\n'
          '[Black "Bob"]\n'
          '[Result "1-0"]\n'
          '[TimeControl "10"]\n\n'
          '1. e4 e5 1-0',
    );
    const tenPlusFive = GameRecord(
      result: '1-0',
      title: 'Carol vs Dana',
      subtitle: 'Chess.com / 2 moves',
      playMode: 'chesscom',
      whiteName: 'Carol',
      blackName: 'Dana',
      pgn: '[Site "https://www.chess.com/game/live/10-5"]\n'
          '[White "Carol"]\n'
          '[Black "Dana"]\n'
          '[Result "1-0"]\n'
          '[TimeControl "10+5"]\n\n'
          '1. d4 d5 1-0',
    );

    expect(tenMinute.speed, 'rapid');
    expect(tenPlusFive.speed, 'rapid');
  });

  test('Chess.com records prefer actual TimeControl over stale speed labels',
      () {
    const blitzRecord = GameRecord(
      result: '1-0',
      title: 'Alice vs Bob',
      subtitle: 'Chess.com / 2 moves',
      playMode: 'chesscom',
      whiteName: 'Alice',
      blackName: 'Bob',
      pgn: '[Event "Live Chess"]\n'
          '[Site "https://www.chess.com/game/live/stale-speed"]\n'
          '[White "Alice"]\n'
          '[Black "Bob"]\n'
          '[Result "1-0"]\n'
          '[Speed "Classical"]\n'
          '[TimeClass "Classical"]\n'
          '[TimeControl "300+0"]\n\n'
          '1. e4 e5 1-0',
    );
    const rapidRecord = GameRecord(
      result: '1-0',
      title: 'Carol vs Dana',
      subtitle: 'Chess.com / 2 moves',
      playMode: 'chesscom',
      whiteName: 'Carol',
      blackName: 'Dana',
      pgn: '[Event "Live Chess"]\n'
          '[Site "https://www.chess.com/game/live/stale-speed-rapid"]\n'
          '[White "Carol"]\n'
          '[Black "Dana"]\n'
          '[Result "1-0"]\n'
          '[Speed "Classical"]\n'
          '[TimeControl "600+5"]\n\n'
          '1. d4 d5 1-0',
    );

    expect(blitzRecord.speed, 'blitz');
    expect(blitzRecord.timeLabel, 'Blitz');
    expect(rapidRecord.speed, 'rapid');
    expect(rapidRecord.timeLabel, 'Rapid');
  });

  test('Chess.com records use saved time-control category for filtering', () {
    const rapidRecord = GameRecord(
      result: '1-0',
      title: 'Alice vs Bob',
      subtitle: 'Chess.com / 2 moves',
      playMode: 'chesscom',
      whiteName: 'Alice',
      blackName: 'Bob',
      pgn: '[Event "Live Chess"]\n'
          '[Site "Chess.com"]\n'
          '[White "Alice"]\n'
          '[Black "Bob"]\n'
          '[Result "1-0"]\n'
          '[Speed "Classical"]\n'
          '[TimeControl "600"]\n'
          '[TimeControlCategory "Rapid"]\n\n'
          '1. e4 e5 1-0',
    );
    const dailyRecord = GameRecord(
      result: '1-0',
      title: 'Carol vs Dana',
      subtitle: 'Chess.com / 2 moves',
      playMode: 'chesscom',
      whiteName: 'Carol',
      blackName: 'Dana',
      pgn: '[Event "Live Chess"]\n'
          '[Site "Chess.com"]\n'
          '[White "Carol"]\n'
          '[Black "Dana"]\n'
          '[Result "1-0"]\n'
          '[Speed "Classical"]\n'
          '[TimeControl "86400"]\n'
          '[TimeControlCategory "Daily"]\n\n'
          '1. d4 d5 1-0',
    );

    expect(rapidRecord.speed, 'rapid');
    expect(rapidRecord.timeLabel, 'Rapid');
    expect(dailyRecord.speed, 'daily');
    expect(dailyRecord.timeLabel, 'Daily');
  });

  test('Bot game config persists the last setup selections', () {
    final config = const BotGameConfig.defaultConfig().copyWith(
      engineKind: BotEngineKind.stockfish,
      playerSide: BotPlayerSide.black,
      timeMinutes: 15,
      incrementSeconds: 10,
      stockfishElo: 2180,
      stockfishThinkingTime: const Duration(seconds: 2),
      maiaElo: 1700,
      maiaSearchStyle: MaiaSearchStyle.pure,
      maiaSearchDepth: 3,
      opening: botOpeningScenarios[2],
      startFen: botOpeningScenarios[2].fen,
      showPgnList: false,
      resumePgn: 'should not be included by callers',
    );

    final restored = BotGameConfig.fromJson(config.toJson());

    expect(restored.engineKind, BotEngineKind.stockfish);
    expect(restored.playerSide, BotPlayerSide.black);
    expect(restored.timeMinutes, 15);
    expect(restored.incrementSeconds, 10);
    expect(restored.stockfishElo, 2180);
    expect(restored.stockfishThinkingTime, const Duration(seconds: 2));
    expect(restored.maiaElo, 1700);
    expect(restored.maiaSearchStyle, MaiaSearchStyle.pure);
    expect(restored.maiaSearchDepth, 3);
    expect(restored.opening.id, botOpeningScenarios[2].id);
    expect(restored.showPgnList, isFalse);
    expect(restored.resumePgn, isNull);
  });

  test('Bot game config remembers random side selection separately', () {
    final config = const BotGameConfig.defaultConfig().copyWith(
      playerSide: BotPlayerSide.black,
      playerSidePreference: BotPlayerSide.random,
    );

    final restored = BotGameConfig.fromJson(config.toJson());

    expect(restored.playerSide, BotPlayerSide.black);
    expect(restored.playerSidePreference, BotPlayerSide.random);
  });

  test('Bot game config persists LC0 weight selection', () {
    final config = const BotGameConfig.defaultConfig().copyWith(
      engineKind: BotEngineKind.lc0,
      lc0WeightKey: 'lab:rapid',
      lc0WeightLabel: 'Rapid model',
      lc0WeightPath: 'C:/Chessnut/weights/rapid.pb.gz',
    );

    final restored = BotGameConfig.fromJson(config.toJson());

    expect(restored.engineKind, BotEngineKind.lc0);
    expect(restored.lc0WeightKey, 'lab:rapid');
    expect(restored.lc0WeightLabel, 'Rapid model');
    expect(restored.lc0WeightPath, 'C:/Chessnut/weights/rapid.pb.gz');
    expect(
      const BotGameConfig.defaultConfig().lc0WeightPath,
      'assets/lc0_weights/791556.pb.gz',
    );
  });

  test('Maia 1 and Maia 3 use separate official Elo ranges', () {
    final maia1Low = BotGameConfig.fromJson({
      'engine_kind': 'maia',
      'maia_elo': 600,
    });
    final maia1High = BotGameConfig.fromJson({
      'engine_kind': 'maia',
      'maia_elo': 2600,
    });
    final maia3Low = BotGameConfig.fromJson({
      'engine_kind': 'maia3',
      'maia_elo': 600,
    });
    final maia3High = BotGameConfig.fromJson({
      'engine_kind': 'maia3',
      'maia_elo': 2600,
    });
    final maia3TooHigh = BotGameConfig.fromJson({
      'engine_kind': 'maia3',
      'maia_elo': 2800,
    });

    expect(maia1Low.maiaElo, 1100);
    expect(maia1High.maiaElo, 1900);
    expect(maia3Low.maiaElo, 600);
    expect(maia3High.maiaElo, 2600);
    expect(maia3TooHigh.maiaElo, 2600);
  });

  test('Career mode maps Elo to level progress and settlement deltas', () {
    final low = CareerModeProgress.fromElo(960);
    final mid = CareerModeProgress.fromElo(1425);
    final high = CareerModeProgress.fromElo(2520);

    expect(low.level, 2);
    expect(low.currentElo, 960);
    expect(low.currentLevelElo, 825);
    expect(low.nextElo, 975);
    expect(low.progress, closeTo(0.9, 0.001));
    expect(low.eloAfter(CareerGameOutcome.victory), 1035);
    expect(low.eloAfter(CareerGameOutcome.defeat), 885);

    expect(mid.level, 6);
    expect(mid.levelLabel, 'Silver II');
    expect(mid.currentLevelElo, 1400);
    expect(mid.nextElo, 1500);
    expect(mid.progress, closeTo(0.25, 0.001));
    expect(mid.eloAfter(CareerGameOutcome.victory), 1475);
    expect(mid.eloAfter(CareerGameOutcome.draw), 1425);
    expect(mid.eloAfter(CareerGameOutcome.defeat), 1375);

    expect(high.levelLabel, 'Master I');
    expect(high.eloAfter(CareerGameOutcome.victory), 2530);
    expect(high.eloAfter(CareerGameOutcome.defeat), 2510);
  });

  test('Career journey thresholds align with win-based Elo steps', () {
    expect(careerEloThresholds, hasLength(36));
    expect(careerEloThresholds.take(3), [600, 825, 975]);
    expect(careerEloThresholds.last, 2600);
    expect(CareerModeProgress.fromElo(600).nextElo, 825);
    expect(CareerModeProgress.fromElo(825).nextElo, 975);

    final reachableElos = <int>{};
    var elo = careerEloThresholds.first;
    while (elo <= careerEloThresholds.last) {
      reachableElos.add(elo);
      if (elo == careerEloThresholds.last) break;
      elo += CareerModeProgress.fromElo(elo).delta;
    }

    for (final threshold in careerEloThresholds) {
      expect(
        reachableElos,
        contains(threshold),
        reason: '$threshold should be reachable by career win Elo steps',
      );
    }
  });

  test('Career opponent profile creates immersive bot config', () {
    final progress = CareerModeProgress.fromElo(1425);
    final opponent = CareerOpponentProfile.matchFor(
      progress: progress,
      seed: 3,
    );
    final config = opponent.toBotGameConfig(progress: progress);

    expect(opponent.name, isNotEmpty);
    expect(opponent.avatarAsset, startsWith('assets/avatars/avatar-'));
    expect(opponent.elo, progress.currentElo);
    expect(
      opponent.elo,
      inInclusiveRange(progress.currentLevelElo, progress.nextElo),
    );
    expect(
      opponent.engineKind,
      anyOf(
        BotEngineKind.maia,
        BotEngineKind.maia3,
        BotEngineKind.stockfish,
      ),
    );
    expect(opponent.opening, standardOpeningScenario);
    expect(config.opponent, contains(opponent.name));
    expect(config.title, contains(opponent.name));
    expect(config.subtitle, contains('Career'));
    expect(config.timeMinutes, 0);
    expect(config.incrementSeconds, 0);
    expect(config.maiaElo, opponent.elo);
    expect(config.opening, standardOpeningScenario);
    expect(config.startFen, chessnutStandardStartFen);
    expect(config.careerMode, isNotNull);
    expect(config.careerMode!.startElo, progress.currentElo);
    expect(config.careerMode!.opponentName, opponent.name);
  });

  test('Career rotates engines online and excludes Maia 3 offline', () {
    final belowStockfish = CareerOpponentProfile.matchFor(
      progress: CareerModeProgress.fromElo(2599),
    );
    final atStockfishThreshold = CareerOpponentProfile.matchFor(
      progress: CareerModeProgress.fromElo(2600),
    );
    final alternateAtSameElo = CareerOpponentProfile.matchFor(
      progress: CareerModeProgress.fromElo(2600),
      seed: 1,
    );
    final config = atStockfishThreshold.toBotGameConfig(
      progress: CareerModeProgress.fromElo(2600),
    );

    final engines = {
      for (final seed in List<int>.generate(8, (index) => index))
        CareerOpponentProfile.matchFor(
          progress: CareerModeProgress.fromElo(1200),
          seed: seed,
        ).engineKind,
    };
    expect(
      engines,
      containsAll([
        BotEngineKind.maia,
        BotEngineKind.maia3,
        BotEngineKind.stockfish,
      ]),
    );
    final offlineEngines = {
      for (final seed in List<int>.generate(8, (index) => index))
        CareerOpponentProfile.matchFor(
          progress: CareerModeProgress.fromElo(1200),
          seed: seed,
          allowMaia3: false,
        ).engineKind,
    };
    expect(
      offlineEngines,
      containsAll([BotEngineKind.maia, BotEngineKind.stockfish]),
    );
    expect(offlineEngines, isNot(contains(BotEngineKind.maia3)));
    expect(atStockfishThreshold.elo, 2600);
    expect(config.engineKind, atStockfishThreshold.engineKind);
    expect(config.stockfishElo, 2600);
    expect(config.opponent, contains('2600'));

    final lowOnline = {
      for (final seed in List<int>.generate(6, (index) => index))
        CareerOpponentProfile.matchFor(
          progress: CareerModeProgress.fromElo(700),
          seed: seed,
        ).engineKind,
    };
    expect(lowOnline, equals({BotEngineKind.maia3, BotEngineKind.stockfish}));

    final highOnline = {
      for (final seed in List<int>.generate(6, (index) => index))
        CareerOpponentProfile.matchFor(
          progress: CareerModeProgress.fromElo(2800),
          seed: seed,
        ).engineKind,
    };
    expect(
      highOnline,
      equals({BotEngineKind.stockfish}),
    );
  });

  test('Career player side is randomized evenly and ignores level parity', () {
    final progress = CareerModeProgress.fromElo(1200);
    final otherProgress = CareerModeProgress.fromElo(1250);
    final opponent = CareerOpponentProfile.matchFor(progress: progress);
    final otherOpponent =
        CareerOpponentProfile.matchFor(progress: otherProgress);
    final random = math.Random(20260831);
    final otherRandom = math.Random(20260831);
    var whiteGames = 0;
    var blackGames = 0;

    for (var game = 0; game < 10000; game += 1) {
      final config = opponent.toBotGameConfig(
        progress: progress,
        random: random,
      );
      final otherConfig = otherOpponent.toBotGameConfig(
        progress: otherProgress,
        random: otherRandom,
      );
      expect(otherConfig.playerSide, config.playerSide);
      if (config.playerSide == BotPlayerSide.white) {
        whiteGames += 1;
      } else if (config.playerSide == BotPlayerSide.black) {
        blackGames += 1;
      }
    }

    expect(whiteGames + blackGames, 10000);
    expect(whiteGames, inInclusiveRange(4800, 5200));
    expect(blackGames, inInclusiveRange(4800, 5200));
  });

  test('PGN game status prevents finished bot records from continuing', () {
    const record = GameRecord(
      result: '*',
      title: 'Chessnut Player vs Maia 1500',
      subtitle: 'Bot / 2 moves',
      pgn: '''
[Event "Bot game room"]
[Site "Chessnut App"]
[White "Chessnut Player"]
[Black "Maia 1500"]
[Result "*"]
[GameStatus "2"]

1. e4 e5 *
''',
      playMode: 'bot',
      gameStatus: 1,
      gameStep: 2,
      winId: 0,
    );

    expect(record.declaredGameStatus, 2);
    expect(record.isInProgress, isFalse);
    expect(record.canContinueBotGame, isFalse);
  });

  test('App update reminder suppresses deferred and ignored versions', () {
    final tomorrow = DateTime.utc(2026, 6, 29, 12);
    final reminder = AppUpdateReminderState(
      deferredVersion: 'android-play:45',
      deferredUntil: tomorrow,
      ignoredVersion: 'android-play:44',
    );

    expect(
      reminder.shouldSuppress(
        'android-play:45',
        DateTime.utc(2026, 6, 29, 11),
      ),
      isTrue,
    );
    expect(
      reminder.shouldSuppress(
        'android-play:45',
        DateTime.utc(2026, 6, 29, 13),
      ),
      isFalse,
    );
    expect(
      reminder.shouldSuppress(
        'android-play:44',
        DateTime.utc(2026, 6, 30),
      ),
      isTrue,
    );
  });
}
