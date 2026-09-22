import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chessnut_flutter_export/l10n/app_language.dart';
import 'package:chessnut_flutter_export/l10n/app_strings.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/widgets/app_feedback.dart';

void main() {
  testWidgets('offline notification appears once per app launch across routes',
      (tester) async {
    late BuildContext pageContext;
    const offlineText = '设备当前无法联网，请检查 Wi-Fi 或移动网络后重试。';
    Widget app({ThemeMode themeMode = ThemeMode.light}) => MaterialApp(
          themeMode: themeMode,
          locale:
              const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
          supportedLocales: AppLanguagePreference.supportedLocales,
          localizationsDelegates: AppStrings.localizationsDelegates,
          home: Scaffold(body: Builder(builder: (context) {
            pageContext = context;
            return const SizedBox();
          })),
        );
    void notifyOffline() => showAppFeedback(
          pageContext,
          networkConnectionErrorMessage,
          tone: AppFeedbackTone.error,
          duration: const Duration(milliseconds: 100),
        );
    Future<void> dismiss() async {
      ScaffoldMessenger.of(pageContext).removeCurrentSnackBar();
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(app());
    // A global API error and page-specific error can report the same failure.
    notifyOffline();
    notifyOffline();
    await tester.pump();
    expect(find.text(offlineText), findsOneWidget);
    await dismiss();
    expect(find.byType(SnackBar), findsNothing);
    notifyOffline();
    showAppFeedback(pageContext, offlineText);
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);

    // Rebuilding the app for settings and opening a different route must not
    // reset the launch-scoped notification state.
    await tester.pumpWidget(app(themeMode: ThemeMode.dark));
    Navigator.of(pageContext).push<void>(MaterialPageRoute(builder: (_) {
      return Scaffold(body: Builder(builder: (context) {
        pageContext = context;
        return const SizedBox();
      }));
    }));
    await tester.pumpAndSettle();
    notifyOffline();
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(app());
    notifyOffline();
    await tester.pump();
    expect(find.text(offlineText), findsOneWidget);
    await dismiss();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('suppressed offline notifications do not hide other feedback',
      (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) {
        pageContext = context;
        return const SizedBox();
      })),
    ));
    showAppFeedback(pageContext, networkConnectionErrorMessage);
    await tester.pump();
    ScaffoldMessenger.of(pageContext).removeCurrentSnackBar();
    await tester.pumpAndSettle();

    for (var attempt = 0; attempt < 2; attempt++) {
      showAppFeedback(pageContext, 'Game could not be saved locally.');
      await tester.pump();
      showAppFeedback(pageContext, networkConnectionErrorMessage);
      await tester.pump();
      expect(find.text('Game could not be saved locally.'), findsOneWidget);
      expect(find.text(networkConnectionErrorMessage), findsNothing);
      ScaffoldMessenger.of(pageContext).removeCurrentSnackBar();
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
