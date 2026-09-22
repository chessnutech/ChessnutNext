import 'package:chessnut_flutter_export/widgets/app_chrome.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const viewportSize = Size(1920, 1080);

  Future<double> pumpPage(
    WidgetTester tester,
    TargetPlatform platform,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await tester.binding.setSurfaceSize(viewportSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsivePage(
              children: (context, spec) => const [
                SizedBox(key: Key('page-content'), height: 100),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.getSize(find.byKey(const Key('page-content'))).width;
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('Windows expanded pages use the available window width',
      (tester) async {
    final contentWidth = await pumpPage(tester, TargetPlatform.windows);

    expect(contentWidth, viewportSize.width - 56);
  });

  testWidgets('other platforms keep the expanded content width limit',
      (tester) async {
    final contentWidth = await pumpPage(tester, TargetPlatform.macOS);

    expect(contentWidth, 1260 - 56);
  });
}
