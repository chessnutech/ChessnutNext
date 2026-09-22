import 'dart:async';

import 'package:flutter/material.dart' as material;
import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_language.dart';
import '../l10n/app_strings.dart';
import '../l10n/localized_material.dart';
import '../services/app_sound_service.dart';
import '../services/app_update_service.dart';
import '../services/board_settings_service.dart';
import '../services/evo2_display_service.dart';
import '../services/chessnut_api_client.dart';
import '../services/module_guide_service.dart';
import '../theme/chessnut_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_feedback.dart';

const _maia3SourceUrl = 'https://github.com/chessnutech/chessnut-maia3-service';
const _hiddenReplayModuleGuideIds = {'online_match_room'};
const _openSourceNoticeItems = [
  _OpenSourceNoticeItem(
    name: 'Stockfish',
    license: 'GNU GPL v3',
    sourceUrl: 'https://github.com/official-stockfish/Stockfish',
    note: 'Chess engine used for evaluation, hints, bots, and analysis.',
  ),
  _OpenSourceNoticeItem(
    name: 'Leela Chess Zero / lc0',
    license: 'GNU GPL v3',
    sourceUrl: 'https://github.com/LeelaChessZero/lc0',
    note: 'Neural-network chess engine used for LC0 and Maia-compatible play.',
  ),
  _OpenSourceNoticeItem(
    name: 'dartchess',
    license: 'GNU GPL v3',
    sourceUrl: 'https://github.com/lichess-org/dartchess',
    note: 'Chess rules, move generation, FEN, and PGN handling.',
  ),
  _OpenSourceNoticeItem(
    name: 'flutter-chessground',
    license: 'GNU GPL v3',
    sourceUrl: 'https://github.com/lichess-org/flutter-chessground',
    note: 'Chess board UI used by the virtual board.',
  ),
  _OpenSourceNoticeItem(
    name: 'Maia 1 weights',
    license: 'See Maia Chess project notices',
    sourceUrl: 'https://github.com/CSSLab/maia-chess',
    note: 'Human-like chess model weights for Maia bot play.',
  ),
  _OpenSourceNoticeItem(
    name: 'Maia 3 inference service',
    license: 'GNU AGPL-3.0',
    sourceUrl: _maia3SourceUrl,
    note:
        'Independent cloud service for Maia 3 bot moves and human review. The service source is published separately.',
  ),
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.onNavigate,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.visualTheme,
    required this.onVisualThemeChanged,
    required this.pageAnimations,
    required this.onPageAnimationsChanged,
    this.hidePageAnimationsSetting = false,
    this.isChessnutEvo2Device = false,
    this.evo2ScreenOrientation = Evo2ScreenOrientation.rotation0,
    this.onEvo2ScreenOrientationChanged,
    required this.boardCoordinatesEnabled,
    required this.onBoardCoordinatesChanged,
    required this.keepBoardConnectedInBackground,
    required this.onKeepBoardConnectedInBackgroundChanged,
    required this.soundEffectsEnabled,
    required this.onSoundEffectsChanged,
    required this.moveAnnouncementEnabled,
    required this.onMoveAnnouncementChanged,
    this.visionRecognitionOnly = false,
    this.onVisionRecognitionOnlyChanged,
    this.soundEffects = const SoundEffectsSettings(),
    this.onSoundEffectsSettingsChanged,
    this.boardSettings = const BoardSettingsState(),
    this.onBoardSettingsChanged,
    required this.languagePreference,
    required this.onLanguagePreferenceChanged,
    required this.apiClient,
    required this.bugReportDiagnosticsBuilder,
    this.onCheckForUpdates,
    this.moduleGuides = const [],
    this.onReplayModuleGuide,
    this.onResetModuleGuides,
    this.hidePhysicalBoardConnectionUi = false,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ChessnutVisualTheme visualTheme;
  final ValueChanged<ChessnutVisualTheme> onVisualThemeChanged;
  final bool pageAnimations;
  final ValueChanged<bool> onPageAnimationsChanged;
  final bool hidePageAnimationsSetting;
  final bool isChessnutEvo2Device;
  final Evo2ScreenOrientation evo2ScreenOrientation;
  final ValueChanged<Evo2ScreenOrientation>? onEvo2ScreenOrientationChanged;
  final bool boardCoordinatesEnabled;
  final ValueChanged<bool> onBoardCoordinatesChanged;
  final bool keepBoardConnectedInBackground;
  final ValueChanged<bool> onKeepBoardConnectedInBackgroundChanged;
  final bool soundEffectsEnabled;
  final ValueChanged<bool> onSoundEffectsChanged;
  final bool moveAnnouncementEnabled;
  final ValueChanged<bool> onMoveAnnouncementChanged;
  final bool visionRecognitionOnly;
  final ValueChanged<bool>? onVisionRecognitionOnlyChanged;
  final SoundEffectsSettings soundEffects;
  final ValueChanged<SoundEffectsSettings>? onSoundEffectsSettingsChanged;
  final BoardSettingsState boardSettings;
  final ValueChanged<BoardSettingsState>? onBoardSettingsChanged;
  final AppLanguagePreference languagePreference;
  final ValueChanged<AppLanguagePreference> onLanguagePreferenceChanged;
  final ChessnutApiClient apiClient;
  final FutureOr<BugReportDiagnostics> Function() bugReportDiagnosticsBuilder;
  final Future<void> Function()? onCheckForUpdates;
  final List<ModuleGuideDefinition> moduleGuides;
  final ValueChanged<ModuleGuideDefinition>? onReplayModuleGuide;
  final VoidCallback? onResetModuleGuides;
  final bool hidePhysicalBoardConnectionUi;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? installedAppVersion;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInstalledAppVersion());
  }

  Future<void> _loadInstalledAppVersion() async {
    final installed = await AppUpdateService.readInstalledVersion();
    if (!mounted) return;
    setState(() => installedAppVersion = installed.version);
  }

  Future<void> _showBugReport() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _BugReportDialog(
        apiClient: widget.apiClient,
        diagnosticsBuilder: widget.bugReportDiagnosticsBuilder,
      ),
    );
  }

  Future<void> _showOpenSourceNotices() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => const _OpenSourceNoticesDialog(),
    );
  }

  List<ModuleGuideDefinition> get _replayableModuleGuides {
    return widget.moduleGuides
        .where((guide) => !_hiddenReplayModuleGuideIds.contains(guide.id))
        .toList(growable: false);
  }

  Future<void> _showModuleGuidePicker() async {
    final guides = _replayableModuleGuides;
    if (guides.isEmpty) return;
    final selected = await showDialog<ModuleGuideDefinition>(
      context: context,
      builder: (dialogContext) => _ModuleGuidePickerDialog(
        guides: guides,
        onReset: widget.onResetModuleGuides == null
            ? null
            : () {
                widget.onResetModuleGuides?.call();
                Navigator.of(dialogContext).pop();
              },
      ),
    );
    if (selected == null || !mounted) return;
    widget.onReplayModuleGuide?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final replayableModuleGuides = _replayableModuleGuides;
    return ResponsivePage(
      children: (context, spec) => [
        ScreenHeader(
          title: 'Settings',
          subtitle: 'App',
          leading: IconButton.filledTonal(
            onPressed: () => widget.onNavigate('Back'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        SizedBox(height: spec.gutter),
        ResponsiveSplit(
          breakpoint: 880,
          spacing: spec.gutter,
          leadingFlex: 6,
          trailingFlex: 5,
          leading: SectionColumn(
            spacing: 12,
            children: [
              _SettingsSection(
                title: 'Interface',
                status: strings.t(_themeModeLabel(widget.themeMode)),
                children: [
                  _OptionRow(
                    key: const ValueKey('settings-language-row'),
                    label: 'Language',
                    child: DropdownButtonFormField<AppLanguagePreference>(
                      initialValue: widget.languagePreference,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: AppLanguagePreference.values
                          .map(
                            (item) => DropdownMenuItem<AppLanguagePreference>(
                              value: item,
                              child: material.Text(
                                item == AppLanguagePreference.system
                                    ? strings.systemLanguageLabel()
                                    : item.nativeLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          widget.onLanguagePreferenceChanged(value);
                        }
                      },
                    ),
                  ),
                  if (widget.isChessnutEvo2Device)
                    _OptionRow(
                      key: const ValueKey('settings-evo2-orientation-row'),
                      label: 'Screen orientation',
                      child: DropdownButtonFormField<Evo2ScreenOrientation>(
                        key: const ValueKey(
                          'settings-evo2-orientation-dropdown',
                        ),
                        initialValue: widget.evo2ScreenOrientation,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: Evo2ScreenOrientation.values
                            .map(
                              (orientation) => DropdownMenuItem(
                                value: orientation,
                                child: material.Text(orientation.label),
                              ),
                            )
                            .toList(),
                        onChanged: (orientation) {
                          if (orientation != null) {
                            widget.onEvo2ScreenOrientationChanged
                                ?.call(orientation);
                          }
                        },
                      ),
                    ),
                  _OptionRow(
                    label: 'Theme',
                    child: _VisualThemePills(
                      selected: widget.visualTheme,
                      onSelected: widget.onVisualThemeChanged,
                    ),
                  ),
                  _OptionRow(
                    label: 'Mode',
                    child: _ThemeModePills(
                      selected: widget.themeMode,
                      onSelected: widget.onThemeModeChanged,
                    ),
                  ),
                  if (!widget.hidePageAnimationsSetting) ...[
                    _SettingSwitchRow(
                      label: 'Visual effects',
                      value: widget.pageAnimations,
                      onChanged: widget.onPageAnimationsChanged,
                    ),
                    AnimatedSwitcher(
                      duration: widget.pageAnimations
                          ? const Duration(milliseconds: 220)
                          : Duration.zero,
                      child: _ThemePreview(
                        key: ValueKey(widget.visualTheme),
                        visualTheme: widget.visualTheme,
                      ),
                    ),
                  ],
                ],
              ),
              _SettingsSection(
                key: const ValueKey('settings-general-section'),
                title: 'General',
                children: [
                  _SettingSwitchRow(
                    label: 'Board coordinates',
                    subtitle: 'Show files and ranks on virtual boards',
                    value: widget.boardCoordinatesEnabled,
                    onChanged: widget.onBoardCoordinatesChanged,
                  ),
                  if (!kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.android &&
                      widget.onVisionRecognitionOnlyChanged != null)
                    _SettingSwitchRow(
                      key: const ValueKey(
                        'settings-vision-recognition-only-switch',
                      ),
                      label: 'Vision recognition only',
                      subtitle:
                          'Recognize and guide the physical board without simulating taps on the screen',
                      value: widget.visionRecognitionOnly,
                      onChanged: widget.onVisionRecognitionOnlyChanged!,
                    ),
                  if ((kIsWeb ||
                          (defaultTargetPlatform != TargetPlatform.windows &&
                              defaultTargetPlatform != TargetPlatform.macOS)) &&
                      (!widget.hidePhysicalBoardConnectionUi ||
                          widget.isChessnutEvo2Device))
                    _SettingSwitchRow(
                      label: 'Keep playing while screen is off',
                      subtitle:
                          'When enabled, active games continue while the screen is off. When disabled, screen-off play stops and the board LEDs turn off.',
                      value: widget.keepBoardConnectedInBackground,
                      onChanged: widget.onKeepBoardConnectedInBackgroundChanged,
                    ),
                  _SettingSwitchRow(
                    label: 'Sound effects',
                    subtitle: 'Master switch for all app sounds',
                    value: widget.soundEffectsEnabled,
                    onChanged: widget.onSoundEffectsChanged,
                  ),
                  if (widget.soundEffectsEnabled)
                    Column(
                      children: [
                        _SettingSwitchRow(
                          label: 'From/to voice',
                          subtitle:
                              'Speak opponent move squares, such as e7 to e5',
                          value: widget.soundEffects.fromTo,
                          onChanged: (value) =>
                              widget.onSoundEffectsSettingsChanged?.call(
                            widget.soundEffects.copyWith(fromTo: value),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _SettingSwitchRow(
                          label: 'Move sounds',
                          subtitle: 'Play move, capture, and check effects',
                          value: widget.soundEffects.move,
                          onChanged: (value) =>
                              widget.onSoundEffectsSettingsChanged?.call(
                            widget.soundEffects.copyWith(move: value),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _SettingSwitchRow(
                          label: 'Result sounds',
                          subtitle: 'Play victory, defeat, and draw sounds',
                          value: widget.soundEffects.result,
                          onChanged: (value) =>
                              widget.onSoundEffectsSettingsChanged?.call(
                            widget.soundEffects.copyWith(result: value),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _SettingSwitchRow(
                          label: 'Key action sounds',
                          subtitle: 'Play game start, hint, and confirm sounds',
                          value: widget.soundEffects.keyAction,
                          onChanged: (value) =>
                              widget.onSoundEffectsSettingsChanged?.call(
                            widget.soundEffects.copyWith(keyAction: value),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
          trailing: SectionColumn(
            spacing: 12,
            children: [
              GlassPanel(
                padding: EdgeInsets.zero,
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline_rounded),
                        title: const Text('Account'),
                        subtitle: const Text('Profile, security, data'),
                        onTap: () => widget.onNavigate('Account'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.grid_4x4_rounded),
                        title: const Text('Board settings'),
                        subtitle: const Text('Pairing, LED, move sync'),
                        onTap: () => widget.onNavigate('BoardSettings'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        key: const ValueKey('settings-bug-report-tile'),
                        leading: const Icon(Icons.bug_report_rounded),
                        title: const Text('Report a bug'),
                        subtitle:
                            const Text('Send logs, screenshots, or video'),
                        onTap: _showBugReport,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        key: const ValueKey(
                          'settings-open-source-notices-tile',
                        ),
                        leading: const Icon(Icons.source_rounded),
                        title: const Text('Open-source notices'),
                        subtitle: const Text('Licenses and Maia 3 source code'),
                        onTap: _showOpenSourceNotices,
                      ),
                      if (replayableModuleGuides.isNotEmpty &&
                          widget.onReplayModuleGuide != null) ...[
                        const Divider(height: 1),
                        ListTile(
                          key: const ValueKey('settings-replay-guides-tile'),
                          leading: const Icon(Icons.tips_and_updates_rounded),
                          title: const Text('Replay guides'),
                          subtitle: const Text('View first-time tips again'),
                          onTap: _showModuleGuidePicker,
                        ),
                      ],
                      const Divider(height: 1),
                      ListTile(
                        key: const ValueKey('settings-check-updates-tile'),
                        leading: const Icon(Icons.system_update_alt_rounded),
                        title: Text(strings.t('Check for updates')),
                        subtitle: Text(
                          strings.t(
                            'Check whether a newer Chessnut version is available.',
                          ),
                        ),
                        onTap: widget.onCheckForUpdates,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.info_outline_rounded),
                        title: const Text('Version'),
                        subtitle: Text(_settingsVersionLabel()),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  String _settingsVersionLabel() {
    final version = installedAppVersion?.trim() ?? '';
    return version.isEmpty ? 'Chessnut Next' : 'Chessnut Next $version';
  }
}

class _OpenSourceNoticesDialog extends StatelessWidget {
  const _OpenSourceNoticesDialog();

  Future<void> _openSourceUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      showAppFeedback(
        context,
        'Could not open the source link. Please try again later.',
        tone: AppFeedbackTone.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: 560, maxHeight: size.height * 0.8),
        child: GlassPanel(
          borderRadius: 18,
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.source_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Open-source notices',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Chessnut uses open-source chess engines and libraries. '
                  'The package includes license notices, and corresponding '
                  'source links are listed below.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final item in _openSourceNoticeItems) ...[
                  _OpenSourceNoticeTile(
                    item: item,
                    onOpen: () => _openSourceUrl(context, item.sourceUrl),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModuleGuidePickerDialog extends StatelessWidget {
  const _ModuleGuidePickerDialog({
    required this.guides,
    this.onReset,
  });

  final List<ModuleGuideDefinition> guides;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compactLandscape = isCompactLandscapeDevice(context);
    return Dialog(
      key: const ValueKey('module-guide-picker'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: compactLandscape ? 720 : 480,
          maxHeight: size.height * 0.82,
        ),
        child: GlassPanel(
          borderRadius: 18,
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tips_and_updates_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Replay guides',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a module to view its first-time guide again.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 560;
                    final tileWidth = twoColumns
                        ? (constraints.maxWidth - 10) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final guide in guides)
                          SizedBox(
                            width: tileWidth,
                            child: _ModuleGuidePickerTile(guide: guide),
                          ),
                      ],
                    );
                  },
                ),
                if (onReset != null) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Show all guides next time'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModuleGuidePickerTile extends StatelessWidget {
  const _ModuleGuidePickerTile({required this.guide});

  final ModuleGuideDefinition guide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('module-guide-pick-${guide.id}'),
        onTap: () => Navigator.of(context).pop(guide),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(guide.icon, color: scheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guide.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      guide.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenSourceNoticeItem {
  const _OpenSourceNoticeItem({
    required this.name,
    required this.license,
    required this.sourceUrl,
    required this.note,
  });

  final String name;
  final String license;
  final String sourceUrl;
  final String note;
}

class _OpenSourceNoticeTile extends StatelessWidget {
  const _OpenSourceNoticeTile({required this.item, required this.onOpen});

  final _OpenSourceNoticeItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  item.license,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(item.note, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          material.Text(
            item.sourceUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open source code'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BugReportDialog extends StatefulWidget {
  const _BugReportDialog({
    required this.apiClient,
    required this.diagnosticsBuilder,
  });

  final ChessnutApiClient apiClient;
  final FutureOr<BugReportDiagnostics> Function() diagnosticsBuilder;

  @override
  State<_BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<_BugReportDialog> {
  final descriptionController = TextEditingController();
  final contactController = TextEditingController();
  final attachments = <BugReportAttachment>[];
  bool includeLogs = true;
  bool sending = false;
  String? errorText;

  @override
  void dispose() {
    descriptionController.dispose();
    contactController.dispose();
    super.dispose();
  }

  Future<void> _addAttachments() async {
    // iOS requires Uniform Type Identifiers. macOS accepts extensions, but
    // passing both keeps the same filter working on both Apple platforms.
    final files = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Screenshots and videos',
          extensions: ['png', 'jpg', 'jpeg', 'webp', 'mp4', 'mov', 'heic'],
          uniformTypeIdentifiers: [
            'public.png',
            'public.jpeg',
            'org.webmproject.webp',
            'public.mpeg-4',
            'com.apple.quicktime-movie',
            'public.heic',
          ],
        ),
      ],
    );
    if (files.isEmpty) return;
    final next = <BugReportAttachment>[];
    final remainingSlots = 4 - attachments.length;
    if (remainingSlots <= 0) return;
    for (final file in files.take(remainingSlots)) {
      final bytes = await file.readAsBytes();
      if (bytes.length > 25 * 1024 * 1024) continue;
      next.add(
        BugReportAttachment(
          filename: file.name,
          bytes: bytes,
          contentType: _contentTypeFor(file.name),
        ),
      );
    }
    if (!mounted) return;
    setState(() => attachments.addAll(next));
  }

  Future<void> _submit() async {
    final description = descriptionController.text.trim();
    if (description.length < 10) {
      setState(() => errorText = 'Tell us what happened in a little detail.');
      return;
    }

    setState(() {
      sending = true;
      errorText = null;
    });

    final diagnostics = await widget.diagnosticsBuilder();
    final result = await widget.apiClient.submitBugReport(
      description: description,
      contact: contactController.text.trim(),
      diagnostics: includeLogs
          ? diagnostics
          : BugReportDiagnostics(
              appVersion: diagnostics.appVersion,
              appBuildNumber: diagnostics.appBuildNumber,
              platform: diagnostics.platform,
              locale: diagnostics.locale,
              route: diagnostics.route,
              boardModel: diagnostics.boardModel,
              boardConnected: diagnostics.boardConnected,
              signedIn: diagnostics.signedIn,
              log: '',
              generatedAt: diagnostics.generatedAt,
              deviceManufacturer: '',
              deviceModel: '',
              osVersion: '',
              osSdk: 0,
            ),
      attachments: attachments,
    );

    if (!mounted) return;
    setState(() => sending = false);
    if (!result.isSuccess) {
      setState(() {
        errorText = result.status.errorMessage ??
            'Could not send the report. Please try again.';
      });
      return;
    }

    showAppFeedback(
      context,
      'Bug report sent. Thank you for helping us fix it.',
      tone: AppFeedbackTone.success,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 720;
    final maxWidth = wide ? 720.0 : size.width - 24;
    final maxHeight = size.height * 0.86;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: GlassPanel(
          borderRadius: 18,
          padding: const EdgeInsets.all(14),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bug_report_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Report a bug',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed:
                          sending ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Describe the issue and attach anything that helps us reproduce it. App logs and device details are included by default.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('bug-report-description'),
                  controller: descriptionController,
                  minLines: 5,
                  maxLines: 8,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'What went wrong?',
                    hintText:
                        'Example: Air+ connected, then bot game showed an illegal move warning after ...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contactController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Contact email or order info (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: includeLogs,
                  onChanged: sending
                      ? null
                      : (value) => setState(() => includeLogs = value),
                  title: const Text('Include app logs and device details'),
                  subtitle: const Text(
                    'Includes app version, device type, current screen, board status, and recent logs.',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('bug-report-add-attachment'),
                  onPressed: sending ? null : _addAttachments,
                  icon: const Icon(Icons.attach_file_rounded),
                  label: Text(
                    attachments.isEmpty
                        ? 'Add screenshot or video'
                        : 'Add more files (${attachments.length}/4)',
                  ),
                ),
                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final attachment in attachments)
                        InputChip(
                          label: Text(attachment.filename),
                          onDeleted: sending
                              ? null
                              : () => setState(
                                    () => attachments.remove(attachment),
                                  ),
                        ),
                    ],
                  ),
                ],
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorText!,
                    style: TextStyle(
                      color: ChessnutTheme.tokensOf(context).danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            sending ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('bug-report-submit'),
                        onPressed: sending ? null : _submit,
                        icon: sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(sending ? 'Sending' : 'Send report'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _contentTypeFor(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.mov')) return 'video/quicktime';
  return 'application/octet-stream';
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    this.status,
    required this.children,
    super.key,
  });

  final String title;
  final String? status;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(10),
      borderRadius: 13,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (status?.trim().isNotEmpty ?? false)
                Text(
                  status!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.child,
    super.key,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}

class _SettingSwitchRow extends StatelessWidget {
  const _SettingSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = ChessnutTheme.tokensOf(context);
    final color = value
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondary;
    final strings = AppStrings.maybeOf(context);
    final localizedLabel = strings?.t(label) ?? label;
    final localizedSubtitle =
        subtitle == null ? null : strings?.t(subtitle!) ?? subtitle!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: BoxConstraints(minHeight: tokens.touchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: value ? 0.10 : 0.06),
          borderRadius: BorderRadius.circular(tokens.controlRadius),
          border: Border.all(
            color: color.withValues(alpha: value ? 0.30 : 0.12),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(localizedLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (localizedSubtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      localizedSubtitle,
                      maxLines: 3,
                      overflow: TextOverflow.visible,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withValues(alpha: 0.65),
                          ),
                    ),
                  ],
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _ThemeModePills extends StatelessWidget {
  const _ThemeModePills({
    required this.selected,
    required this.onSelected,
  });

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PillButton(
            label: 'Light',
            selected: selected == ThemeMode.light,
            onTap: () => onSelected(ThemeMode.light),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _PillButton(
            label: 'Dark',
            selected: selected == ThemeMode.dark,
            onTap: () => onSelected(ThemeMode.dark),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _PillButton(
            label: 'System',
            selected: selected == ThemeMode.system,
            onTap: () => onSelected(ThemeMode.system),
          ),
        ),
      ],
    );
  }
}

class _VisualThemePills extends StatelessWidget {
  const _VisualThemePills({
    required this.selected,
    required this.onSelected,
  });

  final ChessnutVisualTheme selected;
  final ValueChanged<ChessnutVisualTheme> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PillButton(
            label: 'Modern',
            selected: selected == ChessnutVisualTheme.modern,
            onTap: () => onSelected(ChessnutVisualTheme.modern),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PillButton(
            label: 'Classic',
            selected: selected == ChessnutVisualTheme.classic,
            onTap: () => onSelected(ChessnutVisualTheme.classic),
          ),
        ),
      ],
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.visualTheme, super.key});

  final ChessnutVisualTheme visualTheme;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final classic = visualTheme == ChessnutVisualTheme.classic;
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: classic ? 10 : 14,
      tint: scheme.primary.withValues(alpha: classic ? 0.07 : 0.05),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(classic ? 8 : 12),
              color: scheme.primary.withValues(alpha: 0.14),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.30)),
            ),
            child: Icon(
              classic ? Icons.history_edu_rounded : Icons.auto_awesome_rounded,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classic ? 'Classic chess club' : 'Modern motion',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  classic
                      ? 'Higher contrast, calmer motion, larger touch targets.'
                      : 'Visual effects improve motion and polish, but can feel slower on older devices.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ChessnutTheme.tokensOf(context);
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondary;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: BoxConstraints(minHeight: tokens.touchTarget),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.16 : 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: color.withValues(alpha: selected ? 0.44 : 0.12)),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.visible,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? color : null,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
