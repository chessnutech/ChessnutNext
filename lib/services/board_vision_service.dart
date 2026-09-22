import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

export 'board_vision_recognizer.dart';

enum BoardVisionImageSource { gallery, camera }

class BoardVisionImage {
  const BoardVisionImage({required this.bytes});

  final List<int> bytes;
}

class BoardVisionFenResult {
  const BoardVisionFenResult({
    required this.fen,
    required this.confidence,
    required this.source,
  });

  final String fen;
  final double confidence;
  final String source;
}

class BoardVisionSourceAvailability {
  const BoardVisionSourceAvailability({
    required this.gallery,
    required this.camera,
  });

  final bool gallery;
  final bool camera;

  bool get any => gallery || camera;
}

abstract class BoardVisionImagePicker {
  BoardVisionSourceAvailability availability({required bool isChessnutClock});

  Future<BoardVisionImage?> pick(BoardVisionImageSource source);
}

class PlatformBoardVisionImagePicker implements BoardVisionImagePicker {
  PlatformBoardVisionImagePicker({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  BoardVisionSourceAvailability availability({required bool isChessnutClock}) {
    if (kIsWeb) {
      return const BoardVisionSourceAvailability(
        gallery: false,
        camera: false,
      );
    }
    final mobile = Platform.isAndroid || Platform.isIOS;
    return BoardVisionSourceAvailability(
      gallery: true,
      camera: mobile && !isChessnutClock,
    );
  }

  @override
  Future<BoardVisionImage?> pick(BoardVisionImageSource source) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final imageSource = source == BoardVisionImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery;
      final picked = await _imagePicker.pickImage(
        source: imageSource,
      );
      if (picked == null) return null;
      final bytes = await picked.readAsBytes();
      return BoardVisionImage(bytes: bytes);
    }

    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Images',
          extensions: ['jpg', 'jpeg', 'png', 'webp'],
          mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
        ),
      ],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return BoardVisionImage(bytes: bytes);
  }
}
