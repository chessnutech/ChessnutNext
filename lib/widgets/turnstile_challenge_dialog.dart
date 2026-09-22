import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../l10n/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win_webview;

import '../services/recaptcha_service.dart';
import '../theme/chessnut_theme.dart';
import 'webview_zoom_guard.dart';

typedef TurnstileChallengePresenter = Future<RecaptchaResult> Function(
  BuildContext context, {
  required Uri challengeUri,
  required RecaptchaActionKind action,
});

Future<RecaptchaResult> showTurnstileChallenge(
  BuildContext context, {
  required Uri challengeUri,
  required RecaptchaActionKind action,
}) async {
  final result = await showDialog<RecaptchaResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => TurnstileChallengeDialog(challengeUri: challengeUri),
  );
  return result ?? const RecaptchaResult.failed('Verification was cancelled.');
}

class TurnstileChallengeDialog extends StatelessWidget {
  const TurnstileChallengeDialog({required this.challengeUri, super.key});

  final Uri challengeUri;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 12),
              child: Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Turnstile verification',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(
                      const RecaptchaResult.failed(
                        'Verification was cancelled.',
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                child: Platform.isWindows
                    ? _WindowsTurnstileWebView(challengeUri: challengeUri)
                    : _MobileTurnstileWebView(challengeUri: challengeUri),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileTurnstileWebView extends StatefulWidget {
  const _MobileTurnstileWebView({required this.challengeUri});

  final Uri challengeUri;

  @override
  State<_MobileTurnstileWebView> createState() =>
      _MobileTurnstileWebViewState();
}

class _MobileTurnstileWebViewState extends State<_MobileTurnstileWebView> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'ChessnutTurnstile',
        onMessageReceived: (message) => _handleToken(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            unawaited(injectMobileWebViewTextScaleGuard(_controller));
            if (mounted) setState(() => _loading = false);
          },
          onUrlChange: (change) => _handleUrl(change.url),
        ),
      );
    unawaited(_loadChallenge());
  }

  Future<void> _loadChallenge() async {
    await configureMobileWebViewZoomGuard(_controller);
    await _controller.loadRequest(widget.challengeUri);
  }

  void _handleUrl(String? url) {
    if (url == null) return;
    final uri = Uri.tryParse(url);
    final token = uri?.queryParameters['token'];
    if (token != null && token.isNotEmpty) _handleToken(token);
  }

  void _handleToken(String raw) {
    final token = _extractToken(raw);
    if (token == null || token.isEmpty || !mounted) return;
    Navigator.of(context).pop(RecaptchaResult.verified(token: token));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        buildWebViewTextScaleGuard(
          child: WebViewWidget(controller: _controller),
        ),
        if (_loading) const _TurnstileLoading(),
      ],
    );
  }
}

class _WindowsTurnstileWebView extends StatefulWidget {
  const _WindowsTurnstileWebView({required this.challengeUri});

  final Uri challengeUri;

  @override
  State<_WindowsTurnstileWebView> createState() =>
      _WindowsTurnstileWebViewState();
}

class _WindowsTurnstileWebViewState extends State<_WindowsTurnstileWebView> {
  final win_webview.WebviewController _controller =
      win_webview.WebviewController();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();
      await configureWindowsWebViewZoomGuard(_controller);
      _subscriptions.add(_controller.url.listen(_handleUrl));
      _subscriptions.add(_controller.webMessage.listen((message) {
        _handleToken(message);
      }));
      _subscriptions.add(_controller.loadingState.listen((state) {
        if (state == win_webview.LoadingState.navigationCompleted) {
          unawaited(injectWindowsWebViewTextScaleGuard(_controller));
        }
      }));
      await _controller.setPopupWindowPolicy(
        win_webview.WebviewPopupWindowPolicy.deny,
      );
      await _controller.loadUrl(widget.challengeUri.toString());
      unawaited(injectWindowsWebViewTextScaleGuard(_controller));
      if (!mounted) return;
      setState(() {});
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _error =
            'Verification could not open in the app. Continue to try another way.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error =
            'Verification could not open in the app. Continue to try another way.';
      });
    }
  }

  void _handleUrl(String url) {
    final uri = Uri.tryParse(url);
    final token = uri?.queryParameters['token'];
    if (token != null && token.isNotEmpty) _handleToken(token);
  }

  void _handleToken(Object? raw) {
    final token = _extractToken(raw);
    if (token == null || token.isEmpty || !mounted) return;
    Navigator.of(context).pop(RecaptchaResult.verified(token: token));
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return _TurnstileError(message: error);
    }
    if (!_controller.value.isInitialized) {
      return const _TurnstileLoading();
    }
    return Stack(
      children: [
        buildWebViewTextScaleGuard(
          child: win_webview.Webview(_controller),
        ),
        StreamBuilder<win_webview.LoadingState>(
          stream: _controller.loadingState,
          builder: (context, snapshot) {
            if (snapshot.data == win_webview.LoadingState.loading) {
              return const _TurnstileLoading();
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

class _TurnstileLoading extends StatelessWidget {
  const _TurnstileLoading();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _TurnstileError extends StatelessWidget {
  const _TurnstileError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final danger = ChessnutTheme.tokensOf(context).danger;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, color: danger, size: 36),
          const SizedBox(height: 12),
          const Text(
            'Verification could not open in the app',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              const RecaptchaResult.failed(
                'Verification could not open in the app. Try the browser verification.',
              ),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

String? _extractToken(Object? raw) {
  if (raw == null) return null;
  if (raw is Map) {
    return (raw['token'] ?? raw['cf-turnstile-response'])?.toString();
  }
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map) {
      return (decoded['token'] ?? decoded['cf-turnstile-response'])?.toString();
    }
  } catch (_) {
    return text;
  }
  return text;
}
