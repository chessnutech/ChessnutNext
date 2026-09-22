import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_windows/webview_windows.dart' as win_webview;

const String chessnutWebViewTextScaleGuardScript = '''
(function() {
  var css = [
    'html, body {',
    '  -webkit-text-size-adjust: 100% !important;',
    '  text-size-adjust: 100% !important;',
    '}'
  ].join('\\n');
  var parent = document.head || document.documentElement || document.body;
  if (!parent) return false;
  var style = document.getElementById('chessnut-webview-text-scale-guard');
  if (!style) {
    style = document.createElement('style');
    style.id = 'chessnut-webview-text-scale-guard';
    parent.appendChild(style);
  }
  style.textContent = css;
  return true;
})();
''';

Future<void> configureMobileWebViewZoomGuard(
  WebViewController controller,
) async {
  await controller.enableZoom(false);
  final platform = controller.platform;
  if (platform is AndroidWebViewController) {
    await platform.setTextZoom(100);
  }
}

Future<void> configureWindowsWebViewZoomGuard(
  win_webview.WebviewController controller,
) async {
  await controller.setZoomFactor(1.0);
}

Future<void> injectMobileWebViewTextScaleGuard(
  WebViewController controller,
) async {
  try {
    await controller.runJavaScript(chessnutWebViewTextScaleGuardScript);
  } catch (_) {
    // The page can still be navigating; callers inject again on the next event.
  }
}

Future<void> injectWindowsWebViewTextScaleGuard(
  win_webview.WebviewController controller,
) async {
  try {
    await controller.executeScript(chessnutWebViewTextScaleGuardScript);
  } catch (_) {
    // The page can still be navigating; callers inject again on the next event.
  }
}

Widget buildWebViewTextScaleGuard({required Widget child}) {
  return Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.noScaling,
      ),
      child: child,
    ),
  );
}
