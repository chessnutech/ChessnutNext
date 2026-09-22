import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/services/recaptcha_service.dart';

void main() {
  test('TurnstileConfig falls back to the configured Chessnut API host', () {
    const config = TurnstileConfig();

    expect(
      config
          .challengeUri(
            callback: Uri.parse('http://127.0.0.1:49321/callback'),
            action: RecaptchaActionKind.signup,
          )
          .toString(),
      'https://api.chessnutech.com/captcha/turnstile'
      '?callback=http%3A%2F%2F127.0.0.1%3A49321%2Fcallback'
      '&mode=redirect'
      '&action=signup',
    );
  });

  test('TurnstileConfig default challenge URL uses production API', () {
    const config = TurnstileConfig();

    final uri = config.challengeUri(
        action: RecaptchaActionKind.signup, mode: 'webview');

    expect(uri.host, 'api.chessnutech.com');
    expect(uri.path, '/captcha/turnstile');
  });

  test('TurnstileConfig builds challenge URL with optional site key', () {
    const config = TurnstileConfig(
      siteKey: 'turnstile-site-key',
      challengeBaseUrl: 'https://api.chessnutech.com/captcha/turnstile',
    );

    expect(config.isConfigured, isTrue);
    expect(
      config
          .challengeUri(
            callback: Uri.parse('http://127.0.0.1:49321/callback'),
            action: RecaptchaActionKind.signup,
          )
          .toString(),
      'https://api.chessnutech.com/captcha/turnstile'
      '?sitekey=turnstile-site-key'
      '&callback=http%3A%2F%2F127.0.0.1%3A49321%2Fcallback'
      '&mode=redirect'
      '&action=signup',
    );

    const serverConfigured = TurnstileConfig(
      challengeBaseUrl: 'https://api.chessnutech.com/captcha/turnstile',
    );
    expect(serverConfigured.isConfigured, isTrue);
    expect(
      serverConfigured
          .challengeUri(
            callback: Uri.parse('http://127.0.0.1:49321/callback'),
            action: RecaptchaActionKind.signup,
          )
          .toString(),
      'https://api.chessnutech.com/captcha/turnstile'
      '?callback=http%3A%2F%2F127.0.0.1%3A49321%2Fcallback'
      '&mode=redirect'
      '&action=signup',
    );
  });

  test('TurnstileConfig can build in-app WebView challenge URLs', () {
    const config = TurnstileConfig(
      siteKey: 'turnstile-site-key',
      challengeBaseUrl: 'https://api.chessnutech.com/captcha/turnstile',
    );

    expect(
      config
          .challengeUri(action: RecaptchaActionKind.signup, mode: 'webview')
          .toString(),
      'https://api.chessnutech.com/captcha/turnstile'
      '?sitekey=turnstile-site-key'
      '&mode=webview'
      '&action=signup',
    );
  });

  test('CloudflareTurnstileService fails safely when challenge URL is missing',
      () async {
    final service = CloudflareTurnstileService(
      config: const TurnstileConfig(challengeBaseUrl: ''),
      launchChallenge: (_) async => false,
    );

    final result = await service.verify(action: RecaptchaActionKind.signup);

    expect(result.isVerified, isFalse);
    expect(result.token, isNull);
    expect(result.provider, RecaptchaProvider.cloudflareTurnstile);
    expect(
      result.message,
      'Verification could not open. Check your connection and try again.',
    );
  });
}
