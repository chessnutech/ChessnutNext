import 'package:chessnut_flutter_export/widgets/lichess_authorization_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes supported Chessnut Lichess callback URLs', () {
    expect(
      isLichessAuthorizationComplete(
        Uri.parse('https://api.chessnutech.com/static/callback.html'),
      ),
      isTrue,
    );
    expect(
      isLichessAuthorizationComplete(
        Uri.parse('http://localhost:8888/static/callback.html'),
      ),
      isTrue,
    );
    expect(
      isLichessAuthorizationComplete(
        Uri.parse('http://127.0.0.1:8888/static/callback.html'),
      ),
      isTrue,
    );
    expect(
      isLichessAuthorizationComplete(Uri.parse('https://lichess.org/oauth')),
      isFalse,
    );
  });

  test('styles Lichess authorization login inputs for readable text', () {
    final script = lichessAuthorizationInputStyleScript();

    expect(script, contains('chessnut-lichess-auth-inputs'));
    expect(script, contains('input:not([type="hidden"])'));
    expect(script, contains('textarea'));
    expect(script, contains('[contenteditable="true"]'));
    expect(script, contains('input:-webkit-autofill'));
    expect(script, contains("readableText = '#111827'"));
    expect(script, contains("readableBackground = '#ffffff'"));
    expect(script, contains('-webkit-text-fill-color'));
    expect(script, contains('caret-color'));
    expect(script, contains('background-color'));
    expect(script, contains("style.setProperty('color', readableText"));
    expect(script, contains('MutationObserver'));
  });
}
