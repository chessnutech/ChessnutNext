import 'dart:async';
import 'dart:io';

import '../l10n/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win_webview;

import 'webview_zoom_guard.dart';

typedef LichessAuthorizationPresenter = Future<bool> Function(
  BuildContext context, {
  required Uri authorizationUri,
});

@visibleForTesting
const lichessAuthorizationCompletionDelay = Duration(seconds: 3);

@visibleForTesting
String lichessAuthorizationInputStyleScript() => r'''
(function() {
  var readableText = '#111827';
  var readableBackground = '#ffffff';
  var placeholderText = '#6b7280';
  var fieldSelector = [
    'input:not([type="hidden"]):not([type="checkbox"]):not([type="radio"]):not([type="button"]):not([type="submit"]):not([type="reset"]):not([type="file"]):not([type="image"]):not([type="range"]):not([type="color"])',
    'textarea',
    '[contenteditable="true"]'
  ].join(',');
  var css = [
    fieldSelector + ' {',
    '  color: ' + readableText + ' !important;',
    '  -webkit-text-fill-color: ' + readableText + ' !important;',
    '  caret-color: ' + readableText + ' !important;',
    '  background-color: ' + readableBackground + ' !important;',
    '  opacity: 1 !important;',
    '  text-shadow: none !important;',
    '  filter: none !important;',
    '  mix-blend-mode: normal !important;',
    '  color-scheme: light !important;',
    '}',
    'input:-webkit-autofill,',
    'input:-webkit-autofill:hover,',
    'input:-webkit-autofill:focus,',
    'textarea:-webkit-autofill,',
    'textarea:-webkit-autofill:hover,',
    'textarea:-webkit-autofill:focus {',
    '  color: ' + readableText + ' !important;',
    '  -webkit-text-fill-color: ' + readableText + ' !important;',
    '  caret-color: ' + readableText + ' !important;',
    '  -webkit-box-shadow: 0 0 0 1000px ' + readableBackground + ' inset !important;',
    '  box-shadow: 0 0 0 1000px ' + readableBackground + ' inset !important;',
    '  transition: background-color 9999s ease-out 0s !important;',
    '}',
    'input::placeholder,',
    'textarea::placeholder {',
    '  color: ' + placeholderText + ' !important;',
    '  -webkit-text-fill-color: ' + placeholderText + ' !important;',
    '  opacity: 1 !important;',
    '}',
    'input::selection,',
    'textarea::selection,',
    '[contenteditable="true"]::selection {',
    '  color: #ffffff !important;',
    '  background: #2563eb !important;',
    '}'
  ].join('\n');
  var parent = document.head || document.documentElement || document.body;
  if (!parent) return false;
  var style = document.getElementById('chessnut-lichess-auth-inputs');
  if (!style) {
    style = document.createElement('style');
    style.id = 'chessnut-lichess-auth-inputs';
    parent.appendChild(style);
  }
  style.textContent = css;

  function applyReadableFieldStyle(field) {
    if (!field || !field.style) return;
    field.style.setProperty('color', readableText, 'important');
    field.style.setProperty('-webkit-text-fill-color', readableText, 'important');
    field.style.setProperty('caret-color', readableText, 'important');
    field.style.setProperty('background-color', readableBackground, 'important');
    field.style.setProperty('opacity', '1', 'important');
    field.style.setProperty('text-shadow', 'none', 'important');
    field.style.setProperty('filter', 'none', 'important');
    field.style.setProperty('mix-blend-mode', 'normal', 'important');
    field.style.setProperty('color-scheme', 'light', 'important');
  }

  function applyAllReadableFieldStyles(root) {
    var scope = root && root.querySelectorAll ? root : document;
    var fields = scope.querySelectorAll(fieldSelector);
    for (var i = 0; i < fields.length; i++) {
      applyReadableFieldStyle(fields[i]);
    }
  }

  applyAllReadableFieldStyles(document);

  if (!window.__chessnutLichessAuthInputObserver) {
    window.__chessnutLichessAuthInputObserver = true;
    document.addEventListener('focusin', function(event) {
      if (event.target && event.target.matches && event.target.matches(fieldSelector)) {
        applyReadableFieldStyle(event.target);
      }
    }, true);
    document.addEventListener('input', function(event) {
      if (event.target && event.target.matches && event.target.matches(fieldSelector)) {
        applyReadableFieldStyle(event.target);
      }
    }, true);
    var observer = new MutationObserver(function(mutations) {
      for (var i = 0; i < mutations.length; i++) {
        for (var j = 0; j < mutations[i].addedNodes.length; j++) {
          var node = mutations[i].addedNodes[j];
          if (node && node.nodeType === 1) {
            if (node.matches && node.matches(fieldSelector)) {
              applyReadableFieldStyle(node);
            }
            applyAllReadableFieldStyles(node);
          }
        }
      }
    });
    var observerRoot = document.documentElement || document.body;
    if (observerRoot) {
      observer.observe(observerRoot, {
        childList: true,
        subtree: true
      });
    }
  }
  return true;
})();
''';

Future<bool> showLichessAuthorization(
  BuildContext context, {
  required Uri authorizationUri,
}) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LichessAuthorizationPage(
        authorizationUri: authorizationUri,
      ),
    ),
  );
  return result ?? false;
}

class LichessAuthorizationPage extends StatelessWidget {
  const LichessAuthorizationPage({
    required this.authorizationUri,
    super.key,
  });

  final Uri authorizationUri;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close authorization',
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text(
          'Authorize Lichess',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Icon(
              Icons.verified_user_rounded,
              color: scheme.primary,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Platform.isWindows
                ? _WindowsLichessAuthorizationWebView(
                    authorizationUri: authorizationUri,
                  )
                : _MobileLichessAuthorizationWebView(
                    authorizationUri: authorizationUri,
                  ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          const _LichessAuthorizationFooter(),
        ],
      ),
    );
  }
}

class _LichessAuthorizationFooter extends StatelessWidget {
  const _LichessAuthorizationFooter();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final message = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'Complete authorization on this page.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message:
                    'Chessnut will return automatically after Lichess shows the authorization callback.',
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 5),
                child: Icon(
                  Icons.help_outline_rounded,
                  size: 17,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          );
          final closeButton = TextButton.icon(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded),
            label: const Text(
              'Close authorization',
              maxLines: 2,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                message,
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [closeButton],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: message),
              const SizedBox(width: 12),
              closeButton,
            ],
          );
        },
      ),
    );
  }
}

class _MobileLichessAuthorizationWebView extends StatefulWidget {
  const _MobileLichessAuthorizationWebView({required this.authorizationUri});

  final Uri authorizationUri;

  @override
  State<_MobileLichessAuthorizationWebView> createState() =>
      _MobileLichessAuthorizationWebViewState();
}

class _MobileLichessAuthorizationWebViewState
    extends State<_MobileLichessAuthorizationWebView> {
  late final WebViewController _controller;
  Timer? _completionTimer;
  bool _loading = true;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            unawaited(_injectInputStyle());
            _handleUrl(url);
            if (mounted) setState(() => _loading = false);
          },
          onProgress: (progress) {
            if (progress >= 20) unawaited(_injectInputStyle());
          },
          onUrlChange: (change) {
            unawaited(_injectInputStyle());
            _handleUrl(change.url);
          },
        ),
      );
    unawaited(_loadAuthorization());
  }

  Future<void> _loadAuthorization() async {
    await configureMobileWebViewZoomGuard(_controller);
    await _controller.loadRequest(widget.authorizationUri);
  }

  Future<void> _injectInputStyle() async {
    try {
      await injectMobileWebViewTextScaleGuard(_controller);
      await _controller.runJavaScript(lichessAuthorizationInputStyleScript());
    } catch (_) {
      // The page may still be navigating; the next load event retries.
    }
  }

  void _handleUrl(String? url) {
    if (url == null || !mounted) return;
    final uri = Uri.tryParse(url);
    if (isLichessAuthorizationComplete(uri)) {
      _completeAfterCallback();
    }
  }

  void _completeAfterCallback() {
    if (_completing) return;
    setState(() => _completing = true);
    _completionTimer = Timer(lichessAuthorizationCompletionDelay, () {
      if (!mounted) return;
      Navigator.of(context).pop(true);
    });
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        buildWebViewTextScaleGuard(
          child: WebViewWidget(controller: _controller),
        ),
        if (_loading && !_completing) const _LichessAuthorizationLoading(),
        if (_completing) const _LichessAuthorizationComplete(),
      ],
    );
  }
}

class _WindowsLichessAuthorizationWebView extends StatefulWidget {
  const _WindowsLichessAuthorizationWebView({required this.authorizationUri});

  final Uri authorizationUri;

  @override
  State<_WindowsLichessAuthorizationWebView> createState() =>
      _WindowsLichessAuthorizationWebViewState();
}

class _WindowsLichessAuthorizationWebViewState
    extends State<_WindowsLichessAuthorizationWebView> {
  final win_webview.WebviewController _controller =
      win_webview.WebviewController();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _completionTimer;
  String? _error;
  bool _completing = false;

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
      _subscriptions.add(_controller.loadingState.listen((state) {
        if (state == win_webview.LoadingState.navigationCompleted) {
          unawaited(_injectInputStyle());
        } else if (state == win_webview.LoadingState.loading) {
          unawaited(_injectInputStyle());
        }
      }));
      await _controller.setPopupWindowPolicy(
        win_webview.WebviewPopupWindowPolicy.deny,
      );
      await _controller.loadUrl(widget.authorizationUri.toString());
      unawaited(_injectInputStyle());
      if (!mounted) return;
      setState(() {});
    } on PlatformException {
      if (!mounted) return;
      setState(
        () => _error =
            'Authorization could not open in the app. Check WebView2 and try again.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error =
            'Authorization could not open in the app. Check WebView2 and try again.',
      );
    }
  }

  void _handleUrl(String url) {
    if (!mounted) return;
    unawaited(_injectInputStyle());
    final uri = Uri.tryParse(url);
    if (isLichessAuthorizationComplete(uri)) {
      _completeAfterCallback();
    }
  }

  void _completeAfterCallback() {
    if (_completing) return;
    setState(() => _completing = true);
    _completionTimer = Timer(lichessAuthorizationCompletionDelay, () {
      if (!mounted) return;
      Navigator.of(context).pop(true);
    });
  }

  Future<void> _injectInputStyle() async {
    try {
      await injectWindowsWebViewTextScaleGuard(_controller);
      await _controller.executeScript(lichessAuthorizationInputStyleScript());
    } catch (_) {
      // The page may still be navigating; the next load event retries.
    }
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
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
      return _LichessAuthorizationError(message: error);
    }
    if (!_controller.value.isInitialized) {
      return const _LichessAuthorizationLoading();
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
              return const _LichessAuthorizationLoading();
            }
            return const SizedBox.shrink();
          },
        ),
        if (_completing) const _LichessAuthorizationComplete(),
      ],
    );
  }
}

class _LichessAuthorizationLoading extends StatelessWidget {
  const _LichessAuthorizationLoading();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface.withValues(alpha: 0.88),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Opening Lichess authorization...'),
          ],
        ),
      ),
    );
  }
}

class _LichessAuthorizationComplete extends StatelessWidget {
  const _LichessAuthorizationComplete();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface.withValues(alpha: 0.90),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: scheme.primary, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Lichess authorization complete.',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Returning to Chessnut...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _LichessAuthorizationError extends StatelessWidget {
  const _LichessAuthorizationError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: scheme.error, size: 36),
            const SizedBox(height: 12),
            const Text(
              'Lichess authorization could not open.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
bool isLichessAuthorizationComplete(Uri? uri) {
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  final path = uri.path.toLowerCase();
  return path == '/static/callback.html' &&
      (host == 'staging-api.chessnutech.com' ||
          host == 'api.chessnutech.com' ||
          host == 'www.chessnutech.com' ||
          host == 'chessnutech.com' ||
          host == 'localhost' ||
          host == '127.0.0.1');
}
