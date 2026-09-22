import 'package:flutter/material.dart';

class ModuleGuideDefinition {
  const ModuleGuideDefinition({
    required this.id,
    required this.routeLabel,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.steps,
  });

  final String id;
  final String routeLabel;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<ModuleGuideStep> steps;

  ModuleGuideDefinition copyWith({
    String? subtitle,
    List<ModuleGuideStep>? steps,
  }) {
    return ModuleGuideDefinition(
      id: id,
      routeLabel: routeLabel,
      title: title,
      subtitle: subtitle ?? this.subtitle,
      icon: icon,
      steps: steps ?? this.steps,
    );
  }
}

class ModuleGuideStep {
  const ModuleGuideStep({
    required this.title,
    required this.body,
    this.targetKey,
    this.fallbackTargetKey,
  });

  final String title;
  final String body;
  final ValueKey<String>? targetKey;
  final ValueKey<String>? fallbackTargetKey;
}

const moduleGuideDefinitions = [
  ModuleGuideDefinition(
    id: 'home',
    routeLabel: 'Home',
    title: 'Home',
    subtitle: 'Your daily launchpad for play, study, review, and devices.',
    icon: Icons.home_rounded,
    steps: [
      ModuleGuideStep(
        title: 'Start playing',
        body: 'Use Play to choose bot, online, OTB, or clock modes.',
        targetKey: ValueKey('home-action-play'),
      ),
      ModuleGuideStep(
        title: 'Practice plan',
        body:
            'Practice brings puzzles, lessons, mistakes, and live analysis together.',
        targetKey: ValueKey('home-action-training'),
      ),
      ModuleGuideStep(
        title: 'Review games',
        body: 'Game Review helps you analyze saved or imported games.',
        targetKey: ValueKey('home-action-analysis'),
      ),
    ],
  ),
  ModuleGuideDefinition(
    id: 'choose_path',
    routeLabel: 'Setup',
    title: 'Choose path',
    subtitle: 'Start the right kind of game from one focused place.',
    icon: Icons.route_rounded,
    steps: [
      ModuleGuideStep(
        title: 'Play online',
        body: 'Connect to online games when you want a real opponent.',
        targetKey: ValueKey('path-online'),
      ),
      ModuleGuideStep(
        title: 'Bot games',
        body: 'Choose Maia, Maia 3, Stockfish, or your enabled LC0 engines.',
        targetKey: ValueKey('path-bot'),
      ),
      ModuleGuideStep(
        title: 'Board setup',
        body: 'Use the editor when you want to start from a custom position.',
        targetKey: ValueKey('path-editor'),
      ),
      ModuleGuideStep(
        title: 'OTB and clock',
        body:
            'Record a physical-board game or open the standalone chess clock.',
        targetKey: ValueKey('path-otb'),
      ),
    ],
  ),
  ModuleGuideDefinition(
    id: 'bot_game',
    routeLabel: 'Bot',
    title: 'Choose bot',
    subtitle: 'Pick an engine, position, side, and time control.',
    icon: Icons.smart_toy_rounded,
    steps: [
      ModuleGuideStep(
        title: 'Choose engine',
        body: 'Select Maia, Maia 3, Stockfish, or an enabled personal engine.',
        targetKey: ValueKey('bot-setup-engine-panel'),
      ),
      ModuleGuideStep(
        title: 'Starting position',
        body: 'Use Standard, 960, Opening, or Board Editor positions here.',
        targetKey: ValueKey('bot-setup-starting-panel'),
      ),
      ModuleGuideStep(
        title: 'Side and time',
        body: 'Choose your color and time control before starting the game.',
        targetKey: ValueKey('bot-setup-play-settings-panel'),
      ),
    ],
  ),
  ModuleGuideDefinition(
    id: 'online_match',
    routeLabel: 'Online',
    title: 'Online match',
    subtitle: 'Start Lichess or Chess.com games with board sync.',
    icon: Icons.public_rounded,
    steps: [
      ModuleGuideStep(
        title: 'Choose platform',
        body: 'Use Lichess native play or the Chess.com WebView flow.',
        targetKey: ValueKey('online-platform-panel'),
      ),
      ModuleGuideStep(
        title: 'Authorize Lichess',
        body: 'Bind Lichess before seeking native online games.',
        targetKey: ValueKey('online-lichess-auth-panel'),
      ),
      ModuleGuideStep(
        title: 'Match settings',
        body: 'Set time control, rated mode, auto submit, and move LEDs.',
        targetKey: ValueKey('online-match-settings-panel'),
      ),
    ],
  ),
  ModuleGuideDefinition(
    id: 'otb_game',
    routeLabel: 'OtbSetup',
    title: 'OTB game',
    subtitle: 'Record physical-board games or use the clock.',
    icon: Icons.people_alt_rounded,
    steps: [
      ModuleGuideStep(
        title: 'Time control',
        body: 'Choose a preset or custom time before starting.',
        targetKey: ValueKey('otb-time-control-card'),
      ),
      ModuleGuideStep(
        title: 'Record game',
        body: 'Track legal moves, clocks, and PGN for later review.',
        targetKey: ValueKey('otb-record-mode-card'),
      ),
      ModuleGuideStep(
        title: 'Chess clock',
        body: 'Open a standalone clock when you do not need PGN recording.',
        targetKey: ValueKey('otb-clock-mode-card'),
      ),
    ],
  ),
  ModuleGuideDefinition(
    id: 'chess_clock',
    routeLabel: 'Clock',
    title: 'Chess Clock',
    subtitle: 'Use the app as a two-player clock.',
    icon: Icons.timer_rounded,
    steps: [
      ModuleGuideStep(
        title: 'White clock',
        body: 'Tap the active clock after a move, or use the hardware switch.',
        targetKey: ValueKey('clock-face-white'),
      ),
      ModuleGuideStep(
        title: 'Black clock',
        body: 'Only the active side can switch turns during the game.',
        targetKey: ValueKey('clock-face-black'),
      ),
      ModuleGuideStep(
        title: 'Clock controls',
        body: 'Start, pause, reset, and exit the clock from this control area.',
        targetKey: ValueKey('clock-control-dock'),
      ),
    ],
  ),
  ModuleGuideDefinition(
    id: 'bot_game_room',
    routeLabel: 'Play:bot',
    title: 'Bot game',
    subtitle: 'Play against an engine with board sync and review tools.',
    icon: Icons.smart_toy_rounded,
    steps: [
      ModuleGuideStep(
        title: 'Game board',
        body: 'Play your moves on the virtual board or a connected board.',
        targetKey: ValueKey('game-board-frame'),
      ),
      ModuleGuideStep(
        title: 'Board connection',
        body:
            'Check here whether your Chessnut board is connected and syncing.',
        targetKey: ValueKey('game-room-status-capsules'),
      ),
      ModuleGuideStep(
        title: 'Move list and actions',
        body: 'Review recent moves and open game options from the action bar.',
        targetKey: ValueKey('game-pgn-strip'),
      ),
    ],
  ),
  ModuleGuideDefinition(
    id: 'online_match_room',
    routeLabel: 'Play:online',
    title: 'Online match',
    subtitle: 'Play live online games while Chessnut keeps the board in sync.',
    icon: Icons.public_rounded,
    steps: [
      ModuleGuideStep(
        title: 'Connection status',
        body: 'Check latency, voice moves, and physical-board connection here.',
        targetKey: ValueKey('game-room-status-capsules'),
      ),
      ModuleGuideStep(
        title: 'Game board',
        body: 'The board mirrors the online game and accepts your legal moves.',
        targetKey: ValueKey('game-board-frame'),
      ),
      ModuleGuideStep(
        title: 'Game actions',
        body:
            'Use actions to flip, review moves, and open more online options.',
        targetKey: ValueKey('game-actions'),
      ),
    ],
  ),
  ModuleGuideDefinition(
    id: 'record_game',
    routeLabel: 'Play:otb',
    title: 'Record game',
    subtitle: 'Play face to face while Chessnut records the PGN.',
    icon: Icons.grid_on_rounded,
    steps: [
      ModuleGuideStep(
        title: 'Game clocks',
        body: "Watch both players' time and whose turn is active.",
        targetKey: ValueKey('game-clock-top'),
      ),
      ModuleGuideStep(
        title: 'Move list',
        body: 'The PGN strip shows the latest recorded moves.',
        targetKey: ValueKey('game-pgn-strip'),
      ),
      ModuleGuideStep(
        title: 'Game actions',
        body: 'Open game options such as draw, takeback, resign, or leave.',
        targetKey: ValueKey('game-actions'),
      ),
    ],
  ),
  ModuleGuideDefinition(
    id: 'game_records',
    routeLabel: 'Records',
    title: 'Game history',
    subtitle: 'Review, continue, import, and manage saved games.',
    icon: Icons.history_rounded,
    steps: [
      ModuleGuideStep(
        title: 'Sources',
        body: 'Switch between Chessnut, Lichess, and Chess.com records.',
        targetKey: ValueKey('game-record-source-tabs'),
        fallbackTargetKey: ValueKey('game-record-state-card'),
      ),
      ModuleGuideStep(
        title: 'Filters',
        body: 'Filter and search when your game history grows.',
        targetKey: ValueKey('game-record-filter-toggle'),
        fallbackTargetKey: ValueKey('game-record-state-card'),
      ),
      ModuleGuideStep(
        title: 'More actions',
        body:
            'Use the three-dot menu or long press for copy, delete, and continue.',
        targetKey: ValueKey('game-record-selection-toolbar-enter'),
        fallbackTargetKey: ValueKey('game-record-state-card'),
      ),
    ],
  ),
  ModuleGuideDefinition(
    id: 'app_settings',
    routeLabel: 'Settings',
    title: 'App settings',
    subtitle: 'Adjust app language, appearance, sounds, and guides.',
    icon: Icons.settings_rounded,
    steps: [
      ModuleGuideStep(
        title: 'Language',
        body: 'Choose the app language used across the interface.',
        targetKey: ValueKey('settings-language-row'),
      ),
      ModuleGuideStep(
        title: 'General preferences',
        body: 'Control coordinates, background board connection, and sounds.',
        targetKey: ValueKey('settings-general-section'),
      ),
      ModuleGuideStep(
        title: 'Replay guides',
        body: 'Open this when you want to watch first-time guides again.',
        targetKey: ValueKey('settings-replay-guides-tile'),
      ),
    ],
  ),
  ModuleGuideDefinition(
    id: 'board_settings',
    routeLabel: 'BoardSettings',
    title: 'Board settings',
    subtitle: 'Tune board sync, LEDs, voice moves, firmware, and clock switch.',
    icon: Icons.settings_input_component_rounded,
    steps: [
      ModuleGuideStep(
        title: 'Board status',
        body: 'Check the connected board model and battery status here.',
        targetKey: ValueKey('board-settings-hero'),
      ),
      ModuleGuideStep(
        title: 'Move logic',
        body: 'Adjust move delay, restore timing, and voice-move language.',
        targetKey: ValueKey('board-settings-move-logic-section'),
      ),
      ModuleGuideStep(
        title: 'Board lights',
        body: 'Control the board LED hints used while setting up and playing.',
        targetKey: ValueKey('board-settings-lights-section'),
      ),
    ],
  ),
  ModuleGuideDefinition(
    id: 'practice',
    routeLabel: 'Training',
    title: 'Practice',
    subtitle: 'A training hub for puzzles, lessons, mistakes, and analysis.',
    icon: Icons.school_rounded,
    steps: [
      ModuleGuideStep(
        title: 'Puzzle Themes',
        body: 'Choose one tactical motif and practice it directly.',
        targetKey: ValueKey('practice-mode-puzzle-themes'),
      ),
      ModuleGuideStep(
        title: 'Mistake Book',
        body: 'Turn reviewed game mistakes into a personal training queue.',
        targetKey: ValueKey('practice-mode-mistake-book'),
      ),
      ModuleGuideStep(
        title: 'Board Analyzer',
        body: 'Explore any position with live engine feedback.',
        targetKey: ValueKey('practice-mode-board-analyzer'),
      ),
    ],
  ),
  ModuleGuideDefinition(
    id: 'puzzle_themes',
    routeLabel: 'PuzzleThemes',
    title: 'Puzzle Themes',
    subtitle: 'Practice one motif at a time instead of random tactics.',
    icon: Icons.extension_rounded,
    steps: [
      ModuleGuideStep(
        title: 'Choose a theme',
        body: 'Open the theme picker when you want a different tactic type.',
        targetKey: ValueKey('puzzle-theme-chooser-card'),
      ),
      ModuleGuideStep(
        title: 'Solve on the board',
        body:
            'Use the board area to play the answer, with physical board sync when connected.',
        targetKey: ValueKey('puzzle-theme-board-area'),
      ),
      ModuleGuideStep(
        title: 'Side to move',
        body: 'Check whose turn it is before calculating the tactic.',
        targetKey: ValueKey('puzzle-side-to-move-card'),
      ),
    ],
  ),
  ModuleGuideDefinition(
    id: 'engine_lab',
    routeLabel: 'Engine',
    title: 'Engine Lab',
    subtitle: 'Manage the engines that can appear in bot games.',
    icon: Icons.memory_rounded,
    steps: [
      ModuleGuideStep(
        title: 'Enabled engines',
        body: 'Only enabled engines from this library appear in bot setup.',
        targetKey: ValueKey('engine-library-search'),
      ),
      ModuleGuideStep(
        title: 'Personal engine',
        body: 'Build and manage engines trained from your own game sources.',
        targetKey: ValueKey('engine-lab-entry-personal'),
      ),
      ModuleGuideStep(
        title: 'Engine market',
        body: 'Download Chessnut-provided popular LC0 engines here.',
        targetKey: ValueKey('engine-lab-entry-market'),
      ),
    ],
  ),
  ModuleGuideDefinition(
    id: 'game_review',
    routeLabel: 'Analysis',
    title: 'Game Review',
    subtitle: 'Review a full game through Stockfish, Maia, and Grandeur.',
    icon: Icons.analytics_rounded,
    steps: [
      ModuleGuideStep(
        title: 'Import a game',
        body:
            'Import PGN when you want to review a game from outside Chessnut.',
        targetKey: ValueKey('analysis-import-entry'),
      ),
      ModuleGuideStep(
        title: 'Game history',
        body: 'Open saved games and generate reports from your records.',
        targetKey: ValueKey('analysis-game-record-entry'),
      ),
      ModuleGuideStep(
        title: 'Live analysis',
        body: 'Jump to Board Analyzer for real-time position exploration.',
        targetKey: ValueKey('analysis-live-analysis-entry'),
      ),
    ],
  ),
  ModuleGuideDefinition(
    id: 'mistake_book',
    routeLabel: 'MistakeBook',
    title: 'Mistake Book',
    subtitle: 'A focused review queue built from your own weak moves.',
    icon: Icons.menu_book_rounded,
    steps: [
      ModuleGuideStep(
        title: 'Filter mistakes',
        body: 'Use filters to focus on due, blunder, or mastered positions.',
        targetKey: ValueKey('mistake-book-filter-section'),
        fallbackTargetKey: ValueKey('mistake-book-empty-card'),
      ),
      ModuleGuideStep(
        title: 'Search your book',
        body: 'Search by game, motif, or move when the list grows long.',
        targetKey: ValueKey('mistake-book-search-section'),
        fallbackTargetKey: ValueKey('mistake-book-empty-card'),
      ),
      ModuleGuideStep(
        title: 'Page through reviews',
        body: 'Use the pager to move through compact batches.',
        targetKey: ValueKey('mistake-book-pager-section'),
        fallbackTargetKey: ValueKey('mistake-book-empty-card'),
      ),
    ],
  ),
  ModuleGuideDefinition(
    id: 'career',
    routeLabel: 'Career',
    title: 'Career',
    subtitle: 'Progress through chess challenges like a game campaign.',
    icon: Icons.military_tech_rounded,
    steps: [
      ModuleGuideStep(
        title: 'Find opponent',
        body: 'Start the next Career challenge from here.',
        targetKey: ValueKey('career-find-opponent-button'),
      ),
      ModuleGuideStep(
        title: 'Career journey',
        body: 'Track your route, milestones, and current stage.',
        targetKey: ValueKey('career-component-route'),
      ),
      ModuleGuideStep(
        title: 'Training focus',
        body:
            'Use recommended practice when you want to prepare for the next match.',
        targetKey: ValueKey('career-stage-focus-row'),
      ),
    ],
  ),
  ModuleGuideDefinition(
    id: 'board_editor',
    routeLabel: 'Editor',
    title: 'Board Editor',
    subtitle: 'Set up a position from FEN or the physical board.',
    icon: Icons.dashboard_customize_rounded,
    steps: [
      ModuleGuideStep(
        title: 'Board status',
        body: 'Check whether the physical board is connected and syncing.',
        targetKey: ValueKey('board-editor-status-section'),
        fallbackTargetKey: ValueKey('board-editor-board-section'),
      ),
      ModuleGuideStep(
        title: 'Edit controls',
        body:
            'Use these controls to read from the board, send FEN, and adjust position settings.',
        targetKey: ValueKey('board-editor-edit-controls-section'),
      ),
      ModuleGuideStep(
        title: 'Start from here',
        body: 'Start a bot game from the edited position when it is ready.',
        targetKey: ValueKey('board-editor-start-bot-button'),
      ),
    ],
  ),
];

ModuleGuideDefinition moduleGuideDefinitionForDevice(
  ModuleGuideDefinition definition, {
  required bool isChessnutClockDevice,
}) {
  if (definition.id != 'otb_game' || isChessnutClockDevice) {
    return definition;
  }
  return definition.copyWith(
    subtitle: 'Record physical-board games.',
    steps: definition.steps
        .where(
          (step) => step.targetKey != const ValueKey('otb-clock-mode-card'),
        )
        .toList(growable: false),
  );
}

final Map<String, ModuleGuideDefinition> _moduleGuideDefinitionsByRoute = {
  for (final definition in moduleGuideDefinitions)
    definition.routeLabel: definition,
};

final Map<String, ModuleGuideDefinition> _moduleGuideDefinitionsById = {
  for (final definition in moduleGuideDefinitions) definition.id: definition,
};

ModuleGuideDefinition? moduleGuideDefinitionForRoute(String routeLabel) {
  return _moduleGuideDefinitionsByRoute[routeLabel];
}

ModuleGuideDefinition? moduleGuideDefinitionForId(String id) {
  return _moduleGuideDefinitionsById[id];
}
