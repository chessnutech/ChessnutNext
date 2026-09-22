import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

abstract class ReportShareService {
  Future<bool> shareReportImage({
    required BuildContext context,
    required GlobalKey boundaryKey,
    required String fileName,
    required String subject,
  });

  Future<bool> downloadReportHtml({
    required BuildContext context,
    required String html,
    required String fileName,
    required String subject,
  });
}

class SystemReportShareService implements ReportShareService {
  const SystemReportShareService();

  @override
  Future<bool> shareReportImage({
    required BuildContext context,
    required GlobalKey boundaryKey,
    required String fileName,
    required String subject,
  }) async {
    final boundaryContext = boundaryKey.currentContext;
    final renderObject = boundaryContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('Report is not ready to share.');
    }

    final pixelRatio = _reportPixelRatio(
      renderObject.size,
      MediaQuery.devicePixelRatioOf(context),
    );
    final originBox = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = originBox == null
        ? null
        : originBox.localToGlobal(Offset.zero) & originBox.size;
    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final bytes = byteData?.buffer.asUint8List();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Report image is empty.');
    }

    if (Platform.isWindows) {
      final saveLocation = await file_selector.getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: const [
          file_selector.XTypeGroup(
            label: 'PNG image',
            extensions: ['png'],
            mimeTypes: ['image/png'],
          ),
        ],
      );
      if (saveLocation == null) return false;
      final file = File(_pngPath(saveLocation.path));
      await file.writeAsBytes(bytes, flush: true);
      await Process.run('explorer.exe', ['/select,${file.path}']);
      return true;
    }

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png', name: fileName)],
        subject: subject,
        title: subject,
        sharePositionOrigin: sharePositionOrigin,
        fileNameOverrides: [fileName],
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }

  @override
  Future<bool> downloadReportHtml({
    required BuildContext context,
    required String html,
    required String fileName,
    required String subject,
  }) async {
    final safeFileName = _htmlPath(fileName);
    final originBox = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = originBox == null
        ? null
        : originBox.localToGlobal(Offset.zero) & originBox.size;
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final saveLocation = await file_selector.getSaveLocation(
        suggestedName: safeFileName,
        acceptedTypeGroups: const [
          file_selector.XTypeGroup(
            label: 'HTML document',
            extensions: ['html'],
            mimeTypes: ['text/html'],
          ),
        ],
      );
      if (saveLocation == null) return false;
      final file = File(_htmlPath(saveLocation.path));
      await file.writeAsString(html, flush: true);
      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,${file.path}']);
      }
      return true;
    }

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}${Platform.pathSeparator}$safeFileName');
    await file.writeAsString(html, flush: true);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/html', name: safeFileName)],
        subject: subject,
        title: subject,
        sharePositionOrigin: sharePositionOrigin,
        fileNameOverrides: [safeFileName],
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }
}

double _reportPixelRatio(Size size, double devicePixelRatio) {
  if (size.isEmpty || !size.isFinite) return 1;
  const maxDimension = 8192.0;
  const maxPixels = 24 * 1024 * 1024;
  final requested = devicePixelRatio.clamp(1.0, 2.0);
  final dimensionLimit = math.min(
    maxDimension / size.width,
    maxDimension / size.height,
  );
  final pixelLimit = math.sqrt(maxPixels / (size.width * size.height));
  return math.min(requested, math.min(dimensionLimit, pixelLimit)).clamp(
        0.25,
        requested,
      );
}

String _pngPath(String path) {
  return path.toLowerCase().endsWith('.png') ? path : '$path.png';
}

String _htmlPath(String path) {
  return path.toLowerCase().endsWith('.html') ? path : '$path.html';
}
