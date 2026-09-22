import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chessnut themes use the app font across Material components', () {
    for (final theme in [
      ChessnutTheme.light(),
      ChessnutTheme.dark(),
      ChessnutTheme.light(ChessnutVisualTheme.classic),
      ChessnutTheme.dark(ChessnutVisualTheme.classic),
    ]) {
      expect(theme.textTheme.bodyMedium?.fontFamily,
          ChessnutTheme.primaryFontFamily);
      expect(theme.textTheme.bodyMedium?.fontFamilyFallback,
          ChessnutTheme.fontFamilyFallback);
      expect(theme.primaryTextTheme.bodyMedium?.fontFamily,
          ChessnutTheme.primaryFontFamily);
      expect(theme.primaryTextTheme.bodyMedium?.fontFamilyFallback,
          ChessnutTheme.fontFamilyFallback);
      expect(
        theme.filledButtonTheme.style?.textStyle
            ?.resolve(const <WidgetState>{})?.fontFamily,
        ChessnutTheme.primaryFontFamily,
      );
      expect(
        theme.elevatedButtonTheme.style?.textStyle
            ?.resolve(const <WidgetState>{})?.fontFamily,
        ChessnutTheme.primaryFontFamily,
      );
      expect(
        theme.textButtonTheme.style?.textStyle
            ?.resolve(const <WidgetState>{})?.fontFamily,
        ChessnutTheme.primaryFontFamily,
      );
      expect(
        theme.outlinedButtonTheme.style?.textStyle
            ?.resolve(const <WidgetState>{})?.fontFamily,
        ChessnutTheme.primaryFontFamily,
      );
      expect(
        theme.segmentedButtonTheme.style?.textStyle
            ?.resolve(const <WidgetState>{})?.fontFamily,
        ChessnutTheme.primaryFontFamily,
      );
      expect(theme.inputDecorationTheme.labelStyle?.fontFamily,
          ChessnutTheme.primaryFontFamily);
      expect(theme.chipTheme.labelStyle?.fontFamily,
          ChessnutTheme.primaryFontFamily);
    }
  });
}
