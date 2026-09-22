import '../l10n/localized_material.dart';
import '../l10n/app_strings.dart';
import '../services/chessnut_api_client.dart'
    show networkConnectionErrorMessage;

import '../theme/chessnut_theme.dart';
import 'app_chrome.dart';
import 'chessnut_motion.dart';

enum AppFeedbackTone {
  info,
  success,
  warning,
  error,
}

// MaterialApp owns one messenger across routes and account/theme changes.
// Keep this in memory, scoped to that app instance, so a new launch can notify
// again without retaining disposed messengers or suppressing other errors.
final _networkErrorShown = Expando<bool>('network-error-shown');

Future<bool> confirmMoveBoardPieceMovement(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (dialogContext) => AppDialogShell(
      icon: Icons.precision_manufacturing_rounded,
      title: 'Are you sure?',
      subtitle:
          "This action will initiate the pieces' movement and cannot be interrupted once started.",
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

void showAppFeedback(
  BuildContext context,
  String message, {
  AppFeedbackTone tone = AppFeedbackTone.info,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.of(context);
  final localizedNetworkError =
      AppStrings.maybeOf(context)?.t(networkConnectionErrorMessage);
  if (message == networkConnectionErrorMessage ||
      message == localizedNetworkError) {
    if (_networkErrorShown[messenger] == true) return;
    // Mark before showing to coalesce concurrent API and page-level failures.
    _networkErrorShown[messenger] = true;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.zero,
        duration: duration,
        showCloseIcon: true,
        closeIconColor: _foregroundFor(context, tone),
        margin: EdgeInsets.fromLTRB(
          14,
          0,
          14,
          MediaQuery.paddingOf(context).bottom + 14,
        ),
        content: ChessnutFadeSlide(
          offsetY: 0.08,
          child: _AppFeedbackContent(message: message, tone: tone),
        ),
      ),
    );
}

class _AppFeedbackContent extends StatelessWidget {
  const _AppFeedbackContent({
    required this.message,
    required this.tone,
  });

  final String message;
  final AppFeedbackTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = ChessnutTheme.tokensOf(context);
    final toneColor = _toneColor(tokens, tone);
    final foreground = _foregroundFor(context, tone);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final localizedMessage = AppStrings.maybeOf(context)?.t(message) ?? message;
    final fill = Color.alphaBlend(
      toneColor.withValues(alpha: dark ? 0.14 : 0.09),
      tokens.panelFill,
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(tokens.controlRadius),
        border: Border.all(color: toneColor.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.30 : 0.12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(width: 4, color: toneColor),
          const SizedBox(width: 12),
          ChessnutPulseBadge(
            active: tone != AppFeedbackTone.info,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: toneColor.withValues(alpha: dark ? 0.18 : 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_toneIcon(tone), color: toneColor, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                localizedMessage,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                      height: 1.22,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 42),
        ],
      ),
    );
  }
}

Color _toneColor(ChessnutThemeTokens tokens, AppFeedbackTone tone) {
  return switch (tone) {
    AppFeedbackTone.info => tokens.info,
    AppFeedbackTone.success => tokens.success,
    AppFeedbackTone.warning => tokens.warning,
    AppFeedbackTone.error => tokens.danger,
  };
}

IconData _toneIcon(AppFeedbackTone tone) {
  return switch (tone) {
    AppFeedbackTone.info => Icons.info_outline_rounded,
    AppFeedbackTone.success => Icons.check_circle_outline_rounded,
    AppFeedbackTone.warning => Icons.warning_amber_rounded,
    AppFeedbackTone.error => Icons.error_outline_rounded,
  };
}

Color _foregroundFor(BuildContext context, AppFeedbackTone tone) {
  if (tone == AppFeedbackTone.error) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFFF1F2)
        : const Color(0xFF7F1D1D);
  }
  return Theme.of(context).colorScheme.onSurface;
}
