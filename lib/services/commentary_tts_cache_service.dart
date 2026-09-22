import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

const String commentaryTtsModelVersion =
    'vits-piper-en_US-amy-low-int8-93070ac9fadf';
const String commentaryTtsModelAsset =
    'assets/tts/vits-piper-en_US-amy-low-int8.tar.bz2';
const String commentaryTtsModelArchiveSha256 =
    '93070ac9fadf512e56c46bdd0c5d2ce96b424fdc4e683d560167410bd2c4df7d';
const String _commentaryTtsReleaseBaseUrl =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/';

enum CommentaryTtsModelEngine { vits, supertonic }

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

  double? get progress {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (downloadedBytes / total).clamp(0, 1).toDouble();
  }
}

final ValueNotifier<Map<String, CommentaryTtsPreparationStatus>>
    commentaryTtsPreparationStatuses =
    ValueNotifier<Map<String, CommentaryTtsPreparationStatus>>(const {});

void _updateCommentaryTtsPreparationStatus(
  String language,
  CommentaryTtsPreparationStatus status,
) {
  final previous = commentaryTtsPreparationStatuses.value[language];
  if (previous?.state == CommentaryTtsPreparationState.downloading &&
      status.state == CommentaryTtsPreparationState.downloading &&
      previous?.totalBytes == status.totalBytes &&
      status.downloadedBytes < (status.totalBytes ?? -1) &&
      (status.downloadedBytes - (previous?.downloadedBytes ?? 0)).abs() <
          256 * 1024) {
    return;
  }
  commentaryTtsPreparationStatuses.value = {
    ...commentaryTtsPreparationStatuses.value,
    language: status,
  };
}

class CommentaryTtsModelSpec {
  const CommentaryTtsModelSpec({
    required this.modelVersion,
    required this.archiveRootName,
    required this.modelFileName,
    required this.archiveSha256,
    this.engine = CommentaryTtsModelEngine.vits,
    this.assetPath = '',
    this.downloadUrl = '',
    this.lexiconFileName = '',
    this.dataDirectoryName = 'espeak-ng-data',
    this.ruleFstFileNames = const <String>[],
    this.downloadFiles = const <CommentaryTtsDownloadFile>[],
    this.speakerId = 0,
  });

  final String modelVersion;
  final String archiveRootName;
  final String modelFileName;
  final String archiveSha256;
  final CommentaryTtsModelEngine engine;
  final String assetPath;
  final String downloadUrl;
  final String lexiconFileName;
  final String dataDirectoryName;
  final List<String> ruleFstFileNames;
  final List<CommentaryTtsDownloadFile> downloadFiles;
  final int speakerId;
}

class CommentaryTtsDownloadFile {
  const CommentaryTtsDownloadFile({
    required this.fileName,
    required this.url,
    required this.sha256,
  });

  final String fileName;
  final String url;
  final String sha256;
}

const _englishTtsModel = CommentaryTtsModelSpec(
  modelVersion: commentaryTtsModelVersion,
  archiveRootName: 'vits-piper-en_US-amy-low-int8',
  modelFileName: 'en_US-amy-low.onnx',
  archiveSha256: commentaryTtsModelArchiveSha256,
  assetPath: commentaryTtsModelAsset,
);

const _supertonicFemaleTtsModel = CommentaryTtsModelSpec(
  modelVersion: 'supertonic-3-tts-int8-2026-05-11-82fa96f91c4e',
  archiveRootName: 'sherpa-onnx-supertonic-3-tts-int8-2026-05-11',
  modelFileName: '',
  archiveSha256:
      '82fa96f91c4ef8abaae3a14a3f4153facf88bed821d1f7331cec2700f432c427',
  engine: CommentaryTtsModelEngine.supertonic,
  downloadUrl:
      '${_commentaryTtsReleaseBaseUrl}sherpa-onnx-supertonic-3-tts-int8-2026-05-11.tar.bz2',
  dataDirectoryName: '',
  speakerId: 0,
);

const _supertonicMaleTtsModel = CommentaryTtsModelSpec(
  modelVersion: 'supertonic-3-tts-int8-2026-05-11-82fa96f91c4e',
  archiveRootName: 'sherpa-onnx-supertonic-3-tts-int8-2026-05-11',
  modelFileName: '',
  archiveSha256:
      '82fa96f91c4ef8abaae3a14a3f4153facf88bed821d1f7331cec2700f432c427',
  engine: CommentaryTtsModelEngine.supertonic,
  downloadUrl:
      '${_commentaryTtsReleaseBaseUrl}sherpa-onnx-supertonic-3-tts-int8-2026-05-11.tar.bz2',
  dataDirectoryName: '',
  // The official voice.bin is ordered F1..F5, then M1..M5.
  speakerId: 5,
);

const _femaleTtsModels = <String, CommentaryTtsModelSpec>{
  'en': _englishTtsModel,
  'zh-Hans': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-zh_CN-xiao_ya-medium-int8-eab027e194e7',
    archiveRootName: 'vits-piper-zh_CN-xiao_ya-medium-int8',
    modelFileName: 'zh_CN-xiao_ya-medium.onnx',
    archiveSha256:
        'eab027e194e70289233cf12308373611fa4e2e96ef2d97354ef433ab663d831f',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-zh_CN-xiao_ya-medium-int8.tar.bz2',
    lexiconFileName: 'lexicon.txt',
    dataDirectoryName: '',
    ruleFstFileNames: <String>['date.fst', 'number.fst'],
  ),
  'yue-HK': CommentaryTtsModelSpec(
    modelVersion: 'vits-cantonese-hf-xiaomaiiwn-bf3013cd4be3',
    archiveRootName: 'vits-cantonese-hf-xiaomaiiwn',
    modelFileName: 'vits-cantonese-hf-xiaomaiiwn.onnx',
    archiveSha256:
        'bf3013cd4be34f531b7e514e708d835584dd60c9ad6eaf467ac1402005c04e46',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-cantonese-hf-xiaomaiiwn.tar.bz2',
    lexiconFileName: 'lexicon.txt',
    dataDirectoryName: '',
    ruleFstFileNames: <String>['rule.fst'],
  ),
  'de': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-de_DE-kerstin-low-int8-bcd803966794',
    archiveRootName: 'vits-piper-de_DE-kerstin-low-int8',
    modelFileName: 'de_DE-kerstin-low.onnx',
    archiveSha256:
        'bcd8039667940cf2efc939b844f4b33d0823096572fcc1a8caaa2faa77f3379c',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-de_DE-kerstin-low-int8.tar.bz2',
  ),
  'es': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-es_AR-daniela-high-int8-7218f0a119e4',
    archiveRootName: 'vits-piper-es_AR-daniela-high-int8',
    modelFileName: 'es_AR-daniela-high.onnx',
    archiveSha256:
        '7218f0a119e4c16533ac187f71ab3019f2092f1594e43fef8392ae1f5b64abab',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-es_AR-daniela-high-int8.tar.bz2',
  ),
  'fr': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-fr_FR-siwis-low-int8-c001d38068a3',
    archiveRootName: 'vits-piper-fr_FR-siwis-low-int8',
    modelFileName: 'fr_FR-siwis-low.onnx',
    archiveSha256:
        'c001d38068a316c93601a7d10d0b983c9e61adf2af0c4533595483c7f6cba614',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-fr_FR-siwis-low-int8.tar.bz2',
  ),
  'it': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-it_IT-paola-medium-int8-2b975ed30539',
    archiveRootName: 'vits-piper-it_IT-paola-medium-int8',
    modelFileName: 'it_IT-paola-medium.onnx',
    archiveSha256:
        '2b975ed305391c056944a4dde67ee754dd824099503a860295bb4c1d724662d8',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-it_IT-paola-medium-int8.tar.bz2',
  ),
  'ja': _supertonicFemaleTtsModel,
  'ko': CommentaryTtsModelSpec(
    modelVersion: 'vits-mimic3-ko_KO-kss_low-f015d1d15a52',
    archiveRootName: 'vits-mimic3-ko_KO-kss_low',
    modelFileName: 'ko_KO-kss_low.onnx',
    archiveSha256:
        'f015d1d15a52ed00d6fe22757c5ef4a74283c53daf829c838fa5c22616ed789c',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-mimic3-ko_KO-kss_low.tar.bz2',
  ),
  'nl': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-nl_BE-nathalie-medium-int8-f2cdeb555eac',
    archiveRootName: 'vits-piper-nl_BE-nathalie-medium-int8',
    modelFileName: 'nl_BE-nathalie-medium.onnx',
    archiveSha256:
        'f2cdeb555eacbdd053e5d63c4d0120464161a962f9fe3bf9aac47ecc57ac90ac',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-nl_BE-nathalie-medium-int8.tar.bz2',
  ),
  'pt': _supertonicFemaleTtsModel,
  'pl': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-pl_PL-gosia-medium-int8-72acac4c4b03',
    archiveRootName: 'vits-piper-pl_PL-gosia-medium-int8',
    modelFileName: 'pl_PL-gosia-medium.onnx',
    archiveSha256:
        '72acac4c4b031725c41a61b3af0314a3d30e1ec2cd83ee410ea5f9e6d2d9d4fb',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-pl_PL-gosia-medium-int8.tar.bz2',
  ),
  'ro': _supertonicFemaleTtsModel,
  'cs': _supertonicFemaleTtsModel,
  'ar': _supertonicFemaleTtsModel,
  'he': CommentaryTtsModelSpec(
    // facebook/mms-tts-heb (CC BY-NC 4.0), converted for Sherpa ONNX by
    // thewh1teagle. The app downloads the pinned files only when Hebrew TTS
    // is requested; attribution and license terms are included in assets.
    modelVersion: 'vits-mms-tts-heb-sherpa-05e62b666d62',
    archiveRootName: 'vits-mms-tts-heb-sherpa',
    modelFileName: 'model_sherpa.onnx',
    archiveSha256: '',
    dataDirectoryName: '',
    downloadFiles: <CommentaryTtsDownloadFile>[
      CommentaryTtsDownloadFile(
        fileName: 'model_sherpa.onnx',
        url:
            'https://huggingface.co/thewh1teagle/mms-tts-heb/resolve/05e62b666d6283052c8c110165228701e6264f29/model_sherpa.onnx',
        sha256:
            '50e7ba823907852e1b1cd71c62aa7dbf32098265a7d43f917d77a8b462af09fa',
      ),
      CommentaryTtsDownloadFile(
        fileName: 'tokens.txt',
        url:
            'https://huggingface.co/thewh1teagle/mms-tts-heb/resolve/05e62b666d6283052c8c110165228701e6264f29/tokens.txt',
        sha256:
            'd376b756ea9f18037316c20fe16ed041e86153f31bb53dd4ac98c5fe89cf0b4c',
      ),
    ],
  ),
  'ru': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-ru_RU-irina-medium-int8-b0000a509f75',
    archiveRootName: 'vits-piper-ru_RU-irina-medium-int8',
    modelFileName: 'ru_RU-irina-medium.onnx',
    archiveSha256:
        'b0000a509f7551a80742eed5c43b8eb03f469cb9f0a42f6feee96ce0da0ebab8',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-ru_RU-irina-medium-int8.tar.bz2',
  ),
};

const _maleTtsModels = <String, CommentaryTtsModelSpec>{
  'zh-Hans': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-zh_CN-chaowen-medium-int8-f5f7c8628427',
    archiveRootName: 'vits-piper-zh_CN-chaowen-medium-int8',
    modelFileName: 'zh_CN-chaowen-medium.onnx',
    archiveSha256:
        'f5f7c8628427fbb259ea4b7ec1a9a822a0c04e3f267071f0abfa0610371d9e0c',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-zh_CN-chaowen-medium-int8.tar.bz2',
    lexiconFileName: 'lexicon.txt',
    dataDirectoryName: '',
    ruleFstFileNames: <String>['date.fst', 'number.fst', 'phone.fst'],
  ),
  // The upstream Piper model card explicitly identifies John as a US English
  // male voice.
  'en': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-en_US-john-medium-int8-2ea2f6cf88bb',
    archiveRootName: 'vits-piper-en_US-john-medium-int8',
    modelFileName: 'en_US-john-medium.onnx',
    archiveSha256:
        '2ea2f6cf88bba033be71c941d00cd4d2af35d23655b5d68b7fe8239d519f17b4',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-en_US-john-medium-int8.tar.bz2',
  ),
  'de': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-de_DE-thorsten-medium-int8-07e240b7b9c1',
    archiveRootName: 'vits-piper-de_DE-thorsten-medium-int8',
    modelFileName: 'de_DE-thorsten-medium.onnx',
    archiveSha256:
        '07e240b7b9c1fc9211d5a69512f8cbe11b3286c2ed79c15c076ac6ed427fdf13',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-de_DE-thorsten-medium-int8.tar.bz2',
  ),
  'es': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-es_ES-davefx-medium-int8-8bb8ac1cefb7',
    archiveRootName: 'vits-piper-es_ES-davefx-medium-int8',
    modelFileName: 'es_ES-davefx-medium.onnx',
    archiveSha256:
        '8bb8ac1cefb727caec9bd9c6c3185c673c8b42c53bd29bb25d5a7715dac37125',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-es_ES-davefx-medium-int8.tar.bz2',
  ),
  'fr': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-fr_FR-gilles-low-int8-92d2bfd9b6b3',
    archiveRootName: 'vits-piper-fr_FR-gilles-low-int8',
    modelFileName: 'fr_FR-gilles-low.onnx',
    archiveSha256:
        '92d2bfd9b6b32b9787557c466b15620e453aecc10ec521762660e034941b3c43',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-fr_FR-gilles-low-int8.tar.bz2',
  ),
  'it': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-it_IT-riccardo-x_low-int8-afc2ea457fd4',
    archiveRootName: 'vits-piper-it_IT-riccardo-x_low-int8',
    modelFileName: 'it_IT-riccardo-x_low.onnx',
    archiveSha256:
        'afc2ea457fd45420dbdd87db4b3927b4fc97b00511964d474bb43e03092d37c1',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-it_IT-riccardo-x_low-int8.tar.bz2',
  ),
  'ja': _supertonicMaleTtsModel,
  'ko': _supertonicMaleTtsModel,
  'nl': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-nl_NL-ronnie-medium-int8-eb16022c9c8e',
    archiveRootName: 'vits-piper-nl_NL-ronnie-medium-int8',
    modelFileName: 'nl_NL-ronnie-medium.onnx',
    archiveSha256:
        'eb16022c9c8ee48b75dc833e8a8b04e08730929ea68cde9b67e2dc712f988978',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-nl_NL-ronnie-medium-int8.tar.bz2',
  ),
  'pt': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-pt_PT-tugao-medium-int8-8f4c5e4a5994',
    archiveRootName: 'vits-piper-pt_PT-tugao-medium-int8',
    modelFileName: 'pt_PT-tugao-medium.onnx',
    archiveSha256:
        '8f4c5e4a5994d0d1a2c10fb3035631add0460ea5c776f5ea40d3d6051140dbc3',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-pt_PT-tugao-medium-int8.tar.bz2',
  ),
  // The upstream Piper model card explicitly identifies Bass as a Polish
  // male voice.
  'pl': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-pl_PL-bass-high-int8-e6667ea284c1',
    archiveRootName: 'vits-piper-pl_PL-bass-high-int8',
    modelFileName: 'pl_PL-bass-high.onnx',
    archiveSha256:
        'e6667ea284c15b90e5fd6350b8005a0a4d7c1ce1cc1ce647ee64d2650a57a12f',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-pl_PL-bass-high-int8.tar.bz2',
  ),
  'ro': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-ro_RO-mihai-medium-int8-1f41b684fb46',
    archiveRootName: 'vits-piper-ro_RO-mihai-medium-int8',
    modelFileName: 'ro_RO-mihai-medium.onnx',
    archiveSha256:
        '1f41b684fb4640d1b79f750f1581647f8737b24ff5daf8d7c5fd5ad6d1761499',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-ro_RO-mihai-medium-int8.tar.bz2',
  ),
  'cs': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-cs_CZ-jirka-medium-int8-45377b35ce82',
    archiveRootName: 'vits-piper-cs_CZ-jirka-medium-int8',
    modelFileName: 'cs_CZ-jirka-medium.onnx',
    archiveSha256:
        '45377b35ce823eaac5d76a5530b48fb5ad386a4e07db6ff36aa7c417d6bd0a6d',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-cs_CZ-jirka-medium-int8.tar.bz2',
  ),
  'ar': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-ar_JO-kareem-medium-int8-215910431bbe',
    archiveRootName: 'vits-piper-ar_JO-kareem-medium-int8',
    modelFileName: 'ar_JO-kareem-medium.onnx',
    archiveSha256:
        '215910431bbe8236b77242b19d869a4eda6073e9cd424bec45b6d4a59a790d82',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-ar_JO-kareem-medium-int8.tar.bz2',
  ),
  'ru': CommentaryTtsModelSpec(
    modelVersion: 'vits-piper-ru_RU-denis-medium-int8-d710e29eb785',
    archiveRootName: 'vits-piper-ru_RU-denis-medium-int8',
    modelFileName: 'ru_RU-denis-medium.onnx',
    archiveSha256:
        'd710e29eb7854c42461d16d65d3cef753cc559639ca75806edc75ba71f23af66',
    downloadUrl:
        '${_commentaryTtsReleaseBaseUrl}vits-piper-ru_RU-denis-medium-int8.tar.bz2',
  ),
};

/// A replaceable audio generator used by [CommentaryTtsCacheService].
///
/// Tests can inject a lightweight implementation without loading the native
/// Sherpa ONNX runtime or the packaged voice model.
abstract class CommentaryTtsAudioGenerator {
  String get modelVersion => commentaryTtsModelVersion;

  String modelVersionForLanguage(String language, {String voice = 'female'}) =>
      modelVersion;

  Future<void> generate({
    required String text,
    required String language,
    required String coachId,
    required String voice,
    required String style,
    required File outputFile,
  });

  Future<void> dispose() async {}
}

/// Produces and persistently caches commentary speech WAV files.
///
/// The cache key includes every input that can affect speech output. Concurrent
/// callers requesting the same speech share one generation future. A failed
/// generation is not cached and can be retried by the next call.
class CommentaryTtsCacheService {
  CommentaryTtsCacheService({
    CommentaryTtsAudioGenerator? generator,
    Directory? cacheDirectory,
    Future<Directory> Function()? supportDirectoryProvider,
    String? modelVersion,
  })  : _generator = generator ?? SherpaOnnxCommentaryTtsGenerator(),
        _cacheDirectory = cacheDirectory,
        _supportDirectoryProvider =
            supportDirectoryProvider ?? getApplicationSupportDirectory,
        _modelVersionOverride = modelVersion;

  static final CommentaryTtsCacheService shared = CommentaryTtsCacheService();

  final CommentaryTtsAudioGenerator _generator;
  final Directory? _cacheDirectory;
  final Future<Directory> Function() _supportDirectoryProvider;
  final String? _modelVersionOverride;
  final Map<String, Future<File>> _inFlight = <String, Future<File>>{};

  static int _temporaryFileSerial = 0;

  Future<File> getOrCreate({
    required String text,
    String language = '',
    String coachId = 'default',
    String voice = 'amy',
    String style = 'default',
  }) {
    final request = _CommentaryTtsRequest.normalized(
      text: text,
      language: language,
      coachId: coachId,
      voice: voice,
      style: style,
    );
    final modelVersion = _modelVersionOverride ??
        _generator.modelVersionForLanguage(
          request.language,
          voice: request.voice,
        );
    final cacheKey = _cacheKey(request, modelVersion);
    final existing = _inFlight[cacheKey];
    if (existing != null) return existing;

    late final Future<File> pending;
    pending = _loadOrGenerate(cacheKey, modelVersion, request).whenComplete(() {
      if (identical(_inFlight[cacheKey], pending)) {
        _inFlight.remove(cacheKey);
      }
    });
    _inFlight[cacheKey] = pending;
    return pending;
  }

  Future<void> dispose() => _generator.dispose();

  String _cacheKey(
    _CommentaryTtsRequest request,
    String modelVersion,
  ) {
    final canonical = jsonEncode(<String, Object>{
      // Bump the cache schema when the generated waveform processing changes.
      // This prevents previously quiet WAV files from being reused.
      'schema': 4,
      'model': modelVersion,
      'text': request.text,
      'language': request.language,
      'coach': request.coachId,
      'voice': request.voice,
      'style': request.style,
    });
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  Future<File> _loadOrGenerate(
    String cacheKey,
    String modelVersion,
    _CommentaryTtsRequest request,
  ) async {
    final cacheRoot = _cacheDirectory ?? await _defaultCacheDirectory();
    final versionDirectory = Directory(
      _join(cacheRoot.path, _modelCacheDirectoryName(modelVersion)),
    );
    final outputFile = File(_join(versionDirectory.path, '$cacheKey.wav'));
    if (await _isUsableWaveFile(outputFile)) return outputFile;

    await versionDirectory.create(recursive: true);
    final serial = _temporaryFileSerial++;
    final temporaryFile = File(
      '${outputFile.path}.${pid}_${DateTime.now().microsecondsSinceEpoch}_$serial.tmp',
    );

    try {
      await _generator.generate(
        text: request.text,
        language: request.language,
        coachId: request.coachId,
        voice: request.voice,
        style: request.style,
        outputFile: temporaryFile,
      );
      if (!await _isUsableWaveFile(temporaryFile)) {
        throw StateError('Sherpa ONNX did not produce a valid WAV file.');
      }

      // A second service instance may have completed the same file while this
      // one was generating. Prefer the already published complete file.
      if (await _isUsableWaveFile(outputFile)) {
        await _deleteIfPresent(temporaryFile);
        return outputFile;
      }
      if (await outputFile.exists()) await outputFile.delete();

      try {
        return await temporaryFile.rename(outputFile.path);
      } on FileSystemException {
        if (await _isUsableWaveFile(outputFile)) {
          await _deleteIfPresent(temporaryFile);
          return outputFile;
        }
        rethrow;
      }
    } catch (_) {
      await _deleteIfPresent(temporaryFile);
      rethrow;
    }
  }

  Future<Directory> _defaultCacheDirectory() async {
    final support = await _supportDirectoryProvider();
    return Directory(_join(support.path, 'commentary_tts_cache'));
  }
}

class _CommentaryTtsRequest {
  const _CommentaryTtsRequest({
    required this.text,
    required this.language,
    required this.coachId,
    required this.voice,
    required this.style,
  });

  factory _CommentaryTtsRequest.normalized({
    required String text,
    required String language,
    required String coachId,
    required String voice,
    required String style,
  }) {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw const FormatException('Commentary speech text cannot be empty.');
    }
    return _CommentaryTtsRequest(
      text: normalizedText,
      language: resolveCommentaryTtsLanguage(
        text: normalizedText,
        language: language,
      ),
      coachId: _normalizeDimension(coachId, fallback: 'default'),
      voice: _normalizeDimension(voice, fallback: 'amy'),
      style: _normalizeDimension(style, fallback: 'default'),
    );
  }

  final String text;
  final String language;
  final String coachId;
  final String voice;
  final String style;
}

/// Default generator backed by a long-lived Sherpa ONNX worker isolate.
///
/// Model extraction and native runtime initialization happen only for the first
/// uncached request. Keeping generation on a worker isolate avoids blocking
/// Flutter animations while a new commentary clip is synthesized.
class SherpaOnnxCommentaryTtsGenerator extends CommentaryTtsAudioGenerator {
  SherpaOnnxCommentaryTtsGenerator({
    CommentaryTtsModelInstaller? modelInstaller,
    this.numThreads = 2,
    this.nativeLibraryDirectory,
  }) : _customEnglishInstaller = modelInstaller;

  final CommentaryTtsModelInstaller? _customEnglishInstaller;
  final int numThreads;
  final String? nativeLibraryDirectory;
  final Map<String, CommentaryTtsModelInstaller> _installers = {};
  final Map<String, Future<_SherpaTtsWorker>> _workerFutures = {};
  bool _disposed = false;

  @override
  String modelVersionForLanguage(String language, {String voice = 'female'}) {
    final normalized = normalizeCommentaryTtsLanguage(language);
    final spec = _modelSpecForLanguage(normalized, voice: voice);
    return spec?.modelVersion ?? 'sherpa-onnx-unconfigured-$normalized';
  }

  @override
  Future<void> generate({
    required String text,
    required String language,
    required String coachId,
    required String voice,
    required String style,
    required File outputFile,
  }) async {
    if (_disposed) {
      throw StateError('The commentary TTS generator has been disposed.');
    }
    final normalizedLanguage = normalizeCommentaryTtsLanguage(language);
    final spec = _modelSpecForLanguage(normalizedLanguage, voice: voice);
    if (spec == null) {
      throw UnsupportedError(
        'No Sherpa ONNX commentary TTS model is configured for '
        '$normalizedLanguage.',
      );
    }
    final worker = await _worker(spec, normalizedLanguage);
    await worker.generate(
      text: text,
      speakerId: spec.speakerId,
      speed: _speechSpeed(style: style, coachId: coachId),
      outputPath: outputFile.path,
    );
  }

  Future<_SherpaTtsWorker> _worker(
    CommentaryTtsModelSpec spec,
    String language,
  ) async {
    final workerKey = '${spec.modelVersion}:$language';
    final existing = _workerFutures[workerKey];
    if (existing != null) return existing;

    final pending = _startWorker(spec, language);
    _workerFutures[workerKey] = pending;
    try {
      return await pending;
    } catch (_) {
      if (identical(_workerFutures[workerKey], pending)) {
        _workerFutures.remove(workerKey);
      }
      rethrow;
    }
  }

  Future<_SherpaTtsWorker> _startWorker(
    CommentaryTtsModelSpec spec,
    String language,
  ) async {
    try {
      final installer = _installerFor(spec, language);
      final model = await installer.install();
      _updateCommentaryTtsPreparationStatus(
        language,
        const CommentaryTtsPreparationStatus(
          state: CommentaryTtsPreparationState.installing,
        ),
      );
      final worker = await _SherpaTtsWorker.start(
        model: model,
        language: language,
        numThreads: numThreads,
        nativeLibraryDirectory: nativeLibraryDirectory,
      );
      _updateCommentaryTtsPreparationStatus(
        language,
        const CommentaryTtsPreparationStatus(
          state: CommentaryTtsPreparationState.ready,
        ),
      );
      return worker;
    } catch (error) {
      _updateCommentaryTtsPreparationStatus(
        language,
        CommentaryTtsPreparationStatus(
          state: CommentaryTtsPreparationState.failed,
          errorMessage: _readableCommentaryTtsError(error),
        ),
      );
      rethrow;
    }
  }

  CommentaryTtsModelInstaller _installerFor(
    CommentaryTtsModelSpec spec,
    String language,
  ) {
    if (identical(spec, _englishTtsModel) && _customEnglishInstaller != null) {
      return _customEnglishInstaller;
    }
    return _installers.putIfAbsent(
      spec.modelVersion,
      () => CommentaryTtsModelInstaller(
        assetPath: spec.assetPath,
        downloadUri:
            spec.downloadUrl.isEmpty ? null : Uri.parse(spec.downloadUrl),
        archiveSha256: spec.archiveSha256,
        modelVersion: spec.modelVersion,
        archiveRootName: spec.archiveRootName,
        modelFileName: spec.modelFileName,
        engine: spec.engine,
        lexiconFileName: spec.lexiconFileName,
        dataDirectoryName: spec.dataDirectoryName,
        ruleFstFileNames: spec.ruleFstFileNames,
        downloadFiles: spec.downloadFiles,
        onDownloadProgress: (downloadedBytes, totalBytes) {
          _updateCommentaryTtsPreparationStatus(
            language,
            CommentaryTtsPreparationStatus(
              state: CommentaryTtsPreparationState.downloading,
              downloadedBytes: downloadedBytes,
              totalBytes: totalBytes,
            ),
          );
        },
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final pendingWorkers = _workerFutures.values.toList(growable: false);
    _workerFutures.clear();
    for (final pending in pendingWorkers) {
      try {
        final worker = await pending;
        await worker.dispose();
      } catch (_) {
        // Initialization failures have no native worker left to release.
      }
    }
  }
}

/// Installs a packaged or remotely downloaded model into a filesystem directory.
///
/// Sherpa ONNX requires real paths, while Flutter assets are only accessible
/// through an [AssetBundle]. The verified archive is extracted into application
/// support storage and marked complete only after all required files exist.
class CommentaryTtsModelInstaller {
  CommentaryTtsModelInstaller({
    AssetBundle? assetBundle,
    http.Client? httpClient,
    Directory? installRoot,
    Future<Directory> Function()? supportDirectoryProvider,
    this.assetPath = commentaryTtsModelAsset,
    this.downloadUri,
    this.archiveSha256 = commentaryTtsModelArchiveSha256,
    this.modelVersion = commentaryTtsModelVersion,
    this.archiveRootName = 'vits-piper-en_US-amy-low-int8',
    this.modelFileName = 'en_US-amy-low.onnx',
    this.engine = CommentaryTtsModelEngine.vits,
    this.lexiconFileName = '',
    this.dataDirectoryName = 'espeak-ng-data',
    this.ruleFstFileNames = const <String>[],
    this.downloadFiles = const <CommentaryTtsDownloadFile>[],
    this.downloadInactivityTimeout = const Duration(seconds: 60),
    this.onDownloadProgress,
  })  : _assetBundle = assetBundle ?? rootBundle,
        _httpClient = httpClient ?? http.Client(),
        _installRoot = installRoot,
        _supportDirectoryProvider =
            supportDirectoryProvider ?? getApplicationSupportDirectory;

  final AssetBundle _assetBundle;
  final http.Client _httpClient;
  final Directory? _installRoot;
  final Future<Directory> Function() _supportDirectoryProvider;
  final String assetPath;
  final Uri? downloadUri;
  final String archiveSha256;
  final String modelVersion;
  final String archiveRootName;
  final String modelFileName;
  final CommentaryTtsModelEngine engine;
  final String lexiconFileName;
  final String dataDirectoryName;
  final List<String> ruleFstFileNames;
  final List<CommentaryTtsDownloadFile> downloadFiles;
  final Duration downloadInactivityTimeout;
  final void Function(int downloadedBytes, int? totalBytes)? onDownloadProgress;
  Future<CommentaryTtsModelFiles>? _installation;

  Future<CommentaryTtsModelFiles> install() {
    final existing = _installation;
    if (existing != null) return existing;

    final pending = _install();
    _installation = pending;
    unawaited(
      pending.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {
          // Keep successful installations memoized, but allow a later request
          // to retry after an interrupted asset copy or extraction.
          if (identical(_installation, pending)) _installation = null;
        },
      ),
    );
    return pending;
  }

  Future<CommentaryTtsModelFiles> _install() async {
    final baseDirectory = _installRoot ??
        Directory(
          _join(
            (await _supportDirectoryProvider()).path,
            'commentary_tts_models',
          ),
        );
    final installedDirectory = Directory(
      _join(baseDirectory.path, _modelCacheDirectoryName(modelVersion)),
    );
    final installed = CommentaryTtsModelFiles(
      installedDirectory,
      engine: engine,
      modelFileName: modelFileName,
      lexiconFileName: lexiconFileName,
      dataDirectoryName: dataDirectoryName,
      ruleFstFileNames: ruleFstFileNames,
    );
    if (await _isCompleteInstallation(installed)) return installed;

    await baseDirectory.create(recursive: true);
    final modelCacheName = _modelCacheDirectoryName(modelVersion);
    final unique = '${pid}_${DateTime.now().microsecondsSinceEpoch}';
    final stagingDirectory = Directory(
      _join(baseDirectory.path, '.installing_$unique'),
    );
    final archiveFile = File(
      _join(baseDirectory.path, '.$modelCacheName.partial.tar.bz2'),
    );

    try {
      await stagingDirectory.create(recursive: true);
      if (downloadFiles.isNotEmpty) {
        return await _installDownloadedFiles(
          baseDirectory: baseDirectory,
          installedDirectory: installedDirectory,
          installed: installed,
          stagingDirectory: stagingDirectory,
          modelCacheName: modelCacheName,
        );
      }
      await _adoptLegacyPartialDownload(baseDirectory, archiveFile);
      await _copyVerifiedArchive(archiveFile);
      onDownloadProgress?.call(
          await archiveFile.length(), await archiveFile.length());
      final archivePath = archiveFile.path;
      final stagingPath = stagingDirectory.path;
      await Isolate.run(
        () => extractFileToDisk(archivePath, stagingPath),
      );

      final extractedDirectory = Directory(
        _join(stagingDirectory.path, archiveRootName),
      );
      final extracted = CommentaryTtsModelFiles(
        extractedDirectory,
        engine: engine,
        modelFileName: modelFileName,
        lexiconFileName: lexiconFileName,
        dataDirectoryName: dataDirectoryName,
        ruleFstFileNames: ruleFstFileNames,
      );
      if (!await _hasRequiredModelFiles(extracted)) {
        throw StateError(
          'The commentary TTS archive is missing required model files.',
        );
      }
      await extracted.marker.writeAsString(
        _installationMarker,
        flush: true,
      );

      // Another installer may have won the race while extraction was running.
      if (await _isCompleteInstallation(installed)) return installed;
      if (await installedDirectory.exists()) {
        await installedDirectory.delete(recursive: true);
      }
      await extractedDirectory.rename(installedDirectory.path);
      if (!await _isCompleteInstallation(installed)) {
        throw StateError(
            'The commentary TTS model installation is incomplete.');
      }
      await _deleteIfPresent(archiveFile);
      return installed;
    } finally {
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
    }
  }

  Future<CommentaryTtsModelFiles> _installDownloadedFiles({
    required Directory baseDirectory,
    required Directory installedDirectory,
    required CommentaryTtsModelFiles installed,
    required Directory stagingDirectory,
    required String modelCacheName,
  }) async {
    final extractedDirectory = Directory(
      _join(stagingDirectory.path, archiveRootName),
    );
    await extractedDirectory.create(recursive: true);
    final partialFiles = <File>[];
    for (final source in downloadFiles) {
      final partial = File(
        _join(
            baseDirectory.path, '.$modelCacheName.${source.fileName}.partial'),
      );
      partialFiles.add(partial);
      await _downloadVerifiedFile(
        destination: partial,
        remoteUri: Uri.parse(source.url),
        expectedSha256: source.sha256,
      );
      await partial.copy(_join(extractedDirectory.path, source.fileName));
    }

    final extracted = CommentaryTtsModelFiles(
      extractedDirectory,
      engine: engine,
      modelFileName: modelFileName,
      lexiconFileName: lexiconFileName,
      dataDirectoryName: dataDirectoryName,
      ruleFstFileNames: ruleFstFileNames,
    );
    if (!await _hasRequiredModelFiles(extracted)) {
      throw StateError(
        'The commentary TTS download is missing required model files.',
      );
    }
    await extracted.marker.writeAsString(_installationMarker, flush: true);

    if (await _isCompleteInstallation(installed)) return installed;
    if (await installedDirectory.exists()) {
      await installedDirectory.delete(recursive: true);
    }
    await extractedDirectory.rename(installedDirectory.path);
    if (!await _isCompleteInstallation(installed)) {
      throw StateError('The commentary TTS model installation is incomplete.');
    }
    for (final partial in partialFiles) {
      await _deleteIfPresent(partial);
    }
    return installed;
  }

  Future<void> _adoptLegacyPartialDownload(
    Directory baseDirectory,
    File archiveFile,
  ) async {
    if (!modelVersion.startsWith('vits-mimic3-ko_KO-kss_low-')) return;
    if (await archiveFile.exists()) return;
    final candidates = <File>[];
    await for (final entity in baseDirectory.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (name.startsWith('.model_') && name.endsWith('.tar.bz2')) {
        candidates.add(entity);
      }
    }
    if (candidates.isEmpty) return;
    candidates.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
    final largest = candidates.first;
    try {
      await largest.rename(archiveFile.path);
    } on FileSystemException {
      await largest.copy(archiveFile.path);
    }
    for (final stale in candidates.skip(1)) {
      await _deleteIfPresent(stale);
    }
  }

  Future<void> _copyVerifiedArchive(File destination) async {
    final remoteUri = downloadUri;
    if (remoteUri == null) {
      if (assetPath.trim().isEmpty) {
        throw StateError('Commentary TTS model has no archive source.');
      }
      final data = await _assetBundle.load(assetPath);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await destination.writeAsBytes(bytes, flush: true);
    } else {
      await _downloadFile(destination: destination, remoteUri: remoteUri);
    }
    await _verifyDownloadedFile(destination, archiveSha256);
  }

  Future<void> _downloadVerifiedFile({
    required File destination,
    required Uri remoteUri,
    required String expectedSha256,
  }) async {
    await _downloadFile(destination: destination, remoteUri: remoteUri);
    await _verifyDownloadedFile(destination, expectedSha256);
  }

  Future<void> _downloadFile({
    required File destination,
    required Uri remoteUri,
  }) async {
    var automaticRetries = 0;
    while (true) {
      try {
        await _downloadFileOnce(
          destination: destination,
          remoteUri: remoteUri,
        );
        return;
      } on TimeoutException {
        if (automaticRetries >= 1) rethrow;
        automaticRetries++;
      }
    }
  }

  Future<void> _downloadFileOnce({
    required File destination,
    required Uri remoteUri,
  }) async {
    final existingBytes =
        await destination.exists() ? await destination.length() : 0;
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      'GET',
      remoteUri,
      abortTrigger: abort.future,
    );
    if (existingBytes > 0) {
      request.headers[HttpHeaders.rangeHeader] = 'bytes=$existingBytes-';
    }
    onDownloadProgress?.call(existingBytes, null);
    late final http.StreamedResponse response;
    try {
      response = await _httpClient.send(request).timeout(
        downloadInactivityTimeout,
        onTimeout: () {
          if (!abort.isCompleted) abort.complete();
          throw TimeoutException(
            'No response was received while downloading the voice model.',
            downloadInactivityTimeout,
          );
        },
      );
    } catch (_) {
      if (!abort.isCompleted) abort.complete();
      rethrow;
    }
    if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable &&
        existingBytes > 0) {
      onDownloadProgress?.call(existingBytes, existingBytes);
      return;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Unable to download commentary TTS model (${response.statusCode}).',
        uri: remoteUri,
      );
    }
    final resumed =
        response.statusCode == HttpStatus.partialContent && existingBytes > 0;
    final startBytes = resumed ? existingBytes : 0;
    final responseBytes = response.contentLength;
    final totalBytes = _contentRangeTotal(response.headers) ??
        (responseBytes == null ? null : startBytes + responseBytes);
    if (!resumed && existingBytes > 0) {
      await destination.writeAsBytes(const [], flush: true);
    }
    onDownloadProgress?.call(startBytes, totalBytes);
    final sink = destination.openWrite(
      mode: resumed ? FileMode.append : FileMode.write,
    );
    var downloadedBytes = startBytes;
    try {
      final downloadStream = response.stream.timeout(
        downloadInactivityTimeout,
        onTimeout: (sink) {
          if (!abort.isCompleted) abort.complete();
          sink.addError(
            TimeoutException(
              'No data was received while downloading the voice model.',
              downloadInactivityTimeout,
            ),
          );
          sink.close();
        },
      );
      await for (final chunk in downloadStream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        onDownloadProgress?.call(downloadedBytes, totalBytes);
      }
      await sink.flush();
      await sink.close();
    } catch (_) {
      if (!abort.isCompleted) abort.complete();
      await sink.close();
      rethrow;
    }
  }

  Future<void> _verifyDownloadedFile(
    File destination,
    String expectedSha256,
  ) async {
    final filePath = destination.path;
    final actualSha256 = await Isolate.run(() async {
      final digest = await sha256.bind(File(filePath).openRead()).first;
      return digest.toString();
    });
    if (actualSha256 != expectedSha256.toLowerCase()) {
      await _deleteIfPresent(destination);
      throw StateError(
        'Commentary TTS model checksum mismatch: expected '
        '$expectedSha256, got $actualSha256.',
      );
    }
  }

  String get _installationMarker => jsonEncode(<String, Object>{
        'modelVersion': modelVersion,
        'archiveSha256': archiveSha256.toLowerCase(),
        'engine': engine.name,
        if (downloadFiles.isNotEmpty)
          'downloadFiles': <String, String>{
            for (final file in downloadFiles)
              file.fileName: file.sha256.toLowerCase(),
          },
      });

  Future<bool> _isCompleteInstallation(CommentaryTtsModelFiles files) async {
    if (!await _hasRequiredModelFiles(files)) return false;
    if (!await files.marker.exists()) return false;
    try {
      return await files.marker.readAsString() == _installationMarker;
    } on FileSystemException {
      return false;
    }
  }
}

int? _contentRangeTotal(Map<String, String> headers) {
  final value = headers[HttpHeaders.contentRangeHeader]?.trim();
  if (value == null || value.isEmpty) return null;
  final separator = value.lastIndexOf('/');
  if (separator < 0 || separator == value.length - 1) return null;
  return int.tryParse(value.substring(separator + 1));
}

String _readableCommentaryTtsError(Object error) {
  if (error is TimeoutException ||
      error is SocketException ||
      error is HttpException) {
    return 'Voice model download failed. Check the network and retry.';
  }
  final text = error.toString();
  if (text.contains('checksum mismatch')) {
    return 'Voice model download was incomplete. Retry the download.';
  }
  if (text.contains('missing required model files') ||
      text.contains('installation is incomplete')) {
    return 'Voice model installation did not finish. Retry the download.';
  }
  return 'Voice preparation failed. Tap retry to try again.';
}

class CommentaryTtsModelFiles {
  CommentaryTtsModelFiles(
    this.directory, {
    this.engine = CommentaryTtsModelEngine.vits,
    this.modelFileName = 'en_US-amy-low.onnx',
    this.lexiconFileName = '',
    this.dataDirectoryName = 'espeak-ng-data',
    this.ruleFstFileNames = const <String>[],
  });

  final Directory directory;
  final CommentaryTtsModelEngine engine;
  final String modelFileName;
  final String lexiconFileName;
  final String dataDirectoryName;
  final List<String> ruleFstFileNames;

  File get model => File(_join(directory.path, modelFileName));
  File get tokens => File(_join(directory.path, 'tokens.txt'));
  File get durationPredictor =>
      File(_join(directory.path, 'duration_predictor.int8.onnx'));
  File get textEncoder => File(_join(directory.path, 'text_encoder.int8.onnx'));
  File get vectorEstimator =>
      File(_join(directory.path, 'vector_estimator.int8.onnx'));
  File get vocoder => File(_join(directory.path, 'vocoder.int8.onnx'));
  File get ttsJson => File(_join(directory.path, 'tts.json'));
  File get unicodeIndexer => File(_join(directory.path, 'unicode_indexer.bin'));
  File get voiceStyle => File(_join(directory.path, 'voice.bin'));
  File? get lexicon => lexiconFileName.isEmpty
      ? null
      : File(_join(directory.path, lexiconFileName));
  Directory? get dataDirectory => dataDirectoryName.isEmpty
      ? null
      : Directory(_join(directory.path, dataDirectoryName));
  List<File> get ruleFsts => ruleFstFileNames
      .map((name) => File(_join(directory.path, name)))
      .toList(growable: false);
  Directory get espeakData =>
      dataDirectory ?? Directory(_join(directory.path, 'espeak-ng-data'));
  File get marker => File(_join(directory.path, '.installed.json'));
}

class _SherpaTtsWorker {
  _SherpaTtsWorker() {
    _responseSubscription = _responses.listen(_handleResponse);
    _errorSubscription = _errors.listen(_handleError);
    _exitSubscription = _exits.listen((_) => _handleExit());
  }

  static Future<_SherpaTtsWorker> start({
    required CommentaryTtsModelFiles model,
    required String language,
    required int numThreads,
    String? nativeLibraryDirectory,
  }) async {
    final worker = _SherpaTtsWorker();
    try {
      worker._isolate = await Isolate.spawn<List<Object?>>(
        _sherpaTtsWorkerEntry,
        <Object?>[
          worker._responses.sendPort,
          model.engine.name,
          language,
          model.model.path,
          model.tokens.path,
          model.lexicon?.path ?? '',
          model.dataDirectory?.path ?? '',
          model.ruleFsts.map((file) => file.path).join(','),
          model.directory.path,
          numThreads,
          nativeLibraryDirectory,
        ],
        onError: worker._errors.sendPort,
        onExit: worker._exits.sendPort,
        errorsAreFatal: true,
        debugName: 'commentary-sherpa-tts',
      );
      await worker._ready.future;
      return worker;
    } catch (_) {
      await worker._closePorts();
      if (worker._isolate != null) {
        worker._isolate!.kill(priority: Isolate.immediate);
      }
      rethrow;
    }
  }

  final ReceivePort _responses = ReceivePort();
  final ReceivePort _errors = ReceivePort();
  final ReceivePort _exits = ReceivePort();
  final Completer<void> _ready = Completer<void>();
  final Completer<void> _disposeAcknowledged = Completer<void>();
  final Map<int, Completer<void>> _pending = <int, Completer<void>>{};
  late final StreamSubscription<Object?> _responseSubscription;
  late final StreamSubscription<Object?> _errorSubscription;
  late final StreamSubscription<Object?> _exitSubscription;
  Isolate? _isolate;
  SendPort? _commands;
  int _nextRequestId = 1;
  bool _closed = false;
  bool _expectedExit = false;

  Future<void> generate({
    required String text,
    required int speakerId,
    required double speed,
    required String outputPath,
  }) async {
    if (_closed || _commands == null) {
      throw StateError('The Sherpa ONNX commentary worker is not available.');
    }
    final id = _nextRequestId++;
    final completer = Completer<void>();
    _pending[id] = completer;
    _commands!.send(<String, Object>{
      'type': 'generate',
      'id': id,
      'text': text,
      'speakerId': speakerId,
      'speed': speed,
      'outputPath': outputPath,
    });
    return completer.future;
  }

  void _handleResponse(Object? message) {
    if (message is! Map) return;
    final type = message['type'];
    switch (type) {
      case 'ready':
        final port = message['port'];
        if (port is! SendPort) {
          _completeReadyError(
            StateError('Sherpa ONNX worker returned an invalid command port.'),
          );
          return;
        }
        _commands = port;
        if (!_ready.isCompleted) _ready.complete();
      case 'initError':
        _completeReadyError(_remoteError(message));
      case 'generated':
        final id = message['id'];
        if (id is! int) return;
        final completer = _pending.remove(id);
        if (completer == null || completer.isCompleted) return;
        if (message['ok'] == true) {
          completer.complete();
        } else {
          completer.completeError(_remoteError(message));
        }
      case 'disposed':
        if (!_disposeAcknowledged.isCompleted) {
          _disposeAcknowledged.complete();
        }
    }
  }

  void _handleError(Object? message) {
    final error = switch (message) {
      List<Object?> values when values.isNotEmpty => StateError(
          'Sherpa ONNX worker failed: ${values.first}\n'
          '${values.length > 1 ? values[1] : ''}',
        ),
      _ => StateError('Sherpa ONNX worker failed: $message'),
    };
    _completeReadyError(error);
    _failPending(error);
  }

  void _handleExit() {
    if (_expectedExit) return;
    final error =
        StateError('Sherpa ONNX commentary worker exited unexpectedly.');
    _completeReadyError(error);
    _failPending(error);
  }

  void _completeReadyError(Object error) {
    if (!_ready.isCompleted) _ready.completeError(error);
  }

  void _failPending(Object error) {
    final pending = _pending.values.toList(growable: false);
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) completer.completeError(error);
    }
  }

  StateError _remoteError(Map<dynamic, dynamic> message) {
    final error = message['error'] ?? 'Unknown native TTS error';
    final stack = message['stack'];
    return StateError(
      stack == null || '$stack'.isEmpty
          ? 'Sherpa ONNX TTS failed: $error'
          : 'Sherpa ONNX TTS failed: $error\n$stack',
    );
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    _expectedExit = true;
    final commands = _commands;
    if (commands != null) {
      commands.send(const <String, Object>{'type': 'dispose'});
      try {
        await _disposeAcknowledged.future.timeout(const Duration(seconds: 5));
      } catch (_) {
        // Kill below if the worker cannot acknowledge shutdown.
      }
    }
    _failPending(StateError('The Sherpa ONNX commentary worker was disposed.'));
    _isolate?.kill(priority: Isolate.immediate);
    await _closePorts();
  }

  Future<void> _closePorts() async {
    await _responseSubscription.cancel();
    await _errorSubscription.cancel();
    await _exitSubscription.cancel();
    _responses.close();
    _errors.close();
    _exits.close();
  }
}

Future<void> _sherpaTtsWorkerEntry(List<Object?> arguments) async {
  final replies = arguments[0]! as SendPort;
  final engine =
      CommentaryTtsModelEngine.values.byName(arguments[1]! as String);
  final language = arguments[2]! as String;
  final modelPath = arguments[3]! as String;
  final tokensPath = arguments[4]! as String;
  final lexiconPath = arguments[5]! as String;
  final dataDirectoryPath = arguments[6]! as String;
  final ruleFsts = arguments[7]! as String;
  final modelDirectoryPath = arguments[8]! as String;
  final numThreads = arguments[9]! as int;
  final nativeLibraryDirectory = arguments[10] as String?;
  final commands = ReceivePort();
  sherpa_onnx.OfflineTts? tts;

  try {
    sherpa_onnx.initBindings(nativeLibraryDirectory);
    final ttsModelConfig = switch (engine) {
      CommentaryTtsModelEngine.vits => sherpa_onnx.OfflineTtsModelConfig(
          vits: sherpa_onnx.OfflineTtsVitsModelConfig(
            model: modelPath,
            tokens: tokensPath,
            lexicon: lexiconPath,
            dataDir: dataDirectoryPath,
          ),
          numThreads: numThreads,
          debug: false,
          provider: 'cpu',
        ),
      CommentaryTtsModelEngine.supertonic => sherpa_onnx.OfflineTtsModelConfig(
          supertonic: sherpa_onnx.OfflineTtsSupertonicModelConfig(
            durationPredictor:
                _join(modelDirectoryPath, 'duration_predictor.int8.onnx'),
            textEncoder: _join(modelDirectoryPath, 'text_encoder.int8.onnx'),
            vectorEstimator:
                _join(modelDirectoryPath, 'vector_estimator.int8.onnx'),
            vocoder: _join(modelDirectoryPath, 'vocoder.int8.onnx'),
            ttsJson: _join(modelDirectoryPath, 'tts.json'),
            unicodeIndexer: _join(modelDirectoryPath, 'unicode_indexer.bin'),
            voiceStyle: _join(modelDirectoryPath, 'voice.bin'),
          ),
          numThreads: numThreads,
          debug: false,
          provider: 'cpu',
        ),
    };
    tts = sherpa_onnx.OfflineTts(
      sherpa_onnx.OfflineTtsConfig(
        model: ttsModelConfig,
        ruleFsts: ruleFsts,
      ),
    );
    replies.send(<String, Object>{
      'type': 'ready',
      'port': commands.sendPort,
    });

    await for (final Object? message in commands) {
      if (message is! Map) continue;
      final type = message['type'];
      if (type == 'dispose') break;
      if (type != 'generate') continue;

      final id = message['id'];
      if (id is! int) continue;
      try {
        final text = message['text']! as String;
        final speakerId = message['speakerId']! as int;
        final speed = message['speed']! as double;
        final audio = switch (engine) {
          CommentaryTtsModelEngine.vits => tts.generate(
              text: text,
              sid: speakerId,
              speed: speed,
            ),
          CommentaryTtsModelEngine.supertonic => tts.generateWithConfig(
              text: text,
              config: sherpa_onnx.OfflineTtsGenerationConfig(
                sid: speakerId,
                numSteps: 8,
                speed: speed,
                extra: <String, Object>{'lang': language},
              ),
            ),
        };
        if (audio.samples.isEmpty || audio.sampleRate <= 0) {
          throw StateError('Sherpa ONNX generated empty audio.');
        }
        final wroteWave = sherpa_onnx.writeWave(
          filename: message['outputPath']! as String,
          samples: _normalizeSpeechSamples(audio.samples),
          sampleRate: audio.sampleRate,
        );
        if (!wroteWave) {
          throw FileSystemException(
            'Sherpa ONNX could not write the generated WAV file.',
            message['outputPath']! as String,
          );
        }
        replies.send(<String, Object>{
          'type': 'generated',
          'id': id,
          'ok': true,
        });
      } catch (error, stackTrace) {
        replies.send(<String, Object>{
          'type': 'generated',
          'id': id,
          'ok': false,
          'error': '$error',
          'stack': '$stackTrace',
        });
      }
    }
  } catch (error, stackTrace) {
    replies.send(<String, Object>{
      'type': 'initError',
      'error': '$error',
      'stack': '$stackTrace',
    });
  } finally {
    commands.close();
    tts?.free();
    replies.send(const <String, Object>{'type': 'disposed'});
  }
}

Float32List _normalizeSpeechSamples(Float32List samples) {
  if (samples.isEmpty) return samples;

  // Keep this fixed during volume testing. The previous peak-based gain could
  // remain close to 1.0 when the generated waveform already reached the target
  // peak, which made the perceived volume change difficult to verify.
  const gain = 4.0;

  final normalized = Float32List(samples.length);
  for (var index = 0; index < samples.length; index += 1) {
    normalized[index] = (samples[index] * gain).clamp(-1.0, 1.0).toDouble();
  }
  return normalized;
}

double _speechSpeed({required String style, required String coachId}) {
  final normalized = style.isEmpty || style == 'default' ? coachId : style;
  return switch (normalized) {
    'deep' => 0.94,
    'rapid' => 1.08,
    'friendly' => 0.98,
    _ => 1.0,
  };
}

Future<bool> _hasRequiredModelFiles(CommentaryTtsModelFiles files) async {
  if (!await files.directory.exists()) {
    return false;
  }
  if (files.engine == CommentaryTtsModelEngine.supertonic) {
    final requiredFiles = <File>[
      files.durationPredictor,
      files.textEncoder,
      files.vectorEstimator,
      files.vocoder,
      files.ttsJson,
      files.unicodeIndexer,
      files.voiceStyle,
    ];
    for (final file in requiredFiles) {
      if (!await file.exists() || await file.length() == 0) return false;
    }
    return true;
  }
  if (!await files.model.exists() || !await files.tokens.exists()) return false;
  final lexicon = files.lexicon;
  if (lexicon != null &&
      (!await lexicon.exists() || await lexicon.length() == 0)) {
    return false;
  }
  final dataDirectory = files.dataDirectory;
  if (dataDirectory != null &&
      (!await dataDirectory.exists() ||
          !await dataDirectory.list().any((_) => true))) {
    return false;
  }
  for (final ruleFst in files.ruleFsts) {
    if (!await ruleFst.exists() || await ruleFst.length() == 0) return false;
  }
  return await files.model.length() > 0 && await files.tokens.length() > 0;
}

Future<bool> _isUsableWaveFile(File file) async {
  try {
    if (!await file.exists() || await file.length() <= 44) return false;
    final handle = await file.open();
    try {
      final header = await handle.read(12);
      return header.length == 12 &&
          _asciiEquals(header, 0, 'RIFF') &&
          _asciiEquals(header, 8, 'WAVE');
    } finally {
      await handle.close();
    }
  } on FileSystemException {
    return false;
  }
}

bool _asciiEquals(Uint8List bytes, int offset, String expected) {
  final codeUnits = expected.codeUnits;
  if (offset + codeUnits.length > bytes.length) return false;
  for (var index = 0; index < codeUnits.length; index += 1) {
    if (bytes[offset + index] != codeUnits[index]) return false;
  }
  return true;
}

Future<void> _deleteIfPresent(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // Best effort cleanup must not hide the original generation error.
  }
}

String _normalizeDimension(String value, {required String fallback}) {
  final normalized = value.trim().toLowerCase();
  return normalized.isEmpty ? fallback : normalized;
}

String resolveCommentaryTtsLanguage({
  required String text,
  String language = '',
}) {
  final explicit = normalizeCommentaryTtsLanguage(language);
  if (explicit.isNotEmpty) return explicit;
  return _detectCommentaryLanguage(text);
}

bool commentaryTtsSupportsMaleVoice(String language) {
  final normalized = normalizeCommentaryTtsLanguage(language);
  return _maleTtsModels.containsKey(normalized);
}

CommentaryTtsModelSpec? _modelSpecForLanguage(
  String language, {
  String voice = 'female',
}) {
  final normalized = normalizeCommentaryTtsLanguage(language);
  if (voice.trim().toLowerCase() == 'male') {
    final male = _maleTtsModels[normalized];
    if (male != null) return male;
  }
  return _femaleTtsModels[normalized];
}

String normalizeCommentaryTtsLanguage(String language) {
  final normalized = language.trim().replaceAll('_', '-').toLowerCase();
  if (normalized.isEmpty) return '';
  if (normalized == 'cn' ||
      normalized == 'zh' ||
      normalized == 'zh-cn' ||
      normalized == 'zh-sg' ||
      normalized == 'zh-hans') {
    return 'zh-Hans';
  }
  if (normalized == 'tw' ||
      normalized == 'yue' ||
      normalized == 'yue-hk' ||
      normalized == 'cantonese' ||
      normalized == 'zh-tw' ||
      normalized == 'zh-hk' ||
      normalized == 'zh-mo' ||
      normalized == 'zh-hant') {
    return 'yue-HK';
  }
  final base = normalized.split('-').first;
  return switch (base) {
    'eng' => 'en',
    'deu' || 'ger' => 'de',
    'spa' => 'es',
    'fra' || 'fre' => 'fr',
    'ita' => 'it',
    'jpn' => 'ja',
    'kor' => 'ko',
    'nld' || 'dut' => 'nl',
    'por' => 'pt',
    'pol' => 'pl',
    'ron' || 'rum' => 'ro',
    'ces' || 'cze' => 'cs',
    'ara' => 'ar',
    'heb' => 'he',
    'rus' => 'ru',
    _ => base,
  };
}

String _detectCommentaryLanguage(String text) {
  if (RegExp(r'[\u3040-\u30ff]').hasMatch(text)) return 'ja';
  if (RegExp(r'[\uac00-\ud7af]').hasMatch(text)) return 'ko';
  if (RegExp(r'[\u0590-\u05ff]').hasMatch(text)) return 'he';
  if (RegExp(r'[\u0600-\u06ff]').hasMatch(text)) return 'ar';
  if (RegExp(r'[\u0400-\u04ff]').hasMatch(text)) return 'ru';
  if (RegExp(r'[\u3400-\u4dbf\u4e00-\u9fff]').hasMatch(text)) {
    const traditionalMarkers = '這個為後裡讓與將開關時來說對還點從進過實現發現應該選擇優勢機會';
    return text.split('').any(traditionalMarkers.contains)
        ? 'yue-HK'
        : 'zh-Hans';
  }

  final words = RegExp(r"[a-zA-ZÀ-ÿ']+")
      .allMatches(text)
      .map((match) => match.group(0)!.toLowerCase())
      .where((word) => !_looksLikeChessNotation(word))
      .toList(growable: false);
  if (words.isEmpty) return 'en';

  const markers = <String, Set<String>>{
    'de': {
      'aber',
      'auf',
      'das',
      'der',
      'die',
      'ein',
      'eine',
      'für',
      'ist',
      'mit',
      'nicht',
      'oder',
      'schwarz',
      'sie',
      'und',
      'weiß',
      'zug',
    },
    'es': {
      'ahora',
      'blancas',
      'con',
      'del',
      'el',
      'en',
      'esta',
      'este',
      'la',
      'las',
      'mejor',
      'negras',
      'para',
      'pero',
      'por',
      'que',
      'una',
    },
    'fr': {
      'avec',
      'blancs',
      'ce',
      'cette',
      'dans',
      'des',
      'est',
      'et',
      'la',
      'le',
      'les',
      'mais',
      'meilleur',
      'noirs',
      'pour',
      'que',
      'une',
    },
    'it': {
      'bianchi',
      'con',
      'dei',
      'del',
      'della',
      'il',
      'in',
      'la',
      'le',
      'ma',
      'migliore',
      'neri',
      'per',
      'questa',
      'questo',
      'una',
    },
    'nl': {
      'de',
      'een',
      'en',
      'het',
      'maar',
      'met',
      'niet',
      'om',
      'op',
      'voor',
      'wit',
      'zwart',
      'zet',
      'beste',
      'deze',
      'dat',
      'die',
    },
    'en': {
      'and',
      'black',
      'but',
      'for',
      'from',
      'into',
      'is',
      'move',
      'now',
      'of',
      'on',
      'the',
      'this',
      'to',
      'white',
      'with',
      'best',
    },
  };

  var bestLanguage = 'en';
  var bestScore = 0;
  for (final entry in markers.entries) {
    final score = words.where(entry.value.contains).length;
    if (score > bestScore) {
      bestLanguage = entry.key;
      bestScore = score;
    }
  }
  return bestLanguage;
}

bool _looksLikeChessNotation(String word) {
  return RegExp(r'^[kqrbn]?[a-h]?[1-8]?x?[a-h][1-8][+#]?$').hasMatch(word) ||
      word == 'o' ||
      word == 'oo';
}

String _modelCacheDirectoryName(String modelVersion) {
  final digest = sha256.convert(utf8.encode(modelVersion)).toString();
  return 'model_${digest.substring(0, 16)}';
}

String _join(String parent, String child) =>
    '$parent${Platform.pathSeparator}$child';
