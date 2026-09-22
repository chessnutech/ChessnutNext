import 'dart:async';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import 'chessnut_endpoint_config.dart';

enum RecaptchaActionKind {
  signup,
  login;

  String get wireName {
    return switch (this) {
      RecaptchaActionKind.signup => 'signup',
      RecaptchaActionKind.login => 'login',
    };
  }
}

class RecaptchaProvider {
  static const String googleEnterprise = 'google_recaptcha';
  static const String cloudflareTurnstile = 'cloudflare_turnstile';
}

class RecaptchaResult {
  const RecaptchaResult.verified({
    required this.token,
    this.provider = RecaptchaProvider.cloudflareTurnstile,
  }) : message = null;

  const RecaptchaResult.failed(
    this.message, {
    this.provider = RecaptchaProvider.cloudflareTurnstile,
  }) : token = null;

  final String? token;
  final String provider;
  final String? message;

  bool get isVerified => token != null && token!.isNotEmpty;
}

abstract interface class RecaptchaService {
  Future<RecaptchaResult> verify({required RecaptchaActionKind action});
}

class TurnstileConfig {
  const TurnstileConfig({
    this.siteKey = const String.fromEnvironment('CHESSNUT_TURNSTILE_SITE_KEY'),
    this.challengeBaseUrl = const String.fromEnvironment(
      'CHESSNUT_TURNSTILE_CHALLENGE_URL',
      defaultValue: ChessnutEndpointConfig.defaultTurnstileChallengeUrl,
    ),
    this.timeout = const Duration(minutes: 3),
  });

  final String siteKey;
  final String challengeBaseUrl;
  final Duration timeout;

  bool get isConfigured => true;

  Uri challengeUri({
    Uri? callback,
    required RecaptchaActionKind action,
    String mode = 'redirect',
  }) {
    return _challengeBaseUri.replace(
      queryParameters: {
        if (siteKey.trim().isNotEmpty) 'sitekey': siteKey,
        if (callback != null) 'callback': callback.toString(),
        if (mode.trim().isNotEmpty) 'mode': mode,
        'action': action.wireName,
      },
    );
  }

  Uri get _challengeBaseUri {
    final configured = challengeBaseUrl.trim();
    if (configured.isNotEmpty) {
      return Uri.parse(configured);
    }
    return Uri.parse(ChessnutEndpointConfig.defaultTurnstileChallengeUrl);
  }
}

class CloudflareTurnstileService implements RecaptchaService {
  CloudflareTurnstileService({
    TurnstileConfig config = const TurnstileConfig(),
    Future<bool> Function(Uri uri)? launchChallenge,
  })  : _config = config,
        _launchChallenge = launchChallenge ?? _defaultLaunchChallenge;

  final TurnstileConfig _config;
  final Future<bool> Function(Uri uri) _launchChallenge;

  @override
  Future<RecaptchaResult> verify({required RecaptchaActionKind action}) async {
    if (!_config.isConfigured) {
      return const RecaptchaResult.failed(
        'Verification is not available right now. Please try again later.',
      );
    }

    HttpServer? server;
    Timer? timeoutTimer;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final callback = Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: server.port,
        path: '/turnstile',
      );
      final completer = Completer<RecaptchaResult>();
      timeoutTimer = Timer(_config.timeout, () {
        if (!completer.isCompleted) {
          completer.complete(
            const RecaptchaResult.failed(
              'Verification took too long. Check your connection and try again.',
            ),
          );
        }
      });

      unawaited(_listenForToken(server, completer));
      final launched = await _launchChallenge(
        _config.challengeUri(callback: callback, action: action),
      );
      if (!launched) {
        return const RecaptchaResult.failed(
          'Verification could not open. Check your connection and try again.',
        );
      }
      return await completer.future;
    } catch (error) {
      return const RecaptchaResult.failed(
        'Verification failed. Please try again.',
      );
    } finally {
      timeoutTimer?.cancel();
      await server?.close(force: true);
    }
  }

  Future<void> _listenForToken(
    HttpServer server,
    Completer<RecaptchaResult> completer,
  ) async {
    await for (final request in server) {
      final token = request.uri.queryParameters['token'];
      request.response.headers.contentType = ContentType.html;
      if (token == null || token.isEmpty) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write(
          _htmlResponse('Verification was incomplete. Please try again.'),
        );
        await request.response.close();
        continue;
      }
      request.response.write(_htmlResponse('Verification complete.'));
      await request.response.close();
      if (!completer.isCompleted) {
        completer.complete(RecaptchaResult.verified(token: token));
      }
      break;
    }
  }

  String _htmlResponse(String message) {
    return '<!doctype html><html><body style="font-family:sans-serif">'
        '<h3>$message</h3><p>You can return to Chessnut now.</p>'
        '</body></html>';
  }

  static Future<bool> _defaultLaunchChallenge(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
