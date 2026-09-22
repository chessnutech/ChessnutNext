import 'package:flutter/material.dart' as material;
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../services/app_update_service.dart';
import '../services/play_in_app_update_service.dart';
import 'app_chrome.dart';
import 'app_feedback.dart';

enum AppUpdateDialogResult { later, remindTomorrow, ignoreVersion, opened }

Future<AppUpdateDialogResult?> showAppUpdateDialog(
  material.BuildContext context,
  AppUpdateDecision decision, {
  bool showReminderChoices = false,
  bool showLaterAction = true,
  bool allowFlexiblePlayFallback = true,
}) {
  return material.showDialog<AppUpdateDialogResult>(
    context: context,
    barrierDismissible: !decision.forceUpdate && showLaterAction,
    builder: (_) => AppUpdateDialog(
      decision: decision,
      showReminderChoices: showReminderChoices,
      showLaterAction: showLaterAction,
      allowFlexiblePlayFallback: allowFlexiblePlayFallback,
    ),
  );
}

class AppUpdateDialog extends material.StatelessWidget {
  const AppUpdateDialog({
    required this.decision,
    this.showReminderChoices = false,
    this.showLaterAction = true,
    this.allowFlexiblePlayFallback = true,
    this.playUpdateService = const PlayInAppUpdateService(),
    super.key,
  });

  final AppUpdateDecision decision;
  final bool showReminderChoices;
  final bool showLaterAction;
  final bool allowFlexiblePlayFallback;
  final PlayInAppUpdateService playUpdateService;

  @override
  material.Widget build(material.BuildContext context) {
    final strings = AppStrings.of(context);
    return AppDialogShell(
      icon: material.Icons.system_update_alt_rounded,
      title: decision.forceUpdate
          ? strings.t('Update required')
          : strings.t('Update available'),
      subtitle: '${strings.t('Latest version')}: ${decision.latestVersion}',
      actions: [
        if (!decision.forceUpdate) ...[
          if (showLaterAction)
            material.OutlinedButton(
              onPressed: () => material.Navigator.of(context)
                  .pop(AppUpdateDialogResult.later),
              child: material.Text(strings.t('Later')),
            ),
          if (showReminderChoices) ...[
            material.OutlinedButton(
              onPressed: () => material.Navigator.of(context)
                  .pop(AppUpdateDialogResult.remindTomorrow),
              child: material.Text(strings.t('Remind me in 1 day')),
            ),
            material.OutlinedButton(
              onPressed: () => material.Navigator.of(context)
                  .pop(AppUpdateDialogResult.ignoreVersion),
              child: material.Text(
                strings.t("Don't remind me again for this update"),
              ),
            ),
          ],
        ],
        material.FilledButton.icon(
          onPressed: () => _openUpdate(context),
          icon: const material.Icon(material.Icons.open_in_new_rounded),
          label: material.Text(_primaryActionLabel(context)),
        ),
      ],
      child: material.Column(
        crossAxisAlignment: material.CrossAxisAlignment.stretch,
        children: [
          material.Text(
            _updateMessage(context),
            style: material.Theme.of(context).textTheme.bodyMedium,
          ),
          if (decision.releaseNotes.trim().isNotEmpty) ...[
            const material.SizedBox(height: 12),
            material.Container(
              padding: const material.EdgeInsets.all(12),
              decoration: material.BoxDecoration(
                color: material.Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.62),
                borderRadius: material.BorderRadius.circular(12),
                border: material.Border.all(
                  color: material.Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: material.Text(
                decision.releaseNotes,
                style: material.Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          const material.SizedBox(height: 10),
          material.Text(
            _methodNote(context),
            style: material.Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      material.Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: material.FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  String _updateMessage(material.BuildContext context) {
    final strings = AppStrings.of(context);
    if (decision.forceUpdate) {
      return strings.t(
        'This version is required to keep Chessnut working correctly. Please update before continuing.',
      );
    }
    return strings.t(
      'A newer version is available. Update now to get the latest fixes and improvements.',
    );
  }

  String _methodNote(material.BuildContext context) {
    final strings = AppStrings.of(context);
    switch (decision.updateMethod) {
      case 'play_in_app':
        return strings.t(
          'This update will be handled by Google Play on this device.',
        );
      case 'app_store':
        return strings.t(
          'This update will open the official app store or test track for your device.',
        );
      case 'store':
        return strings.t(
          'This update will open the Chessnut page on Google Play.',
        );
      case 'download':
        return strings.t(
          'This update will open the official Chessnut download page.',
        );
      default:
        return strings.t('This update will open in your browser.');
    }
  }

  String _primaryActionLabel(material.BuildContext context) {
    final strings = AppStrings.of(context);
    switch (decision.updateMethod) {
      case 'play_in_app':
        return strings.t('Update with Google Play');
      case 'app_store':
        return strings.t('Open store');
      case 'store':
        return strings.t('Open Google Play');
      case 'download':
        return strings.t('Download update');
      default:
        return strings.t('Update now');
    }
  }

  Future<void> _openUpdate(material.BuildContext context) async {
    if (decision.updateMethod == 'play_in_app') {
      final preferImmediate =
          decision.forceUpdate || decision.preferImmediatePlayUpdate;
      var result = await playUpdateService.startUpdate(
        immediate: preferImmediate,
      );
      if (result == PlayInAppUpdateResult.notAllowed &&
          preferImmediate &&
          allowFlexiblePlayFallback &&
          !decision.forceUpdate) {
        result = await playUpdateService.startUpdate(immediate: false);
      }
      if (result == PlayInAppUpdateResult.started) {
        if (context.mounted && !decision.forceUpdate) {
          material.Navigator.of(context).pop(AppUpdateDialogResult.opened);
        }
        return;
      }
      if (!context.mounted) return;
      showAppFeedback(
        context,
        AppStrings.of(context).t(
          'Google Play update is not available right now. Opening the store page instead.',
        ),
        tone: AppFeedbackTone.warning,
      );
    }
    final uri = Uri.tryParse(_updateUrl());
    if (uri == null || !uri.hasScheme) {
      showAppFeedback(
        context,
        AppStrings.of(context).t(
          'Update link is not available right now. Please try again later.',
        ),
        tone: AppFeedbackTone.warning,
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      showAppFeedback(
        context,
        AppStrings.of(context).t(
          'Could not open the update link. Please try again later.',
        ),
        tone: AppFeedbackTone.warning,
      );
    }
  }

  String _updateUrl() {
    if (decision.updateMethod == 'store' ||
        decision.updateMethod == 'play_in_app') {
      return decision.downloadUrl;
    }
    return decision.downloadUrl;
  }
}
