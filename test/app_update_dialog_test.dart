import 'dart:collection';

import 'package:chessnut_flutter_export/l10n/app_strings.dart';
import 'package:chessnut_flutter_export/services/app_update_service.dart';
import 'package:chessnut_flutter_export/services/play_in_app_update_service.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';
import 'package:chessnut_flutter_export/widgets/app_update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Automatic update dialog hides later action', (
    WidgetTester tester,
  ) async {
    final playUpdateService = _RecordingPlayUpdateService([
      PlayInAppUpdateResult.started,
    ]);

    await tester.pumpWidget(
      _testApp(
        playUpdateService: playUpdateService,
        showLaterAction: false,
        showReminderChoices: true,
        decision: _playDecision(),
      ),
    );

    expect(find.text('Later'), findsNothing);
    expect(find.text('Remind me in 1 day'), findsOneWidget);
    expect(find.text("Don't remind me again for this update"), findsOneWidget);
  });

  testWidgets('Play update dialog prefers immediate updates when requested', (
    WidgetTester tester,
  ) async {
    final playUpdateService = _RecordingPlayUpdateService([
      PlayInAppUpdateResult.started,
    ]);

    await tester.pumpWidget(
      _testApp(
        playUpdateService: playUpdateService,
        decision: _playDecision(preferImmediatePlayUpdate: true),
      ),
    );

    await tester.tap(find.text('Update with Google Play'));
    await tester.pump();

    expect(playUpdateService.immediateCalls, <bool>[true]);
  });

  testWidgets('Play update dialog falls back to flexible when immediate denied',
      (
    WidgetTester tester,
  ) async {
    final playUpdateService = _RecordingPlayUpdateService([
      PlayInAppUpdateResult.notAllowed,
      PlayInAppUpdateResult.started,
    ]);

    await tester.pumpWidget(
      _testApp(
        playUpdateService: playUpdateService,
        decision: _playDecision(preferImmediatePlayUpdate: true),
      ),
    );

    await tester.tap(find.text('Update with Google Play'));
    await tester.pump();

    expect(playUpdateService.immediateCalls, <bool>[true, false]);
  });

  testWidgets('App Store update dialog uses generic store copy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        playUpdateService: _RecordingPlayUpdateService(const []),
        decision: _appStoreDecision(),
      ),
    );

    expect(find.text('Open store'), findsOneWidget);
    expect(
      find.text(
        'This update will open the official app store or test track for your device.',
      ),
      findsOneWidget,
    );
    expect(find.text('Open Google Play'), findsNothing);
    expect(find.text('Update with Google Play'), findsNothing);
  });
}

Widget _testApp({
  required AppUpdateDecision decision,
  required PlayInAppUpdateService playUpdateService,
  bool showLaterAction = true,
  bool showReminderChoices = false,
}) {
  return MaterialApp(
    theme: ChessnutTheme.light(),
    localizationsDelegates: AppStrings.localizationsDelegates,
    supportedLocales: const [Locale('en')],
    home: Scaffold(
      body: AppUpdateDialog(
        decision: decision,
        showLaterAction: showLaterAction,
        showReminderChoices: showReminderChoices,
        playUpdateService: playUpdateService,
      ),
    ),
  );
}

AppUpdateDecision _playDecision({
  bool preferImmediatePlayUpdate = false,
}) {
  return AppUpdateDecision(
    hasUpdate: true,
    forceUpdate: false,
    currentVersion: '0.5.2+5002',
    latestVersion: 'build 5003',
    downloadUrl: 'https://play.google.com/store/apps/details?id=test',
    releaseNotes: '',
    updateMethod: 'play_in_app',
    platformName: 'android',
    preferImmediatePlayUpdate: preferImmediatePlayUpdate,
  );
}

AppUpdateDecision _appStoreDecision() {
  return const AppUpdateDecision(
    hasUpdate: true,
    forceUpdate: false,
    currentVersion: '0.5.2+5002',
    latestVersion: '0.5.3',
    downloadUrl: 'https://apps.apple.com/us/app/chessnut/id123456789',
    releaseNotes: '',
    updateMethod: 'app_store',
    platformName: 'ios',
  );
}

class _RecordingPlayUpdateService extends PlayInAppUpdateService {
  _RecordingPlayUpdateService(List<PlayInAppUpdateResult> results)
      : _results = Queue<PlayInAppUpdateResult>.of(results);

  final Queue<PlayInAppUpdateResult> _results;
  final List<bool> immediateCalls = <bool>[];

  @override
  Future<PlayInAppUpdateResult> startUpdate({required bool immediate}) async {
    immediateCalls.add(immediate);
    return _results.removeFirst();
  }
}
