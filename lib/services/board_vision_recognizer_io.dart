import 'package:flutter/foundation.dart';
import 'package:vision/vision.dart' as vision;

import 'board_vision_recognizer_base.dart';

class PlatformBoardVisionFenRecognizer implements BoardVisionFenRecognizer {
  static bool _initialized = false;

  @override
  Future<String?> recognizeFen(List<int> imageBytes) async {
    if (kIsWeb) return null;
    _ensureInitialized();
    final bytes =
        imageBytes is Uint8List ? imageBytes : Uint8List.fromList(imageBytes);
    final fen = await vision.detectImageFile2Fen(bytes);
    return _normalizeFen(fen);
  }

  @override
  Future<String?> recognizeJson(List<int> imageBytes) async {
    if (kIsWeb) return null;
    _ensureInitialized();
    final bytes =
        imageBytes is Uint8List ? imageBytes : Uint8List.fromList(imageBytes);
    return _normalizeJson(await vision.detectImageFile2Json(bytes));
  }

  void _ensureInitialized() {
    if (_initialized) return;
    vision.yolov5ncnnInit();
    _initialized = true;
  }
}

String? _normalizeFen(String? fen) {
  final trimmed = fen?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

String? _normalizeJson(String? json) {
  final trimmed = json?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
