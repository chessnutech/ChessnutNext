import 'package:flutter/foundation.dart';

enum CommentaryTtsPreparationState { downloading, installing, ready, failed }

class CommentaryTtsPreparationStatus {
  const CommentaryTtsPreparationStatus({
    required this.state,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.errorMessage = '',
  });

  final CommentaryTtsPreparationState state;
  final int downloadedBytes;
  final int? totalBytes;
  final String errorMessage;

  double? get progress => null;
}

final ValueNotifier<Map<String, CommentaryTtsPreparationStatus>>
    commentaryTtsPreparationStatuses =
    ValueNotifier<Map<String, CommentaryTtsPreparationStatus>>(const {});

String resolveCommentaryTtsLanguage({
  required String text,
  String language = '',
}) {
  final normalized = language.trim().replaceAll('_', '-').toLowerCase();
  return normalized.isEmpty ? 'en' : normalized.split('-').first;
}

bool commentaryTtsSupportsMaleVoice(String language) => false;

class CommentaryTtsAudioPath {
  const CommentaryTtsAudioPath(this.path);

  final String path;
}

class CommentaryTtsCacheService {
  CommentaryTtsCacheService._();

  static final CommentaryTtsCacheService shared = CommentaryTtsCacheService._();

  Future<CommentaryTtsAudioPath> getOrCreate({
    required String text,
    String language = '',
    String coachId = 'default',
    String voice = 'amy',
    String style = 'default',
  }) {
    return Future<CommentaryTtsAudioPath>.error(
      UnsupportedError('Local commentary speech is unavailable on the web.'),
    );
  }
}
