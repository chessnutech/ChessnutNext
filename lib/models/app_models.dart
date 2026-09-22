import 'dart:math' as math;

import 'package:flutter/material.dart';

part 'opening_scenarios.dart';

class AppRouteItem {
  const AppRouteItem({
    required this.label,
    required this.icon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}

enum ChessnutBoardModel { move, air, airPlus, pro, evo, evo2, go, pi, unknown }

extension ChessnutBoardModelInfo on ChessnutBoardModel {
  String get displayName {
    switch (this) {
      case ChessnutBoardModel.move:
        return 'Chessnut Move';
      case ChessnutBoardModel.air:
        return 'Chessnut Air';
      case ChessnutBoardModel.airPlus:
        return 'Chessnut Air Plus';
      case ChessnutBoardModel.pro:
        return 'Chessnut Pro';
      case ChessnutBoardModel.evo:
        return 'Chessnut Evo';
      case ChessnutBoardModel.evo2:
        return 'Chessnut EVO2';
      case ChessnutBoardModel.go:
        return 'Chessnut Go';
      case ChessnutBoardModel.pi:
        return 'Chessnut Pi';
      case ChessnutBoardModel.unknown:
        return 'Chessnut board';
    }
  }

  String get imageAsset {
    return switch (this) {
      ChessnutBoardModel.air => 'assets/images/boardpics/air.png',
      ChessnutBoardModel.airPlus => 'assets/images/boardpics/air_plus.png',
      ChessnutBoardModel.pro => 'assets/images/boardpics/pro.png',
      ChessnutBoardModel.go => 'assets/images/boardpics/go.png',
      ChessnutBoardModel.move => 'assets/images/boardpics/move.png',
      ChessnutBoardModel.evo => 'assets/images/move.png',
      ChessnutBoardModel.evo2 => 'assets/images/move.png',
      ChessnutBoardModel.pi => 'assets/images/move.png',
      ChessnutBoardModel.unknown => 'assets/images/boardpics/move.png',
    };
  }

  String get fallbackImageAsset => 'assets/images/boardpics/move.png';

  bool get hasPieceManagement => this == ChessnutBoardModel.move;
}

enum GameLaunchMode { lichess, chesscom, bot, otb, clock }

enum BotEngineKind { maia, maia3, stockfish, lc0 }

enum BotPlayerSide { random, white, black }

enum MaiaSearchStyle { balanced, pure }

enum CareerGameOutcome { victory, defeat, draw }

const String defaultLc0WeightKey = 'builtin:791556';
const String defaultLc0WeightLabel = 'Default 791556';
const String defaultLc0WeightPath = 'assets/lc0_weights/791556.pb.gz';
const int personalEngineTrainingCostPoints = 300;

const List<int> maia1SupportedElos = [
  1100,
  1200,
  1300,
  1400,
  1500,
  1600,
  1700,
  1800,
  1900,
];

const int maiaMinElo = 1100;
const int maiaMaxElo = 1900;
const int maia3MinElo = 600;
const int maia3MaxElo = 2600;
const int maia3EloStep = 100;
const int careerStockfishMinElo = 600;
const int careerStockfishMaxElo = 3190;
const int careerMaxElo = 3190;

const List<int> careerEloThresholds = [
  600,
  825,
  975,
  1150,
  1250,
  1400,
  1500,
  1550,
  1625,
  1675,
  1725,
  1775,
  1850,
  1900,
  1950,
  2000,
  2030,
  2075,
  2105,
  2135,
  2165,
  2195,
  2225,
  2270,
  2300,
  2330,
  2360,
  2390,
  2420,
  2450,
  2495,
  2520,
  2540,
  2560,
  2580,
  2600,
];

const chessnutStandardStartFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

class CareerModeProgress {
  const CareerModeProgress({
    required this.currentElo,
    required this.level,
    required this.levelLabel,
    required this.currentLevelElo,
    required this.nextElo,
    required this.progress,
  });

  factory CareerModeProgress.fromElo(int elo) {
    final currentElo = elo.clamp(600, 3190).toInt();
    var levelIndex = 0;
    for (var i = 0; i < careerEloThresholds.length - 1; i += 1) {
      if (currentElo >= careerEloThresholds[i] &&
          currentElo < careerEloThresholds[i + 1]) {
        levelIndex = i;
        break;
      }
      if (currentElo >= careerEloThresholds.last) {
        levelIndex = careerEloThresholds.length - 2;
      }
    }
    final start = careerEloThresholds[levelIndex];
    final next = currentElo >= careerEloThresholds.last
        ? careerMaxElo
        : careerEloThresholds[levelIndex + 1];
    final progress = ((currentElo - start) / (next - start)).clamp(0.0, 1.0);
    return CareerModeProgress(
      currentElo: currentElo,
      level: levelIndex + 1,
      levelLabel: _careerLevelLabel(currentElo),
      currentLevelElo: start,
      nextElo: next,
      progress: progress,
    );
  }

  final int currentElo;
  final int level;
  final String levelLabel;
  final int currentLevelElo;
  final int nextElo;
  final double progress;

  int get delta {
    return switch (currentElo) {
      < 1000 => 75,
      < 1500 => 50,
      < 2000 => 25,
      < 2500 => 15,
      _ => 10,
    };
  }

  int eloAfter(CareerGameOutcome outcome) {
    return switch (outcome) {
      CareerGameOutcome.victory => currentElo + delta,
      CareerGameOutcome.defeat =>
        (currentElo - delta).clamp(600, careerMaxElo).toInt(),
      CareerGameOutcome.draw => currentElo,
    };
  }
}

class CareerRatingDelta {
  const CareerRatingDelta({
    required this.before,
    required this.after,
  });

  final int before;
  final int after;

  int get amount => after - before;
  bool get isGain => amount > 0;
  bool get isLoss => amount < 0;

  String get label {
    if (amount == 0) return '±0 ELO';
    final prefix = amount > 0 ? '+' : '';
    return '$prefix$amount ELO';
  }
}

String _careerLevelLabel(int elo) {
  if (elo >= 2500) return 'Master I';
  if (elo >= 2200) return 'Master ${_romanStep(elo, 2200, 2500, 4)}';
  if (elo >= 1800) return 'Platinum ${_romanStep(elo, 1800, 2200, 4)}';
  if (elo >= 1500) return 'Gold ${_romanStep(elo, 1500, 1800, 4)}';
  if (elo >= 1200) return 'Silver ${_romanStep(elo, 1200, 1500, 6)}';
  if (elo >= 1000) return 'Bronze ${_romanStep(elo, 1000, 1200, 4)}';
  return 'Rookie ${_romanStep(elo, 600, 1000, 4)}';
}

String _romanStep(int elo, int start, int end, int divisions) {
  const roman = ['I', 'II', 'III', 'IV', 'V', 'VI'];
  final clamped = elo.clamp(start, end - 1).toInt();
  final progress = (clamped - start) / (end - start);
  final index = (progress * divisions).floor().clamp(0, divisions - 1).toInt();
  final romanIndex = (divisions - 1 - index).clamp(0, roman.length - 1).toInt();
  return roman[romanIndex];
}

class CareerModeConfig {
  const CareerModeConfig({
    required this.startElo,
    required this.winElo,
    required this.loseElo,
    required this.opponentName,
    required this.opponentAvatarAsset,
  });

  factory CareerModeConfig.fromProgress({
    required CareerModeProgress progress,
    required CareerOpponentProfile opponent,
  }) {
    return CareerModeConfig(
      startElo: progress.currentElo,
      winElo: progress.eloAfter(CareerGameOutcome.victory),
      loseElo: progress.eloAfter(CareerGameOutcome.defeat),
      opponentName: opponent.name,
      opponentAvatarAsset: opponent.avatarAsset,
    );
  }

  factory CareerModeConfig.fromJson(Map<String, dynamic> json) {
    final startElo = _intFromJson(json['start_elo']) ?? 1200;
    final progress = CareerModeProgress.fromElo(startElo);
    final winElo = _intFromJson(json['win_elo']) ??
        progress.eloAfter(CareerGameOutcome.victory);
    final loseElo = _intFromJson(json['lose_elo']) ??
        progress.eloAfter(CareerGameOutcome.defeat);
    return CareerModeConfig(
      startElo: startElo.clamp(600, 3190).toInt(),
      winElo: winElo.clamp(600, 3190).toInt(),
      loseElo: loseElo.clamp(600, 3190).toInt(),
      opponentName: _stringFromJson(json['opponent_name']) ?? 'Career opponent',
      opponentAvatarAsset: _stringFromJson(json['opponent_avatar_asset']) ?? '',
    );
  }

  final int startElo;
  final int winElo;
  final int loseElo;
  final String opponentName;
  final String opponentAvatarAsset;

  Map<String, dynamic> toJson() {
    return {
      'start_elo': startElo,
      'win_elo': winElo,
      'lose_elo': loseElo,
      'opponent_name': opponentName,
      'opponent_avatar_asset': opponentAvatarAsset,
    };
  }
}

class CareerOpponentProfile {
  const CareerOpponentProfile({
    required this.name,
    required this.avatarAsset,
    required this.engineKind,
    required this.elo,
    required this.style,
    required this.opening,
  });

  static CareerOpponentProfile matchFor({
    required CareerModeProgress progress,
    int seed = 0,

    /// Whether cloud Maia 3 is available. Set this to false when offline.
    bool allowMaia3 = true,
  }) {
    final index = (progress.level + seed).abs();
    final base = _careerOpponentSeeds[index % _careerOpponentSeeds.length];
    final targetElo = _careerOpponentTargetElo(progress);
    final engineKind = _careerOpponentEngineKind(
      targetElo,
      index,
      allowMaia3: allowMaia3,
    );
    return CareerOpponentProfile(
      name: base.name,
      avatarAsset: base.avatarAsset,
      engineKind: engineKind,
      elo: targetElo,
      style: base.style,
      opening: standardOpeningScenario,
    );
  }

  final String name;
  final String avatarAsset;
  final BotEngineKind engineKind;
  final int elo;
  final String style;
  final OpeningScenario opening;

  BotGameConfig toBotGameConfig({
    required CareerModeProgress progress,
    math.Random? random,
  }) {
    final engineLabel = switch (engineKind) {
      BotEngineKind.maia3 => 'Maia 3 $elo',
      BotEngineKind.stockfish => 'Stockfish $elo',
      _ => 'Maia $elo',
    };
    final side = (random ?? math.Random()).nextBool()
        ? BotPlayerSide.white
        : BotPlayerSide.black;
    final sideLabel = side == BotPlayerSide.white ? 'White side' : 'Black side';
    return BotGameConfig(
      title: '$name / ELO $elo',
      subtitle: 'Career challenge / ${standardOpeningScenario.name}',
      opponent: '$name ($engineLabel)',
      opponentSource: '$style / ${standardOpeningScenario.focus}',
      playerSource: '$sideLabel / ${progress.levelLabel}',
      turn: side == BotPlayerSide.white ? 'White to move' : 'Black to move',
      eval: '+0.4',
      engineKind: engineKind,
      playerSide: side,
      timeMinutes: 0,
      incrementSeconds: 0,
      stockfishElo: elo.clamp(600, 3190).toInt(),
      stockfishThinkingTime:
          Duration(milliseconds: elo.clamp(600, 1600).toInt()),
      maiaElo: elo,
      maiaSearchStyle: MaiaSearchStyle.balanced,
      maiaSearchDepth: 1,
      opening: standardOpeningScenario,
      startFen: chessnutStandardStartFen,
      careerMode: CareerModeConfig.fromProgress(
        progress: progress,
        opponent: this,
      ),
    );
  }
}

int _careerOpponentTargetElo(CareerModeProgress progress) {
  final minElo = progress.currentLevelElo.clamp(600, careerMaxElo).toInt();
  final maxElo = progress.nextElo.clamp(minElo, careerMaxElo).toInt();
  return progress.currentElo.clamp(minElo, maxElo).toInt();
}

BotEngineKind _careerOpponentEngineKind(
  int targetElo,
  int index, {
  required bool allowMaia3,
}) {
  // Maia 3 requires an internet connection. Keep it in the online rotation,
  // while offline play alternates only the local Maia and Stockfish engines.
  final engines = <BotEngineKind>[
    if (allowMaia3 && targetElo >= maia3MinElo && targetElo <= maia3MaxElo)
      BotEngineKind.maia3,
    if (targetElo >= maiaMinElo && targetElo <= maiaMaxElo) BotEngineKind.maia,
    if (targetElo >= careerStockfishMinElo &&
        targetElo <= careerStockfishMaxElo)
      BotEngineKind.stockfish,
  ];
  // Career ELO is constrained to Stockfish's supported range, but retain a
  // safe fallback if this helper is ever called with an out-of-range value.
  if (engines.isEmpty) return BotEngineKind.stockfish;
  return engines[index % engines.length];
}

class _CareerOpponentSeed {
  const _CareerOpponentSeed({
    required this.name,
    required this.avatarAsset,
    required this.style,
  });

  final String name;
  final String avatarAsset;
  final String style;
}

const _careerOpponentSeeds = [
  _CareerOpponentSeed(
    name: 'Ethan Ross',
    avatarAsset: 'assets/avatars/avatar-03.png',
    style: 'Tactical attacker',
  ),
  _CareerOpponentSeed(
    name: 'Mila Chen',
    avatarAsset: 'assets/avatars/avatar-08.png',
    style: 'Solid defender',
  ),
  _CareerOpponentSeed(
    name: 'Leo Park',
    avatarAsset: 'assets/avatars/avatar-12.png',
    style: 'Endgame grinder',
  ),
  _CareerOpponentSeed(
    name: 'Ava Brooks',
    avatarAsset: 'assets/avatars/avatar-17.png',
    style: 'Opening specialist',
  ),
  _CareerOpponentSeed(
    name: 'Noah Stone',
    avatarAsset: 'assets/avatars/avatar-22.png',
    style: 'Counterattacker',
  ),
  _CareerOpponentSeed(
    name: 'Sofia Vale',
    avatarAsset: 'assets/avatars/avatar-27.png',
    style: 'Positional player',
  ),
];

class OpeningScenario {
  const OpeningScenario({
    required this.id,
    required this.name,
    required this.eco,
    required this.moves,
    required this.fen,
    required this.focus,
  });

  final String id;
  final String name;
  final String eco;
  final String moves;
  final String fen;
  final String focus;

  bool get isStandard => id == 'standard';
}

const standardOpeningScenario = OpeningScenario(
  id: 'standard',
  name: 'Standard start',
  eco: 'Start',
  moves: 'Initial position',
  fen: chessnutStandardStartFen,
  focus: 'Full game',
);

const legacyBotOpeningScenarios = <OpeningScenario>[
  standardOpeningScenario,
  OpeningScenario(
    id: 'italian',
    name: 'Italian Game',
    eco: 'C50',
    moves: '1. e4 e5 2. Nf3 Nc6 3. Bc4',
    fen: 'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3',
    focus: 'Fast development',
  ),
  OpeningScenario(
    id: 'ruy-lopez',
    name: 'Ruy Lopez',
    eco: 'C60',
    moves: '1. e4 e5 2. Nf3 Nc6 3. Bb5',
    fen: 'r1bqkbnr/pppp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3',
    focus: 'Pressure on c6',
  ),
  OpeningScenario(
    id: 'sicilian',
    name: 'Sicilian Defense',
    eco: 'B20',
    moves: '1. e4 c5',
    fen: 'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
    focus: 'Asymmetric center',
  ),
  OpeningScenario(
    id: 'french',
    name: 'French Defense',
    eco: 'C00',
    moves: '1. e4 e6',
    fen: 'rnbqkbnr/pppp1ppp/4p3/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
    focus: 'Pawn chain',
  ),
  OpeningScenario(
    id: 'caro-kann',
    name: 'Caro-Kann Defense',
    eco: 'B10',
    moves: '1. e4 c6',
    fen: 'rnbqkbnr/pp1ppppp/2p5/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
    focus: 'Solid structure',
  ),
  OpeningScenario(
    id: 'queens-gambit',
    name: "Queen's Gambit",
    eco: 'D06',
    moves: '1. d4 d5 2. c4',
    fen: 'rnbqkbnr/ppp1pppp/8/3p4/2PP4/8/PP2PPPP/RNBQKBNR b KQkq - 0 2',
    focus: 'Queenside tension',
  ),
  OpeningScenario(
    id: 'kings-indian',
    name: "King's Indian Defense",
    eco: 'E60',
    moves: '1. d4 Nf6 2. c4 g6',
    fen: 'rnbqkb1r/pppppp1p/5np1/8/2PP4/8/PP2PPPP/RNBQKBNR w KQkq - 0 3',
    focus: 'Dynamic counterplay',
  ),
  OpeningScenario(
    id: 'english',
    name: 'English Opening',
    eco: 'A10',
    moves: '1. c4',
    fen: 'rnbqkbnr/pppppppp/8/8/2P5/8/PP1PPPPP/RNBQKBNR b KQkq - 0 1',
    focus: 'Flexible setup',
  ),
  OpeningScenario(
    id: 'scotch',
    name: 'Scotch Game',
    eco: 'C44',
    moves: '1. e4 e5 2. Nf3 Nc6 3. d4',
    fen: 'r1bqkbnr/pppp1ppp/2n5/4p3/3PP3/5N2/PPP2PPP/RNBQKB1R b KQkq - 0 3',
    focus: 'Open center',
  ),
  OpeningScenario(
    id: 'vienna',
    name: 'Vienna Game',
    eco: 'C25',
    moves: '1. e4 e5 2. Nc3',
    fen: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/2N5/PPPP1PPP/R1BQKBNR b KQkq - 2 2',
    focus: 'Flexible kingside',
  ),
  OpeningScenario(
    id: 'kings-gambit',
    name: "King's Gambit",
    eco: 'C30',
    moves: '1. e4 e5 2. f4',
    fen: 'rnbqkbnr/pppp1ppp/8/4p3/4PP2/8/PPPP2PP/RNBQKBNR b KQkq - 0 2',
    focus: 'Attack practice',
  ),
  OpeningScenario(
    id: 'london',
    name: 'London System',
    eco: 'D02',
    moves: '1. d4 d5 2. Bf4',
    fen: 'rnbqkbnr/ppp1pppp/8/3p4/3P1B2/8/PPP1PPPP/RN1QKBNR b KQkq - 1 2',
    focus: 'System play',
  ),
  OpeningScenario(
    id: 'slav',
    name: 'Slav Defense',
    eco: 'D10',
    moves: '1. d4 d5 2. c4 c6',
    fen: 'rnbqkbnr/pp2pppp/2p5/3p4/2PP4/8/PP2PPPP/RNBQKBNR w KQkq - 0 3',
    focus: 'Solid queenside',
  ),
  OpeningScenario(
    id: 'grunfeld',
    name: 'Grunfeld Defense',
    eco: 'D70',
    moves: '1. d4 Nf6 2. c4 g6 3. Nc3 d5',
    fen: 'rnbqkb1r/ppp1pp1p/5np1/3p4/2PP4/2N5/PP2PPPP/R1BQKBNR w KQkq - 0 4',
    focus: 'Center pressure',
  ),
  OpeningScenario(
    id: 'nimzo-indian',
    name: 'Nimzo-Indian Defense',
    eco: 'E20',
    moves: '1. d4 Nf6 2. c4 e6 3. Nc3 Bb4',
    fen: 'rnbqk2r/pppp1ppp/4pn2/8/1bPP4/2N5/PP2PPPP/R1BQKBNR w KQkq - 2 4',
    focus: 'Pin and structure',
  ),
  OpeningScenario(
    id: 'queens-indian',
    name: "Queen's Indian Defense",
    eco: 'E12',
    moves: '1. d4 Nf6 2. c4 e6 3. Nf3 b6',
    fen: 'rnbqkb1r/p1pp1ppp/1p2pn2/8/2PP4/5N2/PP2PPPP/RNBQKB1R w KQkq - 0 4',
    focus: 'Dark-square control',
  ),
  OpeningScenario(
    id: 'benoni',
    name: 'Modern Benoni',
    eco: 'A60',
    moves: '1. d4 Nf6 2. c4 c5 3. d5 e6',
    fen: 'rnbqkb1r/pp1p1ppp/4pn2/2pP4/2P5/8/PP2PPPP/RNBQKBNR w KQkq - 0 4',
    focus: 'Imbalanced center',
  ),
  OpeningScenario(
    id: 'pirc',
    name: 'Pirc Defense',
    eco: 'B07',
    moves: '1. e4 d6 2. d4 Nf6',
    fen: 'rnbqkb1r/ppp1pppp/3p1n2/8/3PP3/8/PPP2PPP/RNBQKBNR w KQkq - 1 3',
    focus: 'Counterattack',
  ),
  OpeningScenario(
    id: 'modern',
    name: 'Modern Defense',
    eco: 'B06',
    moves: '1. e4 g6 2. d4 Bg7',
    fen: 'rnbqk1nr/ppppppbp/6p1/8/3PP3/8/PPP2PPP/RNBQKBNR w KQkq - 1 3',
    focus: 'Hypermodern setup',
  ),
  OpeningScenario(
    id: 'alekhine',
    name: "Alekhine's Defense",
    eco: 'B02',
    moves: '1. e4 Nf6',
    fen: 'rnbqkb1r/pppppppp/5n2/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 1 2',
    focus: 'Tempo challenge',
  ),
  OpeningScenario(
    id: 'scandinavian',
    name: 'Scandinavian Defense',
    eco: 'B01',
    moves: '1. e4 d5',
    fen: 'rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
    focus: 'Queen activity',
  ),
  OpeningScenario(
    id: 'reti',
    name: 'Reti Opening',
    eco: 'A04',
    moves: '1. Nf3',
    fen: 'rnbqkbnr/pppppppp/8/8/8/5N2/PPPPPPPP/RNBQKB1R b KQkq - 1 1',
    focus: 'Transpositions',
  ),
  OpeningScenario(
    id: 'bird',
    name: "Bird's Opening",
    eco: 'A02',
    moves: '1. f4',
    fen: 'rnbqkbnr/pppppppp/8/8/5P2/8/PPPPP1PP/RNBQKBNR b KQkq - 0 1',
    focus: 'Kingside space',
  ),
  OpeningScenario(
    id: 'dutch',
    name: 'Dutch Defense',
    eco: 'A80',
    moves: '1. d4 f5',
    fen: 'rnbqkbnr/ppppp1pp/8/5p2/3P4/8/PPP1PPPP/RNBQKBNR w KQkq - 0 2',
    focus: 'Imbalance early',
  ),
];

final botOpeningScenarios = <OpeningScenario>[
  ...legacyBotOpeningScenarios,
  ...detailedOpeningScenarios.where(
    (opening) => !legacyBotOpeningScenarios.any(
      (legacy) => legacy.name == opening.name && legacy.moves == opening.moves,
    ),
  ),
];

class BotGameConfig {
  const BotGameConfig({
    required this.title,
    required this.subtitle,
    required this.opponent,
    required this.opponentSource,
    required this.playerSource,
    required this.turn,
    required this.eval,
    this.engineKind = BotEngineKind.maia,
    this.playerSide = BotPlayerSide.white,
    this.playerSidePreference,
    this.timeMinutes = 10,
    this.incrementSeconds = 5,
    this.stockfishElo = 1320,
    this.stockfishThinkingTime = Duration.zero,
    this.maiaElo = 1500,
    this.maiaSearchStyle = MaiaSearchStyle.balanced,
    this.maiaSearchDepth = 1,
    this.lc0WeightKey = defaultLc0WeightKey,
    this.lc0WeightLabel = defaultLc0WeightLabel,
    this.lc0WeightPath = defaultLc0WeightPath,
    this.opening = standardOpeningScenario,
    this.startFen = chessnutStandardStartFen,
    this.chess960 = false,
    this.showPgnList = true,
    this.careerMode,
    this.resumePgn,
  });

  const BotGameConfig.defaultConfig()
      : title = 'Maia 1500 / 10+5',
        subtitle = 'Bot game room',
        opponent = 'Maia 1500',
        opponentSource = 'Human-like engine / +0.4',
        playerSource = 'White to move / coach available',
        turn = 'White to move',
        eval = '+0.4',
        engineKind = BotEngineKind.maia,
        playerSide = BotPlayerSide.white,
        playerSidePreference = null,
        timeMinutes = 10,
        incrementSeconds = 5,
        stockfishElo = 1320,
        stockfishThinkingTime = Duration.zero,
        maiaElo = 1500,
        maiaSearchStyle = MaiaSearchStyle.balanced,
        maiaSearchDepth = 1,
        lc0WeightKey = defaultLc0WeightKey,
        lc0WeightLabel = defaultLc0WeightLabel,
        lc0WeightPath = defaultLc0WeightPath,
        opening = standardOpeningScenario,
        startFen = chessnutStandardStartFen,
        chess960 = false,
        showPgnList = true,
        careerMode = null,
        resumePgn = null;

  final String title;
  final String subtitle;
  final String opponent;
  final String opponentSource;
  final String playerSource;
  final String turn;
  final String eval;
  final BotEngineKind engineKind;
  final BotPlayerSide playerSide;

  /// The side mode selected in setup, when it differs from the resolved side
  /// used by the active game (for example, Random resolves to white or black).
  final BotPlayerSide? playerSidePreference;
  final int timeMinutes;
  final int incrementSeconds;
  final int stockfishElo;
  final Duration stockfishThinkingTime;
  final int maiaElo;
  final MaiaSearchStyle maiaSearchStyle;
  final int maiaSearchDepth;
  final String lc0WeightKey;
  final String lc0WeightLabel;
  final String lc0WeightPath;
  final OpeningScenario opening;
  final String startFen;
  final bool chess960;
  final bool showPgnList;
  final CareerModeConfig? careerMode;
  final String? resumePgn;

  BotGameConfig copyWith({
    String? title,
    String? subtitle,
    String? opponent,
    String? opponentSource,
    String? playerSource,
    String? turn,
    String? eval,
    BotEngineKind? engineKind,
    BotPlayerSide? playerSide,
    BotPlayerSide? playerSidePreference,
    int? timeMinutes,
    int? incrementSeconds,
    int? stockfishElo,
    Duration? stockfishThinkingTime,
    int? maiaElo,
    MaiaSearchStyle? maiaSearchStyle,
    int? maiaSearchDepth,
    String? lc0WeightKey,
    String? lc0WeightLabel,
    String? lc0WeightPath,
    OpeningScenario? opening,
    String? startFen,
    bool? chess960,
    bool? showPgnList,
    CareerModeConfig? careerMode,
    String? resumePgn,
    bool clearCareerMode = false,
    bool clearResumePgn = false,
  }) {
    return BotGameConfig(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      opponent: opponent ?? this.opponent,
      opponentSource: opponentSource ?? this.opponentSource,
      playerSource: playerSource ?? this.playerSource,
      turn: turn ?? this.turn,
      eval: eval ?? this.eval,
      engineKind: engineKind ?? this.engineKind,
      playerSide: playerSide ?? this.playerSide,
      playerSidePreference: playerSidePreference ?? this.playerSidePreference,
      timeMinutes: timeMinutes ?? this.timeMinutes,
      incrementSeconds: incrementSeconds ?? this.incrementSeconds,
      stockfishElo: stockfishElo ?? this.stockfishElo,
      stockfishThinkingTime:
          stockfishThinkingTime ?? this.stockfishThinkingTime,
      maiaElo: maiaElo ?? this.maiaElo,
      maiaSearchStyle: maiaSearchStyle ?? this.maiaSearchStyle,
      maiaSearchDepth: maiaSearchDepth ?? this.maiaSearchDepth,
      lc0WeightKey: lc0WeightKey ?? this.lc0WeightKey,
      lc0WeightLabel: lc0WeightLabel ?? this.lc0WeightLabel,
      lc0WeightPath: lc0WeightPath ?? this.lc0WeightPath,
      opening: opening ?? this.opening,
      startFen: startFen ?? this.startFen,
      chess960: chess960 ?? this.chess960,
      showPgnList: showPgnList ?? this.showPgnList,
      careerMode: clearCareerMode ? null : (careerMode ?? this.careerMode),
      resumePgn: clearResumePgn ? null : (resumePgn ?? this.resumePgn),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'engine_kind': engineKind.name,
      'player_side': playerSide.name,
      if (playerSidePreference != null)
        'player_side_preference': playerSidePreference!.name,
      'time_minutes': timeMinutes,
      'increment_seconds': incrementSeconds,
      'stockfish_elo': stockfishElo,
      'stockfish_thinking_time_ms': stockfishThinkingTime.inMilliseconds,
      'maia_elo': maiaElo,
      'maia_search_style': maiaSearchStyle.name,
      'maia_search_depth': maiaSearchDepth,
      'lc0_weight_key': lc0WeightKey,
      'lc0_weight_label': lc0WeightLabel,
      'lc0_weight_path': lc0WeightPath,
      'opening_id': opening.id,
      'chess960': chess960,
      'show_pgn_list': showPgnList,
      'career_mode': careerMode?.toJson(),
    };
  }

  factory BotGameConfig.fromJson(Map<String, dynamic> json) {
    const base = BotGameConfig.defaultConfig();
    final engineKind = _enumByName(BotEngineKind.values, json['engine_kind']) ??
        base.engineKind;
    final playerSide = _enumByName(BotPlayerSide.values, json['player_side']) ??
        base.playerSide;
    final playerSidePreference =
        _enumByName(BotPlayerSide.values, json['player_side_preference']) ??
            playerSide;
    final maiaSearchStyle =
        _enumByName(MaiaSearchStyle.values, json['maia_search_style']) ??
            base.maiaSearchStyle;
    final opening = _openingById(json['opening_id']) ?? base.opening;
    final timeMinutes = _intFromJson(json['time_minutes']) ?? base.timeMinutes;
    final incrementSeconds =
        _intFromJson(json['increment_seconds']) ?? base.incrementSeconds;
    final stockfishElo =
        (_intFromJson(json['stockfish_elo']) ?? base.stockfishElo)
            .clamp(600, 3190)
            .toInt();
    final thinkingMs = _intFromJson(json['stockfish_thinking_time_ms']) ??
        base.stockfishThinkingTime.inMilliseconds;
    final maiaElo = _normalizeBotMaiaElo(
      _intFromJson(json['maia_elo']),
      engineKind,
    );
    final maiaSearchDepth =
        (_intFromJson(json['maia_search_depth']) ?? base.maiaSearchDepth)
            .clamp(1, 4)
            .toInt();
    final lc0WeightKey =
        _stringFromJson(json['lc0_weight_key']) ?? base.lc0WeightKey;
    final lc0WeightLabel =
        _stringFromJson(json['lc0_weight_label']) ?? base.lc0WeightLabel;
    final lc0WeightPath =
        _stringFromJson(json['lc0_weight_path']) ?? base.lc0WeightPath;
    final chess960 = json['chess960'] == true ||
        json['chess960']?.toString().toLowerCase() == 'true';
    final showPgnList = json['show_pgn_list'] != false &&
        json['show_pgn_list']?.toString().toLowerCase() != 'false';
    final rawCareerMode = json['career_mode'];
    final careerMode = rawCareerMode is Map
        ? CareerModeConfig.fromJson(
            rawCareerMode.map((key, value) => MapEntry(key.toString(), value)),
          )
        : null;
    final engineLabel = switch (engineKind) {
      BotEngineKind.maia => 'Maia $maiaElo',
      BotEngineKind.maia3 => 'Maia 3 $maiaElo',
      BotEngineKind.stockfish => 'Stockfish $stockfishElo',
      BotEngineKind.lc0 => 'LC0 $lc0WeightLabel',
    };
    final timeLabel =
        timeMinutes == 0 ? 'Unlimited' : '$timeMinutes+$incrementSeconds';
    final sideLabel = switch (playerSide) {
      BotPlayerSide.random => 'Random side',
      BotPlayerSide.white => 'White side',
      BotPlayerSide.black => 'Black side',
    };
    final turnLabel = switch (playerSide) {
      BotPlayerSide.random => 'Random to move',
      BotPlayerSide.white => 'White to move',
      BotPlayerSide.black => 'Black to move',
    };
    return BotGameConfig(
      title: '$engineLabel / $timeLabel',
      subtitle: '${opening.name} / $sideLabel',
      opponent: engineLabel,
      opponentSource: switch (engineKind) {
        BotEngineKind.maia => '${opening.focus} / ELO $maiaElo',
        BotEngineKind.maia3 => 'Cloud human model / ELO $maiaElo',
        BotEngineKind.stockfish =>
          '${opening.moves} / thinking ${_formatJsonThinkingTime(Duration(milliseconds: thinkingMs))}',
        BotEngineKind.lc0 => '${opening.eco} / $lc0WeightLabel',
      },
      playerSource:
          '$sideLabel / ${opening.eco} / coach ${engineKind == BotEngineKind.stockfish ? 'off' : 'on'}',
      turn: turnLabel,
      eval: switch (engineKind) {
        BotEngineKind.maia => '+0.4',
        BotEngineKind.maia3 => '+0.4',
        BotEngineKind.stockfish => stockfishElo >= 2000 ? '+0.1' : '+0.4',
        BotEngineKind.lc0 => '+0.2',
      },
      engineKind: engineKind,
      playerSide: playerSide,
      playerSidePreference: playerSidePreference,
      timeMinutes: timeMinutes,
      incrementSeconds: incrementSeconds,
      stockfishElo: stockfishElo,
      stockfishThinkingTime: Duration(milliseconds: thinkingMs),
      maiaElo: maiaElo,
      maiaSearchStyle: maiaSearchStyle,
      maiaSearchDepth: maiaSearchDepth,
      lc0WeightKey: lc0WeightKey,
      lc0WeightLabel: lc0WeightLabel,
      lc0WeightPath: lc0WeightPath,
      opening: opening,
      startFen: opening.fen,
      chess960: chess960,
      showPgnList: showPgnList,
      careerMode: careerMode,
    );
  }
}

T? _enumByName<T extends Enum>(List<T> values, Object? value) {
  final name = value?.toString();
  if (name == null) return null;
  for (final item in values) {
    if (item.name == name) return item;
  }
  return null;
}

int? _intFromJson(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

String? _stringFromJson(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

OpeningScenario? _openingById(Object? value) {
  final id = value?.toString();
  if (id == null || id.isEmpty) return null;
  for (final opening in botOpeningScenarios) {
    if (opening.id == id) return opening;
  }
  return null;
}

int _normalizeBotMaiaElo(int? value, BotEngineKind engineKind) {
  if (engineKind == BotEngineKind.maia3) {
    return _normalizeMaia3Elo(value);
  }
  return _nearestMaia1Elo(value);
}

int _normalizeMaia3Elo(int? value) {
  if (value == null) return 1500;
  final clamped = value.clamp(maia3MinElo, maia3MaxElo).toInt();
  return (clamped / maia3EloStep).round() * maia3EloStep;
}

int _nearestMaia1Elo(int? value) {
  const supported = maia1SupportedElos;
  if (value == null) return 1500;
  var nearest = supported.first;
  var distance = (nearest - value).abs();
  for (final elo in supported.skip(1)) {
    final nextDistance = (elo - value).abs();
    if (nextDistance < distance) {
      nearest = elo;
      distance = nextDistance;
    }
  }
  return nearest;
}

String _formatJsonThinkingTime(Duration duration) {
  if (duration == Duration.zero) return 'auto';
  if (duration.inMilliseconds < 1000) return '${duration.inMilliseconds}ms';
  if (duration.inSeconds < 60) return '${duration.inSeconds}s';
  return '${duration.inMinutes}m';
}

class OtbGameConfig {
  const OtbGameConfig({
    this.timeMinutes = 10,
    this.incrementSeconds = 5,
    this.opening = standardOpeningScenario,
    this.startFen = chessnutStandardStartFen,
    this.chess960 = false,
    this.showPgnList = true,
    this.resumePgn,
  });

  final int timeMinutes;
  final int incrementSeconds;
  final OpeningScenario opening;
  final String startFen;
  final bool chess960;
  final bool showPgnList;
  final String? resumePgn;

  String get timeLabel =>
      timeMinutes <= 0 ? 'Unlimited' : '$timeMinutes+$incrementSeconds';
}

class LichessGameConfig {
  const LichessGameConfig({
    required this.gameId,
    required this.token,
    this.lichessName = '',
    this.timeMinutes = 10,
    this.incrementSeconds = 5,
    this.rated = false,
    this.moveLeds = true,
    this.resumePgn,
  });

  const LichessGameConfig.empty()
      : gameId = '',
        token = '',
        lichessName = '',
        timeMinutes = 10,
        incrementSeconds = 5,
        rated = false,
        moveLeds = true,
        resumePgn = null;

  final String gameId;
  final String token;
  final String lichessName;
  final int timeMinutes;
  final int incrementSeconds;
  final bool rated;
  final bool moveLeds;
  final String? resumePgn;

  bool get isReady => gameId.isNotEmpty && token.isNotEmpty;

  String get timeLabel =>
      timeMinutes <= 0 ? 'Unlimited' : '$timeMinutes+$incrementSeconds';
}

typedef LaunchGameCallback = void Function(
  GameLaunchMode mode, {
  BotGameConfig? botConfig,
  OtbGameConfig? otbConfig,
  LichessGameConfig? lichessConfig,
});

class BoardPiece {
  const BoardPiece(this.square, this.code);

  final String square;
  final String code;
}

class GameRecord {
  const GameRecord({
    required this.result,
    required this.title,
    required this.subtitle,
    required this.pgn,
    this.pgnSource = '',
    this.localRecordId = '',
    this.pgnId,
    this.shareId,
    this.playMode = '',
    this.gameStatus = 0,
    this.gameStep = 0,
    this.winId = 0,
    this.whiteName = '',
    this.blackName = '',
    this.commentId = 0,
    this.sortAt,
    this.hasGrandeurReport = false,
    this.lichessGameIdOverride = '',
    this.chessnutGameIdOverride = '',
    this.lichessTokenOverride = '',
    this.lichessNameOverride = '',
    this.playerColorOverride = '',
    this.speedOverride = '',
    this.timeControlOverride = '',
    this.opponentNameOverride = '',
  });

  final String result;
  final String title;
  final String subtitle;
  final String pgn;
  final String pgnSource;
  final String localRecordId;
  final int? pgnId;
  final String? shareId;
  final String playMode;
  final int gameStatus;
  final int gameStep;
  final int winId;
  final String whiteName;
  final String blackName;
  final int commentId;
  final DateTime? sortAt;
  final bool hasGrandeurReport;
  final String lichessGameIdOverride;
  final String chessnutGameIdOverride;
  final String lichessTokenOverride;
  final String lichessNameOverride;
  final String playerColorOverride;
  final String speedOverride;
  final String timeControlOverride;
  final String opponentNameOverride;

  bool get isPgnPending => pgn.isEmpty && pgnSource.isNotEmpty;

  bool get hasRemotePgnSource {
    final source = pgnSource.trim();
    return source.startsWith('http://') ||
        source.startsWith('https://') ||
        source.startsWith('/');
  }

  GameRecord withPgn(String value) {
    return GameRecord(
      result: result,
      title: title,
      subtitle: subtitle,
      pgn: value,
      pgnSource: pgnSource,
      localRecordId: localRecordId,
      pgnId: pgnId,
      shareId: shareId,
      playMode: playMode,
      gameStatus: gameStatus,
      gameStep: gameStep,
      winId: winId,
      whiteName: whiteName,
      blackName: blackName,
      commentId: commentId,
      sortAt: sortAt,
      hasGrandeurReport: hasGrandeurReport,
      lichessGameIdOverride: lichessGameIdOverride,
      chessnutGameIdOverride: chessnutGameIdOverride,
      lichessTokenOverride: lichessTokenOverride,
      lichessNameOverride: lichessNameOverride,
      playerColorOverride: playerColorOverride,
      speedOverride: speedOverride,
      timeControlOverride: timeControlOverride,
      opponentNameOverride: opponentNameOverride,
    );
  }

  bool get hasFinishedResult {
    final token = finishedResultToken;
    return token == '1-0' || token == '0-1' || token == '1/2-1/2';
  }

  bool get isInProgress {
    if (hasFinishedResult) return false;
    final status = declaredGameStatus;
    if (status == 2) return false;
    return status == 1 || (status == 0 && winId == 0 && result == '*');
  }

  int get declaredGameStatus {
    final headerStatus = int.tryParse(_header('GameStatus').trim());
    return headerStatus ?? gameStatus;
  }

  bool get canContinueBotGame =>
      isInProgress &&
      winId == 0 &&
      result == '*' &&
      playMode.trim().toLowerCase() == 'bot' &&
      pgn.isNotEmpty;

  bool get canContinueLichessGame =>
      isInProgress &&
      winId == 0 &&
      result == '*' &&
      playMode.trim().toLowerCase().contains('lichess') &&
      pgn.isNotEmpty &&
      lichessGameId.isNotEmpty;

  bool get canContinueOtbGame =>
      isInProgress &&
      winId == 0 &&
      result == '*' &&
      playMode.trim().toLowerCase() == 'otb' &&
      pgn.isNotEmpty;

  bool get canContinueChessComGame => false;

  bool get canContinueGame =>
      canContinueBotGame ||
      canContinueLichessGame ||
      canContinueOtbGame ||
      canContinueChessComGame;

  String get lichessGameId {
    final header = _header('LichessGameId').trim();
    return header.isNotEmpty ? header : lichessGameIdOverride.trim();
  }

  String get chessnutGameId {
    final header = _header('ChessnutGameId').trim();
    return header.isNotEmpty ? header : chessnutGameIdOverride.trim();
  }

  String get lichessToken {
    final header = _header('LichessToken').trim();
    return header.isNotEmpty ? header : lichessTokenOverride.trim();
  }

  String get lichessName {
    final header = _header('LichessName').trim();
    return header.isNotEmpty ? header : lichessNameOverride.trim();
  }

  String get declaredPlayerColor {
    final explicit = playerColorOverride.trim().toLowerCase();
    if (explicit == 'white' || explicit == 'black') return explicit;
    final side = _header('PlayerSide').trim().toLowerCase();
    if (side == 'white' || side == 'w') return 'white';
    if (side == 'black' || side == 'b') return 'black';
    return '';
  }

  String get timeControl {
    final explicit = timeControlOverride.trim();
    return explicit.isNotEmpty ? explicit : _header('TimeControl').trim();
  }

  bool get isRated => _header('Rated').toLowerCase() == 'true';

  String get speed {
    final explicit = _speedLabelFromText(speedOverride);
    if (explicit.isNotEmpty) return explicit;
    final chessComTimeControl = _speedFromTimeControl(
      _header('TimeControl'),
      site: _header('Site'),
    );
    if (_isChessComRecord && chessComTimeControl.isNotEmpty) {
      return chessComTimeControl;
    }
    final timeControlCategory =
        _speedLabelFromText(_header('TimeControlCategory'));
    if (timeControlCategory.isNotEmpty) return timeControlCategory;
    final speedHeader = _speedLabelFromText(_header('Speed'));
    if (speedHeader.isNotEmpty) return speedHeader;
    final timeClass = _speedLabelFromText(_header('TimeClass'));
    if (timeClass.isNotEmpty) return timeClass;
    final event = _speedLabelFromText(_header('Event'));
    if (event.isNotEmpty) return event;
    final contextual = _speedLabelFromText(
      '$playMode $subtitle ${_header('Variant')} ${_header('Source')}',
    );
    if (contextual.isNotEmpty) return contextual;
    if (playMode.trim().toLowerCase().contains('career')) return 'casual';
    return _speedFromTimeControl(
      _header('TimeControl').trim().isNotEmpty
          ? _header('TimeControl')
          : '$playMode $subtitle',
      site: _header('Site'),
    );
  }

  String get playerColor {
    final declared = declaredPlayerColor;
    if (declared.isNotEmpty) return declared;
    final white = whiteName.toLowerCase();
    final black = blackName.toLowerCase();
    if (white.contains('chessnut') || white.contains('player')) return 'white';
    if (black.contains('chessnut') || black.contains('player')) return 'black';
    return '';
  }

  String get opponentName {
    final explicit = opponentNameOverride.trim();
    if (explicit.isNotEmpty) return explicit;
    final color = playerColor;
    if (color == 'white') return blackName;
    if (color == 'black') return whiteName;
    return '$whiteName $blackName'.trim();
  }

  String get displayWhiteName {
    final explicit = whiteName.trim();
    if (explicit.isNotEmpty) return explicit;
    final header = _header('White').trim();
    if (header.isNotEmpty) return header;
    return _titleSideName(0) ?? 'White';
  }

  String get displayBlackName {
    final explicit = blackName.trim();
    if (explicit.isNotEmpty) return explicit;
    final header = _header('Black').trim();
    if (header.isNotEmpty) return header;
    return _titleSideName(1) ?? 'Black';
  }

  String get playerSummary =>
      'White: $displayWhiteName / Black: $displayBlackName';

  String get timeSummary => 'Time: $timeLabel';

  String get dateSummary => 'Date: $dateLabel';

  String get locationSummary => 'Location: $locationLabel';

  String get dateLabel {
    final sorted = sortAt;
    if (sorted != null) return _formatDate(sorted);
    final dateHeader = _header('Date').trim();
    if (dateHeader.isEmpty || dateHeader == '????.??.??') return 'Unknown';
    final parts = dateHeader.split('.');
    if (parts.length >= 3) {
      final year = parts[0];
      final month = parts[1].padLeft(2, '0');
      final day = parts[2].padLeft(2, '0');
      if (!year.contains('?') && !month.contains('?') && !day.contains('?')) {
        return '$year-$month-$day';
      }
    }
    return dateHeader.replaceAll('.', '-');
  }

  String get locationLabel {
    final site = _header('Site').trim();
    if (site.isEmpty || site == '?' || site == '-') return 'Unknown';
    return site;
  }

  Uri? get chessComGameUrl {
    final site = _header('Site').trim();
    final uri = Uri.tryParse(site);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return null;
    if (uri.scheme != 'https' || uri.host != 'www.chess.com') return null;
    return uri;
  }

  String get resultLabel {
    if (isInProgress) return '';
    final resultToken = finishedResultToken;
    if (resultToken == '1-0') return '$displayWhiteName wins';
    if (resultToken == '0-1') return '$displayBlackName wins';
    if (resultToken == '1/2-1/2') return 'Draw';
    return '';
  }

  String get finishedResultToken {
    if (winId == 1) return '1-0';
    if (winId == 2) return '0-1';
    if (winId == 3) return '1/2-1/2';
    final pgnResult = _header('Result').trim();
    if (pgnResult.isNotEmpty && pgnResult != '*') return pgnResult;
    return result.trim();
  }

  String? _titleSideName(int index) {
    final parts = title.split(RegExp(r'\s+vs\s+', caseSensitive: false));
    if (parts.length != 2) return null;
    final name = parts[index].trim();
    return name.isEmpty ? null : name;
  }

  int get fullMoveCount {
    if (gameStep > 0) return (gameStep / 2).ceil();
    return RegExp(r'\b\d+\.').allMatches(pgn).length;
  }

  String get timeLabel {
    final chessComSpeedLabel = _chessComSpeedTimeLabel;
    if (chessComSpeedLabel.isNotEmpty) return chessComSpeedLabel;
    final timeControl = this.timeControl;
    return timeControl.isEmpty ? '10+5' : timeControl;
  }

  String get openingLabel {
    final opening = _header('Opening').trim();
    final eco = _header('ECO').trim();
    if (opening.isNotEmpty && eco.isNotEmpty) return '$eco $opening';
    return opening.isNotEmpty ? opening : eco;
  }

  String _formatDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  bool get _isChessComRecord {
    final mode = playMode.trim().toLowerCase();
    if (mode.contains('chesscom') || mode.contains('chess.com')) return true;
    final source = _header('Source').trim().toLowerCase();
    if (source.contains('chess.com')) return true;
    final site = _header('Site').trim().toLowerCase();
    if (site.contains('chess.com')) return true;
    return false;
  }

  String get _chessComSpeedTimeLabel {
    if (!_isChessComRecord) return '';
    final fromTimeControl = _speedFromTimeControl(
      _header('TimeControl'),
      site: _header('Site'),
    );
    if (fromTimeControl.isNotEmpty) {
      return _speedDisplayLabel(fromTimeControl);
    }
    final speedHeader = _speedLabelFromText(_header('Speed'));
    if (speedHeader.isNotEmpty) return _speedDisplayLabel(speedHeader);
    final timeClass = _speedLabelFromText(_header('TimeClass'));
    if (timeClass.isNotEmpty) return _speedDisplayLabel(timeClass);
    final category = _speedLabelFromText(_header('TimeControlCategory'));
    if (category.isNotEmpty) return _speedDisplayLabel(category);
    return '';
  }

  String _header(String name) {
    final match =
        RegExp('^\\[$name\\s+"(.*)"\\]\$', multiLine: true).firstMatch(pgn);
    return match?.group(1) ?? '';
  }

  String _speedDisplayLabel(String value) {
    return switch (value) {
      'casual' => 'Casual',
      'bullet' => 'Bullet',
      'blitz' => 'Blitz',
      'rapid' => 'Rapid',
      'daily' => 'Daily',
      'classical' => 'Classical',
      _ => '',
    };
  }

  String _speedLabelFromText(String value) {
    final normalized =
        value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]+'), ' ');
    if (normalized.isEmpty) return '';
    final tokens =
        normalized.split(RegExp(r'\s+')).where((token) => token.isNotEmpty);
    if (tokens.any((token) =>
        token == 'casual' ||
        token == 'unlimited' ||
        token == 'untimed' ||
        token == 'infinite')) {
      return 'casual';
    }
    if (tokens.any((token) => token.contains('bullet'))) return 'bullet';
    if (tokens.any((token) => token.contains('ultrabullet'))) return 'bullet';
    if (tokens.contains('blitz')) return 'blitz';
    if (tokens.contains('rapid')) return 'rapid';
    if (tokens.contains('correspondence') || tokens.contains('daily')) {
      return 'daily';
    }
    if (tokens.contains('classical') || tokens.contains('classic')) {
      return 'classical';
    }
    return '';
  }

  String _speedFromTimeControl(String value, {required String site}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final lowerValue = trimmed.toLowerCase();
    if (lowerValue == '-' ||
        lowerValue == '0' ||
        lowerValue == '0+0' ||
        lowerValue.contains('unlimited') ||
        lowerValue.contains('untimed') ||
        lowerValue.contains('infinite') ||
        lowerValue.contains('casual')) {
      return 'casual';
    }
    if (RegExp(r'\b\d+\s*(?:day|days)\b', caseSensitive: false)
        .hasMatch(trimmed)) {
      return 'daily';
    }
    final incrementMatch =
        RegExp(r'\b(\d+)\s*[+|]\s*(\d+)\b').firstMatch(trimmed);
    final wholeValueMatch = RegExp(r'^\s*(\d+)\s*$').firstMatch(trimmed);
    final minuteMatch = RegExp(
      r'\b(\d+)\s*(?:min|mins|minute|minutes)\b',
      caseSensitive: false,
    ).firstMatch(trimmed);
    final match = incrementMatch ?? wholeValueMatch ?? minuteMatch;
    if (match == null) return '';
    final base = int.tryParse(match.group(1)?.trim() ?? '');
    if (base == null || base <= 0) return '';
    final increment = incrementMatch == null
        ? 0
        : int.tryParse(incrementMatch.group(2)?.trim() ?? '') ?? 0;
    final lowerSite = site.trim().toLowerCase();
    final chessnutMinutes = minuteMatch != null ||
        lowerSite.contains('chessnut app') ||
        lowerValue.contains('chessnut') ||
        lowerValue.contains('bot') ||
        lowerValue.contains('otb') ||
        base < 60;
    final estimatedSeconds =
        chessnutMinutes ? base * 60 + increment * 40 : base + increment * 40;
    if (lowerSite.contains('chess.com')) {
      if (estimatedSeconds >= 24 * 60 * 60) return 'daily';
      if (estimatedSeconds < 3 * 60) return 'bullet';
      if (estimatedSeconds < 10 * 60) return 'blitz';
      return 'rapid';
    }
    if (estimatedSeconds < 3 * 60) return 'bullet';
    if (estimatedSeconds < 8 * 60) return 'blitz';
    if (estimatedSeconds < 25 * 60) return 'rapid';
    return 'classical';
  }
}
