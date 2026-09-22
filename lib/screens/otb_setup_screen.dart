import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../l10n/localized_material.dart';

import '../models/app_models.dart';
import '../services/board_settings_service.dart';
import '../services/physical_board_gateway.dart';
import '../services/app_shared_preferences.dart';
import '../widgets/app_chrome.dart';
import 'setup_screen.dart' show BotBoardEditorSheet;

class OtbSetupScreen extends StatefulWidget {
  const OtbSetupScreen({
    required this.onNavigate,
    required this.onLaunchGame,
    this.boardGateway,
    this.boardSettings = const BoardSettingsState(),
    this.showBoardCoordinates = false,
    this.isChessnutClockDevice = false,
    this.hidePhysicalBoardConnectionUi = false,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final LaunchGameCallback onLaunchGame;
  final PhysicalBoardGateway? boardGateway;
  final BoardSettingsState boardSettings;
  final bool showBoardCoordinates;
  final bool isChessnutClockDevice;
  final bool hidePhysicalBoardConnectionUi;

  @override
  State<OtbSetupScreen> createState() => _OtbSetupScreenState();
}

class _OtbSetupScreenState extends State<OtbSetupScreen> {
  static const timeOptions = [
    OtbGameConfig(timeMinutes: 0, incrementSeconds: 0),
    OtbGameConfig(timeMinutes: 1, incrementSeconds: 0),
    OtbGameConfig(timeMinutes: 2, incrementSeconds: 1),
    OtbGameConfig(timeMinutes: 3, incrementSeconds: 0),
    OtbGameConfig(timeMinutes: 3, incrementSeconds: 2),
    OtbGameConfig(timeMinutes: 5, incrementSeconds: 0),
    OtbGameConfig(timeMinutes: 5, incrementSeconds: 3),
    OtbGameConfig(timeMinutes: 10, incrementSeconds: 0),
    OtbGameConfig(timeMinutes: 10, incrementSeconds: 5),
    OtbGameConfig(timeMinutes: 15, incrementSeconds: 10),
    OtbGameConfig(timeMinutes: 30, incrementSeconds: 0),
    OtbGameConfig(timeMinutes: 30, incrementSeconds: 20),
  ];

  OtbGameConfig selectedTime = const OtbGameConfig();
  bool customTimeSelected = false;
  _OtbStartingPosition startingPosition = _OtbStartingPosition.standard;
  OpeningScenario selectedOpening = botOpeningScenarios[1];
  String boardEditorFen = chessnutStandardStartFen;
  Set<String> favoriteOpeningIds = const {};
  bool showPgnList = true;

  @override
  void initState() {
    super.initState();
    _restoreSetupSettings();
    favoriteOpeningIds = AppSharedPreferences.get<List<String>>(
      AppSettingKeys.favoriteOpeningIds,
    ).toSet();
  }

  bool get _remembersSetupSettings =>
      widget.isChessnutClockDevice ||
      (!kIsWeb &&
          const {
            TargetPlatform.android,
            TargetPlatform.iOS,
            TargetPlatform.windows,
            TargetPlatform.macOS,
          }.contains(defaultTargetPlatform));

  void _restoreSetupSettings() {
    if (!_remembersSetupSettings) return;
    if (widget.isChessnutClockDevice) {
      showPgnList = AppSharedPreferences.get<bool>(
        AppSettingKeys.otbShowPgnList,
      );
    }
    selectedTime = OtbGameConfig(
      timeMinutes: AppSharedPreferences.get<int>(
        AppSettingKeys.otbTimeMinutes,
      ),
      incrementSeconds: AppSharedPreferences.get<int>(
        AppSettingKeys.otbIncrementSeconds,
      ),
    );
    customTimeSelected = AppSharedPreferences.get<bool>(
      AppSettingKeys.otbCustomTimeSelected,
    );
    final savedPosition = AppSharedPreferences.get<String>(
      AppSettingKeys.otbStartingPosition,
    );
    startingPosition = _OtbStartingPosition.values.firstWhere(
      (value) => value.name == savedPosition,
      orElse: () => _OtbStartingPosition.standard,
    );
    final savedOpeningId = AppSharedPreferences.get<String>(
      AppSettingKeys.otbOpeningId,
    );
    selectedOpening = botOpeningScenarios.firstWhere(
      (opening) => opening.id == savedOpeningId,
      orElse: () => botOpeningScenarios[1],
    );
    final savedFen = AppSharedPreferences.get<String>(
      AppSettingKeys.otbBoardEditorFen,
    );
    if (savedFen.trim().isNotEmpty) boardEditorFen = savedFen;
  }

  void _setTimeControl(OtbGameConfig value, {required bool custom}) {
    setState(() {
      selectedTime = value;
      customTimeSelected = custom;
    });
    if (!_remembersSetupSettings) return;
    AppSharedPreferences.set(
      AppSettingKeys.otbTimeMinutes,
      value.timeMinutes,
    );
    AppSharedPreferences.set(
      AppSettingKeys.otbIncrementSeconds,
      value.incrementSeconds,
    );
    AppSharedPreferences.set(AppSettingKeys.otbCustomTimeSelected, custom);
  }

  void _setStartingPosition(_OtbStartingPosition value) {
    setState(() => startingPosition = value);
    if (!_remembersSetupSettings) return;
    AppSharedPreferences.set(AppSettingKeys.otbStartingPosition, value.name);
  }

  void _setShowPgnList(bool value) {
    setState(() => showPgnList = value);
    AppSharedPreferences.set(AppSettingKeys.otbShowPgnList, value);
  }

  Future<void> _toggleFavoriteOpening(String id) async {
    final next = Set<String>.from(favoriteOpeningIds);
    if (!next.add(id)) next.remove(id);
    setState(() => favoriteOpeningIds = next);
    AppSharedPreferences.set<List<String>>(
      AppSettingKeys.favoriteOpeningIds,
      next.toList(growable: false),
    );
  }

  void _launch(GameLaunchMode mode) {
    final opening = switch (startingPosition) {
      _OtbStartingPosition.standard => standardOpeningScenario,
      _OtbStartingPosition.opening => selectedOpening,
      _OtbStartingPosition.chess960 => _randomOtbChess960Opening(),
      _OtbStartingPosition.boardEditor => OpeningScenario(
          id: 'board-editor-fen',
          name: 'FEN position',
          eco: 'FEN',
          moves: 'Board editor',
          fen: boardEditorFen,
          focus: 'Custom position',
        ),
    };
    widget.onLaunchGame(
      mode,
      otbConfig: OtbGameConfig(
        timeMinutes: selectedTime.timeMinutes,
        incrementSeconds: selectedTime.incrementSeconds,
        opening: opening,
        startFen: opening.fen,
        chess960: startingPosition == _OtbStartingPosition.chess960,
        showPgnList: showPgnList,
      ),
    );
  }

  Future<void> _chooseOpening() async {
    final opening = await showDialog<OpeningScenario>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (_) => _OtbOpeningPickerDialog(
        selected: selectedOpening,
        favoriteOpeningIds: favoriteOpeningIds,
        onToggleFavorite: _toggleFavoriteOpening,
      ),
    );
    if (!mounted || opening == null) return;
    setState(() {
      selectedOpening = opening;
      startingPosition = _OtbStartingPosition.opening;
    });
    if (_remembersSetupSettings) {
      AppSharedPreferences.set(
        AppSettingKeys.otbStartingPosition,
        _OtbStartingPosition.opening.name,
      );
      AppSharedPreferences.set(AppSettingKeys.otbOpeningId, opening.id);
    }
  }

  Future<void> _showBoardEditor() async {
    final mediaSize = MediaQuery.sizeOf(context);
    final landscape = mediaSize.width > mediaSize.height &&
        mediaSize.height <= 620 &&
        mediaSize.width >= 700;
    final fen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      constraints:
          landscape ? BoxConstraints(maxWidth: mediaSize.width - 32) : null,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        BotBoardEditorSheet editor(ScrollController? scrollController) {
          return BotBoardEditorSheet(
            initialFen: boardEditorFen,
            boardGateway: widget.boardGateway,
            boardSettings: widget.boardSettings,
            isChessnutClockDevice: widget.isChessnutClockDevice,
            showBoardCoordinates: widget.showBoardCoordinates,
            hidePhysicalBoardConnectionUi: widget.hidePhysicalBoardConnectionUi,
            openInFenMode: false,
            scrollController: scrollController,
          );
        }

        if (landscape) return editor(null);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          minChildSize: 0.6,
          maxChildSize: 0.98,
          builder: (context, scrollController) => editor(scrollController),
        );
      },
    );
    if (!mounted || fen == null) return;
    setState(() {
      boardEditorFen = fen;
      startingPosition = _OtbStartingPosition.boardEditor;
    });
    if (_remembersSetupSettings) {
      AppSharedPreferences.set(
        AppSettingKeys.otbStartingPosition,
        _OtbStartingPosition.boardEditor.name,
      );
      AppSharedPreferences.set(AppSettingKeys.otbBoardEditorFen, fen);
    }
  }

  Future<void> _showCustomTimeDialog() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => _CustomTimeDialog(
        initial: selectedTime,
        onSave: (value) => _setTimeControl(value, custom: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final androidPhoneLandscape = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !widget.isChessnutClockDevice &&
        size.width > size.height &&
        size.width < 1000 &&
        size.height < 600;
    return ResponsivePage(
      preserveLayoutWhenKeyboardVisible: true,
      children: (context, spec) {
        final header = ScreenHeader(
          title: 'OTB setup',
          subtitle: 'Physical board game',
          leading: IconButton.filledTonal(
            onPressed: () => widget.onNavigate('Back'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        );
        final setupContent = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TimeControlCard(
              key: const ValueKey('otb-time-control-card'),
              options: timeOptions,
              selected: selectedTime,
              customSelected: customTimeSelected,
              onChanged: (value) => _setTimeControl(value, custom: false),
              onCustom: _showCustomTimeDialog,
            ),
            SizedBox(height: spec.gutter),
            _OtbStartingPositionCard(
              selected: startingPosition,
              selectedOpening: selectedOpening,
              onChanged: _setStartingPosition,
              onChooseOpening: _chooseOpening,
              onOpenBoardEditor: _showBoardEditor,
            ),
            SizedBox(height: spec.gutter),
            if (widget.isChessnutClockDevice)
              SwitchListTile.adaptive(
                key: const ValueKey('otb-show-pgn-list-toggle'),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Show PGN move list',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                subtitle: const Text(
                  'Keep the move list visible during OTB games.',
                ),
                value: showPgnList,
                onChanged: _setShowPgnList,
              ),
            if (widget.isChessnutClockDevice) SizedBox(height: spec.gutter),
            _OtbModeCards(
              spacing: spec.gutter,
              constrainStandaloneRecordCard: !widget.isChessnutClockDevice,
              record: _OtbModeData(
                icon: Icons.grid_on_rounded,
                title: 'Record Game',
                subtitle: 'Record a full OTB game with the board.',
                detail:
                    'The app tracks legal moves, keeps both clocks in sync, and saves a PGN you can review later.',
                badge: 'BOARD + PGN',
                onTap: () => _launch(GameLaunchMode.otb),
              ),
              clock: widget.isChessnutClockDevice
                  ? _OtbModeData(
                      icon: Icons.timer_rounded,
                      title: 'Chess Clock',
                      subtitle: 'Use the app as a standalone clock.',
                      detail:
                          'No PGN is recorded. Tap the active clock after each move, or use the physical switch when available.',
                      badge: 'CLOCK ONLY',
                      onTap: () => _launch(GameLaunchMode.clock),
                    )
                  : null,
            ),
          ],
        );
        if (androidPhoneLandscape) {
          return [
            SizedBox(
              height: spec.contentHeight,
              child: SingleChildScrollView(
                key: const ValueKey('otb-setup-scroll'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    SizedBox(height: spec.gutter),
                    setupContent,
                  ],
                ),
              ),
            ),
          ];
        }
        return [
          SizedBox(
            height: spec.contentHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                SizedBox(height: spec.gutter),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('otb-setup-scroll'),
                    child: setupContent,
                  ),
                ),
              ],
            ),
          ),
        ];
      },
    );
  }
}

enum _OtbStartingPosition { standard, opening, chess960, boardEditor }

class _OtbStartingPositionCard extends StatelessWidget {
  const _OtbStartingPositionCard({
    required this.selected,
    required this.selectedOpening,
    required this.onChanged,
    required this.onChooseOpening,
    required this.onOpenBoardEditor,
  });

  final _OtbStartingPosition selected;
  final OpeningScenario selectedOpening;
  final ValueChanged<_OtbStartingPosition> onChanged;
  final VoidCallback onChooseOpening;
  final VoidCallback onOpenBoardEditor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compactLandscape = isCompactLandscapeDevice(context);
    return GlassPanel(
      key: const ValueKey('otb-starting-position-card'),
      padding: EdgeInsets.all(compactLandscape ? 8 : 12),
      borderRadius: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!compactLandscape) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.flag_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Starting position',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: compactLandscape ? 16 : 17,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compactLandscape ? 6 : 9),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 680
                  ? 3
                  : constraints.maxWidth >= 300
                      ? 2
                      : 1;
              const spacing = 7.0;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  _OtbStartingPositionTile(
                    key: const ValueKey('otb-starting-standard'),
                    width: width,
                    label: 'Standard',
                    icon: Icons.grid_4x4_rounded,
                    selected: selected == _OtbStartingPosition.standard,
                    onTap: () => onChanged(_OtbStartingPosition.standard),
                    compact: compactLandscape,
                  ),
                  _OtbStartingPositionTile(
                    key: const ValueKey('otb-starting-opening'),
                    width: width,
                    label: 'Opening',
                    icon: Icons.route_rounded,
                    selected: selected == _OtbStartingPosition.opening,
                    onTap: () => onChanged(_OtbStartingPosition.opening),
                    compact: compactLandscape,
                  ),
                  _OtbStartingPositionTile(
                    key: const ValueKey('otb-starting-chess960'),
                    width: width,
                    label: 'Chess960',
                    icon: Icons.shuffle_rounded,
                    selected: selected == _OtbStartingPosition.chess960,
                    onTap: () => onChanged(_OtbStartingPosition.chess960),
                    compact: compactLandscape,
                  ),
                  _OtbStartingPositionTile(
                    key: const ValueKey('otb-starting-board-editor'),
                    width: width,
                    label: 'Board editor',
                    icon: Icons.dashboard_customize_rounded,
                    selected: selected == _OtbStartingPosition.boardEditor,
                    onTap: onOpenBoardEditor,
                    compact: compactLandscape,
                  ),
                ],
              );
            },
          ),
          if (selected == _OtbStartingPosition.opening) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(11, 9, 8, 9),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedOpening.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${selectedOpening.eco} - ${selectedOpening.moves}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    key: const ValueKey('otb-choose-opening'),
                    onPressed: onChooseOpening,
                    child: const Text('Choose'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OtbStartingPositionTile extends StatelessWidget {
  const _OtbStartingPositionTile({
    required this.width,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.compact,
    super.key,
  });

  final double width;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: BoxConstraints(minHeight: compact ? 42 : 54),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 11,
              vertical: compact ? 6 : 9,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: selected ? 0.14 : 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withValues(alpha: selected ? 0.48 : 0.12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: compact ? 19 : 21),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? color : null,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OtbOpeningPickerDialog extends StatefulWidget {
  const _OtbOpeningPickerDialog({
    required this.selected,
    required this.favoriteOpeningIds,
    required this.onToggleFavorite,
  });

  final OpeningScenario selected;
  final Set<String> favoriteOpeningIds;
  final ValueChanged<String> onToggleFavorite;

  @override
  State<_OtbOpeningPickerDialog> createState() =>
      _OtbOpeningPickerDialogState();
}

class _OtbOpeningPickerDialogState extends State<_OtbOpeningPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  late Set<String> _favoriteOpeningIds;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _favoriteOpeningIds = Set<String>.from(widget.favoriteOpeningIds);
  }

  void _toggleFavorite(String id) {
    setState(() {
      if (!_favoriteOpeningIds.add(id)) {
        _favoriteOpeningIds.remove(id);
      }
    });
    widget.onToggleFavorite(id);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final openings = botOpeningScenarios.where((scenario) {
      if (scenario.isStandard) return false;
      if (query.isEmpty) return true;
      return scenario.name.toLowerCase().contains(query) ||
          scenario.eco.toLowerCase().contains(query) ||
          scenario.moves.toLowerCase().contains(query) ||
          scenario.focus.toLowerCase().contains(query);
    }).toList(growable: false);
    final sortedOpenings = [
      ...openings.where((opening) => _favoriteOpeningIds.contains(opening.id)),
      ...openings.where((opening) => !_favoriteOpeningIds.contains(opening.id)),
    ];
    final favoriteOpenings = sortedOpenings
        .where((opening) => _favoriteOpeningIds.contains(opening.id))
        .toList(growable: false);
    final showFavoriteSection = query.isEmpty && favoriteOpenings.isNotEmpty;
    final compactLandscape = isCompactLandscapeDevice(context);
    final listHeight =
        (MediaQuery.sizeOf(context).height * (compactLandscape ? 0.36 : 0.48))
            .clamp(150.0, 390.0)
            .toDouble();
    return AppDialogShell(
      icon: Icons.route_rounded,
      title: 'Opening library',
      subtitle: compactLandscape ? null : 'Search classic training positions',
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
      ],
      child: SizedBox(
        height: listHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('otb-opening-search-field'),
              controller: _searchController,
              autofocus: !compactLandscape,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                labelText: 'Search opening',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            if (showFavoriteSection) ...[
              const SizedBox(height: 10),
              Text(
                'Favorites',
                key: const ValueKey('otb-opening-favorites-header'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final countText = Text(
                  '${openings.length} openings',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                );
                final hintText = Text(
                  'Tap one to use it',
                  style: Theme.of(context).textTheme.bodySmall,
                );
                if (constraints.maxWidth < 380) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [countText, const SizedBox(height: 2), hintText],
                  );
                }
                return Row(
                  children: [countText, const Spacer(), hintText],
                );
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: openings.isEmpty
                  ? Center(child: Text('No openings match "$_query"'))
                  : ListView.builder(
                      itemCount: showFavoriteSection
                          ? favoriteOpenings.length + sortedOpenings.length + 1
                          : sortedOpenings.length,
                      itemBuilder: (context, index) {
                        if (!showFavoriteSection) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: _buildOpeningTile(
                                context, sortedOpenings[index]),
                          );
                        }
                        if (index < favoriteOpenings.length) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: _buildOpeningTile(
                              context,
                              favoriteOpenings[index],
                              keyPrefix: 'otb-opening-favorite-result',
                            ),
                          );
                        }
                        if (index == favoriteOpenings.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 5, bottom: 8),
                            child: Text(
                              'All openings',
                              key: const ValueKey('otb-opening-all-header'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: _buildOpeningTile(
                            context,
                            sortedOpenings[index - favoriteOpenings.length - 1],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on _OtbOpeningPickerDialogState {
  Widget _buildOpeningTile(
    BuildContext context,
    OpeningScenario opening, {
    String keyPrefix = 'otb-opening',
  }) {
    final isSelected = opening.id == widget.selected.id;
    final isFavorite = _favoriteOpeningIds.contains(opening.id);
    final scheme = Theme.of(context).colorScheme;
    final accent = isSelected ? scheme.primary : scheme.secondary;
    return Material(
      key: ValueKey('$keyPrefix-${opening.id}'),
      color: isSelected
          ? accent.withValues(alpha: 0.10)
          : scheme.surface.withValues(alpha: 0.20),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).pop(opening),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.route_rounded,
                      color: accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _OtbOpeningTileTitle(
                      opening: opening,
                      selected: isSelected,
                      accent: accent,
                    ),
                  ),
                  IconButton(
                    key: ValueKey('otb-opening-favorite-${opening.id}'),
                    tooltip: isFavorite ? 'Remove favorite' : 'Add favorite',
                    onPressed: () => _toggleFavorite(opening.id),
                    icon: Icon(
                      isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: isFavorite ? scheme.tertiary : scheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${opening.eco} - ${opening.moves}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 5),
              Text(
                opening.focus,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtbOpeningTileTitle extends StatelessWidget {
  const _OtbOpeningTileTitle({
    required this.opening,
    required this.selected,
    required this.accent,
  });

  final OpeningScenario opening;
  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            opening.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: selected ? 0.14 : 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            opening.eco,
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

OpeningScenario _randomOtbChess960Opening({math.Random? random}) {
  final rng = random ?? math.Random();
  final pieces = List<String>.filled(8, '');
  const darkSquares = [0, 2, 4, 6];
  const lightSquares = [1, 3, 5, 7];
  pieces[darkSquares[rng.nextInt(darkSquares.length)]] = 'B';
  pieces[lightSquares[rng.nextInt(lightSquares.length)]] = 'B';

  List<int> emptyIndexes() => [
        for (var index = 0; index < pieces.length; index += 1)
          if (pieces[index].isEmpty) index,
      ];

  var empty = emptyIndexes();
  pieces[empty[rng.nextInt(empty.length)]] = 'Q';
  empty = emptyIndexes();
  pieces[empty.removeAt(rng.nextInt(empty.length))] = 'N';
  empty = emptyIndexes();
  pieces[empty[rng.nextInt(empty.length)]] = 'N';
  empty = emptyIndexes()..sort();
  pieces[empty[0]] = 'R';
  pieces[empty[1]] = 'K';
  pieces[empty[2]] = 'R';

  final whiteBackRank = pieces.join();
  final blackBackRank = whiteBackRank.toLowerCase();
  final queenSideRook = whiteBackRank.indexOf('R');
  final kingSideRook = whiteBackRank.lastIndexOf('R');
  const files = 'abcdefgh';
  final castlingRights = '${files[kingSideRook].toUpperCase()}'
      '${files[queenSideRook].toUpperCase()}'
      '${files[kingSideRook]}'
      '${files[queenSideRook]}';
  return OpeningScenario(
    id: 'chess960-$whiteBackRank',
    name: 'Chess960',
    eco: '960',
    moves: 'Randomized back rank $whiteBackRank',
    fen:
        '$blackBackRank/pppppppp/8/8/8/8/PPPPPPPP/$whiteBackRank w $castlingRights - 0 1',
    focus: 'Fischer random start',
  );
}

class _CustomTimeDialog extends StatefulWidget {
  const _CustomTimeDialog({
    required this.initial,
    required this.onSave,
  });

  final OtbGameConfig initial;
  final ValueChanged<OtbGameConfig> onSave;

  @override
  State<_CustomTimeDialog> createState() => _CustomTimeDialogState();
}

class _CustomTimeDialogState extends State<_CustomTimeDialog> {
  late double minutes;
  late double increment;

  @override
  void initState() {
    super.initState();
    minutes = widget.initial.timeMinutes.clamp(1, 180).toDouble();
    increment = widget.initial.incrementSeconds.clamp(0, 180).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      icon: Icons.timer_rounded,
      title: 'Custom time',
      subtitle: 'Set the OTB clock duration and increment.',
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: () {
              widget.onSave(
                OtbGameConfig(
                  timeMinutes: minutes.round(),
                  incrementSeconds: increment.round(),
                ),
              );
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ),
      ],
      child: Column(
        children: [
          _CustomTimeSlider(
            key: const ValueKey('otb-custom-minutes-control'),
            sliderKey: const ValueKey('otb-custom-minutes-slider'),
            icon: Icons.schedule_rounded,
            label: 'Minutes',
            valueLabel: '${minutes.round()} min',
            value: minutes,
            min: 1,
            max: 180,
            divisions: 179,
            onChanged: (value) => setState(() => minutes = value),
          ),
          const SizedBox(height: 12),
          _CustomTimeSlider(
            key: const ValueKey('otb-custom-increment-control'),
            sliderKey: const ValueKey('otb-custom-increment-slider'),
            icon: Icons.add_rounded,
            label: 'Increment',
            valueLabel: '${increment.round()} sec',
            value: increment,
            min: 0,
            max: 180,
            divisions: 180,
            onChanged: (value) => setState(() => increment = value),
          ),
          const SizedBox(height: 8),
          Text(
            'Drag to set the base time and the seconds added after each move.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CustomTimeSlider extends StatelessWidget {
  const _CustomTimeSlider({
    required this.sliderKey,
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    super.key,
  });

  final Key sliderKey;
  final IconData icon;
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                valueLabel,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            key: sliderKey,
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _TimeControlCard extends StatelessWidget {
  const _TimeControlCard({
    required this.options,
    required this.selected,
    required this.customSelected,
    required this.onChanged,
    required this.onCustom,
    super.key,
  });

  final List<OtbGameConfig> options;
  final OtbGameConfig selected;
  final bool customSelected;
  final ValueChanged<OtbGameConfig> onChanged;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final compactLandscape = isCompactLandscapeDevice(context);
    final selectedPreset = options.any(
      (option) =>
          option.timeMinutes == selected.timeMinutes &&
          option.incrementSeconds == selected.incrementSeconds &&
          !customSelected,
    );
    return GlassPanel(
      padding: const EdgeInsets.all(10),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Time control',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(_speedForTime(
                      selected.timeMinutes,
                      selected.incrementSeconds,
                    )),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: onCustom,
                icon: const Icon(Icons.tune_rounded, size: 17),
                label: const Text('Custom'),
              ),
            ],
          ),
          SizedBox(height: compactLandscape ? 7 : 9),
          LayoutBuilder(
            builder: (context, constraints) {
              final spacing = compactLandscape ? 6.0 : 7.0;
              final columns = constraints.maxWidth < 520 ? 4 : 6;
              final chipWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                key: const ValueKey('otb-time-control-scroll'),
                spacing: spacing,
                runSpacing: compactLandscape ? 6 : 7,
                children: [
                  for (final option in options)
                    _TimeChip(
                      label: option.timeLabel,
                      selected: selectedPreset &&
                          option.timeMinutes == selected.timeMinutes &&
                          option.incrementSeconds == selected.incrementSeconds,
                      width: chipWidth,
                      onTap: () => onChanged(option),
                    ),
                  if (customSelected)
                    _TimeChip(
                      label: 'Custom ${selected.timeLabel}',
                      selected: true,
                      width: chipWidth * 2 + spacing,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.selected,
    required this.width,
    this.onTap,
  });

  final String label;
  final bool selected;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondary;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: width,
        constraints: const BoxConstraints(
          minHeight: 42,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: color.withValues(alpha: selected ? 0.44 : 0.16)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _OtbModeCards extends StatelessWidget {
  const _OtbModeCards({
    required this.spacing,
    required this.constrainStandaloneRecordCard,
    required this.record,
    this.clock,
  });

  final double spacing;
  final bool constrainStandaloneRecordCard;
  final _OtbModeData record;
  final _OtbModeData? clock;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final flatCards = width >= 820;
        final compactCards = width < 700 ||
            (constraints.maxHeight.isFinite && constraints.maxHeight < 300);
        final cardHeight = constraints.maxHeight.isFinite
            ? ((constraints.maxHeight - spacing) / 2).clamp(132.0, 260.0)
            : width < 700
                ? 120.0
                : 200.0;
        final useCompactCardLayout = compactCards;
        final recordCard = _OtbModeCard(
          key: const ValueKey('otb-record-mode-card'),
          data: record,
          selected: true,
          compact: useCompactCardLayout,
          flat: flatCards,
        );
        final clockCard = clock == null
            ? null
            : _OtbModeCard(
                key: const ValueKey('otb-clock-mode-card'),
                data: clock!,
                compact: useCompactCardLayout,
                flat: flatCards,
              );
        if (width >= 820) {
          if (clockCard == null) {
            if (constrainStandaloneRecordCard) {
              return Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: math.min(width, 720),
                  height: 142,
                  child: recordCard,
                ),
              );
            }
            return SizedBox(
              height: flatCards ? 62 : 142,
              child: recordCard,
            );
          }
          return SizedBox(
            height: flatCards ? 62 : 142,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 6, child: recordCard),
                SizedBox(width: spacing),
                Expanded(flex: 5, child: clockCard),
              ],
            ),
          );
        }
        if (clockCard == null) {
          return SizedBox(
            height: width >= 820 ? (flatCards ? 62 : 142) : cardHeight,
            child: recordCard,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: cardHeight,
              child: recordCard,
            ),
            SizedBox(height: spacing),
            SizedBox(
              height: cardHeight,
              child: clockCard,
            ),
          ],
        );
      },
    );
  }
}

class _OtbModeData {
  const _OtbModeData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String detail;
  final String badge;
  final VoidCallback onTap;
}

class _OtbModeCard extends StatelessWidget {
  const _OtbModeCard({
    super.key,
    required this.data,
    required this.compact,
    required this.flat,
    this.selected = false,
  });

  final _OtbModeData data;
  final bool compact;
  final bool flat;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.secondary;
    final phoneCompact = compact && !flat;
    final iconSize = phoneCompact ? 36.0 : 50.0;
    final buttonLabel =
        data.title == 'Record Game' ? 'Start recording' : 'Open clock';
    return GlassPanel(
      onTap: data.onTap,
      padding:
          phoneCompact ? const EdgeInsets.all(10) : const EdgeInsets.all(14),
      borderRadius: 16,
      tint: color.withValues(alpha: selected ? 0.09 : 0.05),
      child: flat
          ? Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(data.icon, color: color, size: 18),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              data.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            data.badge,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w900,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: data.onTap,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: Text(buttonLabel),
                ),
              ],
            )
          : phoneCompact
              ? Row(
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(data.icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data.badge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            data.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data.detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      height: 1.1,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: data.onTap,
                      tooltip: buttonLabel,
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: iconSize,
                          height: iconSize,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius:
                                BorderRadius.circular(phoneCompact ? 11 : 14),
                          ),
                          child: Icon(data.icon,
                              color: color, size: phoneCompact ? 22 : null),
                        ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: phoneCompact ? 9 : 10,
                              vertical: phoneCompact ? 6 : 7),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            data.badge,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w900,
                              fontSize: phoneCompact ? 10 : 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: phoneCompact ? 8 : 16),
                    Text(
                      data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      data.subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: data.onTap,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(buttonLabel),
                    ),
                  ],
                ),
    );
  }
}

String _speedForTime(int minutes, int increment) {
  if (minutes <= 0) return 'Casual';
  final estimatedSeconds = minutes * 60 + increment * 40;
  if (estimatedSeconds < 3 * 60) return 'Bullet';
  if (estimatedSeconds < 8 * 60) return 'Blitz';
  if (estimatedSeconds < 25 * 60) return 'Rapid';
  return 'Classical';
}
