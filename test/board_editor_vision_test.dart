import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/l10n/app_language.dart';
import 'package:chessnut_flutter_export/l10n/app_strings.dart';
import 'package:chessnut_flutter_export/screens/board_editor_screen.dart';
import 'package:chessnut_flutter_export/screens/setup_screen.dart';
import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/services/board_vision_service.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';

class _FakeBoardVisionImagePicker implements BoardVisionImagePicker {
  _FakeBoardVisionImagePicker(this._sourceAvailability);

  final BoardVisionSourceAvailability _sourceAvailability;
  BoardVisionImageSource? pickedSource;

  @override
  BoardVisionSourceAvailability availability({required bool isChessnutClock}) {
    return _sourceAvailability;
  }

  @override
  Future<BoardVisionImage?> pick(BoardVisionImageSource source) async {
    pickedSource = source;
    return const BoardVisionImage(bytes: [1, 2, 3]);
  }
}

class _FakeBoardVisionFenRecognizer implements BoardVisionFenRecognizer {
  _FakeBoardVisionFenRecognizer(this.fen);

  final String? fen;
  List<int>? imageBytes;

  @override
  Future<String?> recognizeFen(List<int> imageBytes) async {
    this.imageBytes = imageBytes;
    return fen;
  }

  @override
  Future<String?> recognizeJson(List<int> imageBytes) async {
    this.imageBytes = imageBytes;
    return null;
  }
}

Widget _testShell(Widget child) {
  return MaterialApp(
    theme: ChessnutTheme.light(),
    supportedLocales: AppLanguagePreference.supportedLocales,
    localizationsDelegates: AppStrings.localizationsDelegates,
    home: Scaffold(body: child),
  );
}

Widget _localizedTestShell(Widget child, Locale locale) {
  return MaterialApp(
    locale: locale,
    theme: ChessnutTheme.light(),
    supportedLocales: AppLanguagePreference.supportedLocales,
    localizationsDelegates: AppStrings.localizationsDelegates,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets(
      'Vision import recognizes the selected image and imports returned FEN for sending',
      (tester) async {
    String? importedFen;
    final picker = _FakeBoardVisionImagePicker(
      const BoardVisionSourceAvailability(gallery: true, camera: false),
    );
    final recognizer = _FakeBoardVisionFenRecognizer(
      '8/8/8/3k4/8/4K3/8/8 b - - 0 1',
    );

    await tester.pumpWidget(
      _testShell(
        BoardEditorScreen(
          onNavigate: (_) {},
          imagePicker: picker,
          fenRecognizer: recognizer,
          isChessnutClockDevice: true,
          onFenChanged: (fen) => importedFen = fen,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.lightbulb_outline_rounded).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choose image'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose image'));
    await tester.pump();
    await tester.pump();

    expect(picker.pickedSource, BoardVisionImageSource.gallery);
    expect(recognizer.imageBytes, [1, 2, 3]);
    expect(importedFen, '8/8/8/3k4/8/4K3/8/8 b - - 0 1');
    expect(find.text('Position imported from image.'), findsOneWidget);
    expect(find.text('Send FEN to board'), findsOneWidget);
    expect(find.textContaining('8/8/8/3k4/8/4K3/8/8'), findsOneWidget);
  });

  testWidgets('Vision panel uses localized copy', (tester) async {
    await tester.pumpWidget(
      _localizedTestShell(
        BoardEditorScreen(
          onNavigate: (_) {},
          imagePicker: _FakeBoardVisionImagePicker(
            const BoardVisionSourceAvailability(gallery: true, camera: false),
          ),
          fenRecognizer: _FakeBoardVisionFenRecognizer(null),
          isChessnutClockDevice: true,
        ),
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      ),
    );

    await tester.tap(find.byIcon(Icons.lightbulb_outline_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('从照片导入棋盘局面。'), findsOneWidget);
    expect(find.text('选择图片'), findsOneWidget);
    expect(find.text('Import a board position from a photo.'), findsNothing);
  });

  testWidgets('Bot board editor recognizes images locally', (tester) async {
    final picker = _FakeBoardVisionImagePicker(
      const BoardVisionSourceAvailability(gallery: true, camera: false),
    );
    final recognizer = _FakeBoardVisionFenRecognizer(
      '8/8/8/3k4/8/4K3/8/8 b - - 0 1',
    );

    await tester.pumpWidget(
      _testShell(
        BotBoardEditorSheet(
          initialFen: chessnutStandardStartFen,
          openInFenMode: true,
          imagePicker: picker,
          fenRecognizer: recognizer,
          isChessnutClockDevice: true,
        ),
      ),
    );

    await tester.ensureVisible(find.text('Choose image'));
    await tester.tap(find.text('Choose image'));
    await tester.pump();
    await tester.pump();

    expect(picker.pickedSource, BoardVisionImageSource.gallery);
    expect(recognizer.imageBytes, [1, 2, 3]);
    expect(find.text('Position imported from image.'), findsOneWidget);
    expect(find.textContaining('8/8/8/3k4/8/4K3/8/8'), findsOneWidget);
  });

}
