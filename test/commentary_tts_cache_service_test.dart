import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:chessnut_flutter_export/services/commentary_tts_cache_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('coalesces concurrent generation for the same commentary', () async {
    final cacheDirectory = await _temporaryDirectory();
    final gate = Completer<void>();
    final generator = _RecordingGenerator(gate: gate);
    final service = CommentaryTtsCacheService(
      generator: generator,
      cacheDirectory: cacheDirectory,
    );

    final first = service.getOrCreate(
      text: 'The knight belongs on f5.',
      coachId: 'deep',
      style: 'deep',
    );
    final second = service.getOrCreate(
      text: 'The knight belongs on f5.',
      coachId: 'deep',
      style: 'deep',
    );
    await generator.started.future;

    expect(generator.calls, 1);
    gate.complete();
    final files = await Future.wait(<Future<File>>[first, second]);

    expect(files[0].path, files[1].path);
    expect(await files[0].exists(), isTrue);
  });

  test('reuses a persistent WAV with a new service instance', () async {
    final cacheDirectory = await _temporaryDirectory();
    final firstGenerator = _RecordingGenerator();
    final firstService = CommentaryTtsCacheService(
      generator: firstGenerator,
      cacheDirectory: cacheDirectory,
    );
    final first = await firstService.getOrCreate(text: 'Castle now.');

    final secondGenerator = _RecordingGenerator();
    final secondService = CommentaryTtsCacheService(
      generator: secondGenerator,
      cacheDirectory: cacheDirectory,
    );
    final second = await secondService.getOrCreate(text: 'Castle now.');

    expect(firstGenerator.calls, 1);
    expect(secondGenerator.calls, 0);
    expect(second.path, first.path);
  });

  test('coach, style, voice, language, and model version affect cache key',
      () async {
    final cacheDirectory = await _temporaryDirectory();
    final generator = _RecordingGenerator();
    final service = CommentaryTtsCacheService(
      generator: generator,
      cacheDirectory: cacheDirectory,
      modelVersion: 'model-a',
    );

    final base = await service.getOrCreate(text: 'Control the open file.');
    final coach = await service.getOrCreate(
      text: 'Control the open file.',
      coachId: 'rapid',
    );
    final style = await service.getOrCreate(
      text: 'Control the open file.',
      style: 'friendly',
    );
    final voice = await service.getOrCreate(
      text: 'Control the open file.',
      voice: 'another-voice',
    );
    final language = await service.getOrCreate(
      text: 'Control the open file.',
      language: 'fr-FR',
    );
    final otherModelGenerator = _RecordingGenerator();
    final otherModelService = CommentaryTtsCacheService(
      generator: otherModelGenerator,
      cacheDirectory: cacheDirectory,
      modelVersion: 'model-b',
    );
    final model = await otherModelService.getOrCreate(
      text: 'Control the open file.',
    );

    expect(generator.calls, 5);
    expect(otherModelGenerator.calls, 1);
    expect(
      <String>{
        base.path,
        coach.path,
        style.path,
        voice.path,
        language.path,
        model.path,
      },
      hasLength(6),
    );
  });

  test('failed generation is cleaned up and can be retried', () async {
    final cacheDirectory = await _temporaryDirectory();
    final generator = _RecordingGenerator(failuresRemaining: 1);
    final service = CommentaryTtsCacheService(
      generator: generator,
      cacheDirectory: cacheDirectory,
    );

    await expectLater(
      service.getOrCreate(text: 'Retry this explanation.'),
      throwsStateError,
    );
    final file = await service.getOrCreate(text: 'Retry this explanation.');

    expect(generator.calls, 2);
    expect(await file.exists(), isTrue);
    final temporaryFiles = await cacheDirectory
        .list(recursive: true)
        .where((entity) => entity is File && entity.path.endsWith('.tmp'))
        .toList();
    expect(temporaryFiles, isEmpty);
  });

  test('rejects empty commentary without invoking the generator', () async {
    final cacheDirectory = await _temporaryDirectory();
    final generator = _RecordingGenerator();
    final service = CommentaryTtsCacheService(
      generator: generator,
      cacheDirectory: cacheDirectory,
    );

    expect(
      () => service.getOrCreate(text: '   '),
      throwsFormatException,
    );
    expect(generator.calls, 0);
  });

  test('uses explicit report language before text detection', () async {
    final cacheDirectory = await _temporaryDirectory();
    final generator = _RecordingGenerator();
    final service = CommentaryTtsCacheService(
      generator: generator,
      cacheDirectory: cacheDirectory,
    );

    await service.getOrCreate(
      text: '这是中文文本，但报告语言字段具有最高优先级。',
      language: 'de-DE',
    );

    expect(generator.languages, ['de']);
  });

  test('detects language only when an old report has no language field', () {
    expect(
      resolveCommentaryTtsLanguage(text: '这个着法控制了中心。'),
      'zh-Hans',
    );
    expect(
      resolveCommentaryTtsLanguage(text: 'この手は中央を支配します。'),
      'ja',
    );
    expect(
      resolveCommentaryTtsLanguage(text: '이 수는 중앙을 장악합니다.'),
      'ko',
    );
    expect(
      resolveCommentaryTtsLanguage(
          text: 'Dieser Zug kontrolliert das Zentrum.'),
      'de',
    );
    expect(
      resolveCommentaryTtsLanguage(text: 'Ce coup contrôle le centre.'),
      'fr',
    );
    expect(
      resolveCommentaryTtsLanguage(text: 'Этот ход контролирует центр.'),
      'ru',
    );
    expect(
      resolveCommentaryTtsLanguage(text: 'המהלך הזה שולט במרכז.'),
      'he',
    );
    expect(
      resolveCommentaryTtsLanguage(text: 'هذه النقلة تسيطر على المركز.'),
      'ar',
    );
  });

  test('normalizes new report languages for commentary speech', () {
    const expected = <String, String>{
      'zh-Hant': 'yue-HK',
      'yue-HK': 'yue-HK',
      'pt-PT': 'pt',
      'pol': 'pl',
      'ron': 'ro',
      'ces': 'cs',
      'ara': 'ar',
      'heb': 'he',
    };

    for (final entry in expected.entries) {
      expect(normalizeCommentaryTtsLanguage(entry.key), entry.value);
    }
  });

  test('configures models for Cantonese and new supported languages', () {
    final generator = SherpaOnnxCommentaryTtsGenerator();
    const expectedVersionPrefixes = <String, String>{
      'yue-HK': 'vits-cantonese-hf-xiaomaiiwn-',
      'pt': 'supertonic-3-tts-',
      'pl': 'vits-piper-pl_PL-',
      'ro': 'supertonic-3-tts-',
      'cs': 'supertonic-3-tts-',
      'ar': 'supertonic-3-tts-',
      'he': 'vits-mms-tts-heb-sherpa-',
    };

    for (final entry in expectedVersionPrefixes.entries) {
      expect(
        generator.modelVersionForLanguage(entry.key),
        startsWith(entry.value),
      );
    }
  });

  test('configures the official Supertonic model for Japanese', () {
    final generator = SherpaOnnxCommentaryTtsGenerator();

    expect(
      generator.modelVersionForLanguage('ja-JP'),
      'supertonic-3-tts-int8-2026-05-11-82fa96f91c4e',
    );
  });

  test('keeps female and male voice models separate', () {
    final generator = SherpaOnnxCommentaryTtsGenerator();

    const maleVersions = <String, String>{
      'zh-CN': 'vits-piper-zh_CN-chaowen-medium-int8-',
      'en-US': 'vits-piper-en_US-john-medium-int8-',
      'de-DE': 'vits-piper-de_DE-thorsten-medium-int8-',
      'es-ES': 'vits-piper-es_ES-davefx-medium-int8-',
      'fr-FR': 'vits-piper-fr_FR-gilles-low-int8-',
      'it-IT': 'vits-piper-it_IT-riccardo-x_low-int8-',
      'ja-JP': 'supertonic-3-tts-',
      'ko-KR': 'supertonic-3-tts-',
      'nl-NL': 'vits-piper-nl_NL-ronnie-medium-int8-',
      'pt-PT': 'vits-piper-pt_PT-tugao-medium-int8-',
      'pl-PL': 'vits-piper-pl_PL-bass-high-int8-',
      'ro-RO': 'vits-piper-ro_RO-mihai-medium-int8-',
      'cs-CZ': 'vits-piper-cs_CZ-jirka-medium-int8-',
      'ar-JO': 'vits-piper-ar_JO-kareem-medium-int8-',
      'ru-RU': 'vits-piper-ru_RU-denis-medium-int8-',
    };
    for (final entry in maleVersions.entries) {
      expect(commentaryTtsSupportsMaleVoice(entry.key), isTrue);
      expect(
        generator.modelVersionForLanguage(entry.key, voice: 'male'),
        startsWith(entry.value),
      );
    }

    expect(commentaryTtsSupportsMaleVoice('yue-HK'), isFalse);
    expect(commentaryTtsSupportsMaleVoice('he-IL'), isFalse);

    const correctedFemaleVersions = <String, String>{
      'de-DE': 'vits-piper-de_DE-kerstin-low-int8-',
      'es-ES': 'vits-piper-es_AR-daniela-high-int8-',
      'it-IT': 'vits-piper-it_IT-paola-medium-int8-',
      'nl-NL': 'vits-piper-nl_BE-nathalie-medium-int8-',
      'ru-RU': 'vits-piper-ru_RU-irina-medium-int8-',
    };
    for (final entry in correctedFemaleVersions.entries) {
      expect(
        generator.modelVersionForLanguage(entry.key, voice: 'female'),
        startsWith(entry.value),
      );
      expect(
        generator.modelVersionForLanguage(entry.key, voice: 'female'),
        isNot(generator.modelVersionForLanguage(entry.key, voice: 'male')),
      );
    }
  });

  test('installs a Supertonic archive with every required model file',
      () async {
    final installRoot = await _temporaryDirectory();
    const archiveRoot = 'test-supertonic-model';
    final compressed = _supertonicArchive(archiveRoot: archiveRoot);
    final installer = CommentaryTtsModelInstaller(
      assetBundle: _MemoryAssetBundle(compressed),
      installRoot: installRoot,
      assetPath: 'test-supertonic.tar.bz2',
      archiveSha256: sha256.convert(compressed).toString(),
      modelVersion: 'test-supertonic-v1',
      archiveRootName: archiveRoot,
      modelFileName: '',
      engine: CommentaryTtsModelEngine.supertonic,
      dataDirectoryName: '',
    );

    final installed = await installer.install();

    expect(await installed.durationPredictor.exists(), isTrue);
    expect(await installed.textEncoder.exists(), isTrue);
    expect(await installed.vectorEstimator.exists(), isTrue);
    expect(await installed.vocoder.exists(), isTrue);
    expect(await installed.ttsJson.exists(), isTrue);
    expect(await installed.unicodeIndexer.exists(), isTrue);
    expect(await installed.voiceStyle.exists(), isTrue);
  });

  test('rejects an incomplete Supertonic archive', () async {
    final installRoot = await _temporaryDirectory();
    const archiveRoot = 'incomplete-supertonic-model';
    final compressed = _supertonicArchive(
      archiveRoot: archiveRoot,
      omittedFile: 'voice.bin',
    );
    final installer = CommentaryTtsModelInstaller(
      assetBundle: _MemoryAssetBundle(compressed),
      installRoot: installRoot,
      assetPath: 'incomplete-supertonic.tar.bz2',
      archiveSha256: sha256.convert(compressed).toString(),
      modelVersion: 'incomplete-supertonic-v1',
      archiveRootName: archiveRoot,
      modelFileName: '',
      engine: CommentaryTtsModelEngine.supertonic,
      dataDirectoryName: '',
    );

    await expectLater(
      installer.install(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('missing required model files'),
        ),
      ),
    );
  });

  test('installs a verified model archive once and reuses it from disk',
      () async {
    final installRoot = await _temporaryDirectory();
    const archiveRoot = 'test-piper-model';
    final archive = Archive()
      ..addFile(ArchiveFile.directory('$archiveRoot/'))
      ..addFile(
        ArchiveFile.string('$archiveRoot/en_US-amy-low.onnx', 'model'),
      )
      ..addFile(ArchiveFile.string('$archiveRoot/tokens.txt', 'tokens'))
      ..addFile(ArchiveFile.directory('$archiveRoot/espeak-ng-data/'))
      ..addFile(
        ArchiveFile.string('$archiveRoot/espeak-ng-data/en_dict', 'dict'),
      );
    final tar = TarEncoder().encodeBytes(archive);
    final compressed = BZip2Encoder().encodeBytes(tar);
    final bundle = _MemoryAssetBundle(compressed);
    final digest = sha256.convert(compressed).toString();
    final installer = CommentaryTtsModelInstaller(
      assetBundle: bundle,
      installRoot: installRoot,
      assetPath: 'test-model.tar.bz2',
      archiveSha256: digest,
      modelVersion: 'test-model-v1',
      archiveRootName: archiveRoot,
    );

    final first = await installer.install();
    final coalesced = await installer.install();

    expect(bundle.loads, 1);
    expect(first.directory.path, coalesced.directory.path);
    expect(await first.model.readAsString(), 'model');
    expect(await first.tokens.readAsString(), 'tokens');
    expect(
      await File('${first.espeakData.path}${Platform.pathSeparator}en_dict')
          .readAsString(),
      'dict',
    );

    final diskOnlyInstaller = CommentaryTtsModelInstaller(
      assetBundle: _FailingAssetBundle(),
      installRoot: installRoot,
      assetPath: 'test-model.tar.bz2',
      archiveSha256: digest,
      modelVersion: 'test-model-v1',
      archiveRootName: archiveRoot,
    );
    final reused = await diskOnlyInstaller.install();

    expect(reused.directory.path, first.directory.path);
  });

  test('model installation can retry after a failed asset load', () async {
    final installRoot = await _temporaryDirectory();
    const archiveRoot = 'retry-piper-model';
    final archive = Archive()
      ..addFile(ArchiveFile.directory('$archiveRoot/'))
      ..addFile(
        ArchiveFile.string('$archiveRoot/en_US-amy-low.onnx', 'model'),
      )
      ..addFile(ArchiveFile.string('$archiveRoot/tokens.txt', 'tokens'))
      ..addFile(ArchiveFile.directory('$archiveRoot/espeak-ng-data/'))
      ..addFile(
        ArchiveFile.string('$archiveRoot/espeak-ng-data/en_dict', 'dict'),
      );
    final compressed =
        BZip2Encoder().encodeBytes(TarEncoder().encodeBytes(archive));
    final bundle = _FailOnceAssetBundle(compressed);
    final installer = CommentaryTtsModelInstaller(
      assetBundle: bundle,
      installRoot: installRoot,
      assetPath: 'retry-model.tar.bz2',
      archiveSha256: sha256.convert(compressed).toString(),
      modelVersion: 'retry-model-v1',
      archiveRootName: archiveRoot,
    );

    await expectLater(installer.install(), throwsStateError);
    final installed = await installer.install();

    expect(bundle.loads, 2);
    expect(await installed.model.readAsString(), 'model');
  });

  test('remote model download resumes from the saved partial file', () async {
    final installRoot = await _temporaryDirectory();
    const archiveRoot = 'remote-piper-model';
    final archive = Archive()
      ..addFile(ArchiveFile.directory('$archiveRoot/'))
      ..addFile(
        ArchiveFile.string('$archiveRoot/en_US-amy-low.onnx', 'model'),
      )
      ..addFile(ArchiveFile.string('$archiveRoot/tokens.txt', 'tokens'))
      ..addFile(ArchiveFile.directory('$archiveRoot/espeak-ng-data/'))
      ..addFile(
        ArchiveFile.string('$archiveRoot/espeak-ng-data/en_dict', 'dict'),
      );
    final compressed = Uint8List.fromList(
      BZip2Encoder().encodeBytes(TarEncoder().encodeBytes(archive)),
    );
    final client = _InterruptingRangeClient(compressed);
    final installer = CommentaryTtsModelInstaller(
      httpClient: client,
      installRoot: installRoot,
      assetPath: '',
      downloadUri: Uri.parse('https://example.test/model.tar.bz2'),
      archiveSha256: sha256.convert(compressed).toString(),
      modelVersion: 'remote-model-v1',
      archiveRootName: archiveRoot,
    );

    await expectLater(installer.install(), throwsA(isA<SocketException>()));
    final partial = File(
      '${installRoot.path}${Platform.pathSeparator}'
      '.model_${sha256.convert('remote-model-v1'.codeUnits).toString().substring(0, 16)}.partial.tar.bz2',
    );
    expect(await partial.exists(), isTrue);
    final savedBytes = await partial.length();
    expect(savedBytes, greaterThan(0));
    expect(savedBytes, lessThan(compressed.length));

    final installed = await installer.install();

    expect(client.rangeHeaders, [null, 'bytes=$savedBytes-']);
    expect(await partial.exists(), isFalse);
    expect(await installed.model.readAsString(), 'model');
  });

  test('retries after the model download receives no data', () async {
    final installRoot = await _temporaryDirectory();
    const archiveRoot = 'idle-retry-piper-model';
    final archive = Archive()
      ..addFile(ArchiveFile.directory('$archiveRoot/'))
      ..addFile(
        ArchiveFile.string('$archiveRoot/en_US-amy-low.onnx', 'model'),
      )
      ..addFile(ArchiveFile.string('$archiveRoot/tokens.txt', 'tokens'))
      ..addFile(ArchiveFile.directory('$archiveRoot/espeak-ng-data/'))
      ..addFile(
        ArchiveFile.string('$archiveRoot/espeak-ng-data/en_dict', 'dict'),
      );
    final compressed = Uint8List.fromList(
      BZip2Encoder().encodeBytes(TarEncoder().encodeBytes(archive)),
    );
    final client = _IdleThenRangeClient(compressed);
    final installer = CommentaryTtsModelInstaller(
      httpClient: client,
      installRoot: installRoot,
      assetPath: '',
      downloadUri: Uri.parse('https://example.test/model.tar.bz2'),
      archiveSha256: sha256.convert(compressed).toString(),
      modelVersion: 'idle-retry-model-v1',
      archiveRootName: archiveRoot,
      downloadInactivityTimeout: const Duration(milliseconds: 20),
    );

    final installed = await installer.install();

    final firstChunkLength = compressed.length ~/ 2;
    expect(
      client.rangeHeaders,
      [null, 'bytes=$firstChunkLength-'],
    );
    expect(await installed.model.readAsString(), 'model');
  });

  test('installs and reuses a verified multi-file model download', () async {
    final installRoot = await _temporaryDirectory();
    final files = <String, Uint8List>{
      'https://example.test/model.onnx': Uint8List.fromList('model'.codeUnits),
      'https://example.test/tokens.txt': Uint8List.fromList('tokens'.codeUnits),
    };
    final client = _StaticFilesClient(files);
    final installer = CommentaryTtsModelInstaller(
      httpClient: client,
      installRoot: installRoot,
      assetPath: '',
      archiveSha256: '',
      modelVersion: 'multi-file-model-v1',
      archiveRootName: 'multi-file-model',
      modelFileName: 'model.onnx',
      dataDirectoryName: '',
      downloadFiles: <CommentaryTtsDownloadFile>[
        CommentaryTtsDownloadFile(
          fileName: 'model.onnx',
          url: 'https://example.test/model.onnx',
          sha256: sha256
              .convert(files['https://example.test/model.onnx']!)
              .toString(),
        ),
        CommentaryTtsDownloadFile(
          fileName: 'tokens.txt',
          url: 'https://example.test/tokens.txt',
          sha256: sha256
              .convert(files['https://example.test/tokens.txt']!)
              .toString(),
        ),
      ],
    );

    final first = await installer.install();
    final reused = await installer.install();

    expect(await first.model.readAsString(), 'model');
    expect(await first.tokens.readAsString(), 'tokens');
    expect(reused.directory.path, first.directory.path);
    expect(client.requests, hasLength(2));
  });
}

Uint8List _supertonicArchive({
  required String archiveRoot,
  String omittedFile = '',
}) {
  const requiredFiles = <String>[
    'duration_predictor.int8.onnx',
    'text_encoder.int8.onnx',
    'vector_estimator.int8.onnx',
    'vocoder.int8.onnx',
    'tts.json',
    'unicode_indexer.bin',
    'voice.bin',
  ];
  final archive = Archive()..addFile(ArchiveFile.directory('$archiveRoot/'));
  for (final fileName in requiredFiles) {
    if (fileName == omittedFile) continue;
    archive.addFile(ArchiveFile.string('$archiveRoot/$fileName', fileName));
  }
  return Uint8List.fromList(
    BZip2Encoder().encodeBytes(TarEncoder().encodeBytes(archive)),
  );
}

Future<Directory> _temporaryDirectory() async {
  final directory = await Directory.systemTemp.createTemp('commentary_tts_');
  addTearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });
  return directory;
}

class _RecordingGenerator extends CommentaryTtsAudioGenerator {
  _RecordingGenerator({this.gate, this.failuresRemaining = 0});

  final Completer<void>? gate;
  int failuresRemaining;
  int calls = 0;
  final List<String> languages = <String>[];
  final Completer<void> started = Completer<void>();

  @override
  Future<void> generate({
    required String text,
    required String language,
    required String coachId,
    required String voice,
    required String style,
    required File outputFile,
  }) async {
    calls += 1;
    languages.add(language);
    if (!started.isCompleted) started.complete();
    await gate?.future;
    if (failuresRemaining > 0) {
      failuresRemaining -= 1;
      throw StateError('Synthetic TTS failure');
    }
    await outputFile.writeAsBytes(_testWave(text), flush: true);
  }
}

Uint8List _testWave(String text) {
  final bytes = Uint8List(48 + text.length);
  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  bytes.setRange(8, 12, 'WAVE'.codeUnits);
  bytes.setRange(12, 16, 'fmt '.codeUnits);
  bytes.setRange(36, 40, 'data'.codeUnits);
  bytes.setRange(44, 44 + text.length, text.codeUnits);
  return bytes;
}

class _MemoryAssetBundle extends CachingAssetBundle {
  _MemoryAssetBundle(this.bytes);

  final Uint8List bytes;
  int loads = 0;

  @override
  Future<ByteData> load(String key) async {
    loads += 1;
    return ByteData.sublistView(bytes);
  }
}

class _FailingAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    throw StateError('The installed model should not reload its asset.');
  }
}

class _FailOnceAssetBundle extends CachingAssetBundle {
  _FailOnceAssetBundle(this.bytes);

  final Uint8List bytes;
  int loads = 0;

  @override
  Future<ByteData> load(String key) async {
    loads += 1;
    if (loads == 1) throw StateError('Synthetic first asset load failure');
    return ByteData.sublistView(bytes);
  }
}

class _InterruptingRangeClient extends http.BaseClient {
  _InterruptingRangeClient(this.bytes);

  final Uint8List bytes;
  final List<String?> rangeHeaders = <String?>[];
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final range = request.headers[HttpHeaders.rangeHeader];
    rangeHeaders.add(range);
    calls += 1;
    if (calls == 1) {
      final split = bytes.length ~/ 2;
      final controller = StreamController<List<int>>();
      scheduleMicrotask(() async {
        controller.add(bytes.sublist(0, split));
        controller.addError(const SocketException('Synthetic interruption'));
        await controller.close();
      });
      return http.StreamedResponse(
        controller.stream,
        HttpStatus.ok,
        contentLength: bytes.length,
      );
    }

    final offset =
        int.parse(range!.substring('bytes='.length, range.length - 1));
    final remaining = bytes.sublist(offset);
    return http.StreamedResponse(
      Stream<List<int>>.value(remaining),
      HttpStatus.partialContent,
      contentLength: remaining.length,
      headers: {
        HttpHeaders.contentRangeHeader:
            'bytes $offset-${bytes.length - 1}/${bytes.length}',
      },
    );
  }
}

class _IdleThenRangeClient extends http.BaseClient {
  _IdleThenRangeClient(this.bytes);

  final Uint8List bytes;
  final List<String?> rangeHeaders = <String?>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final range = request.headers[HttpHeaders.rangeHeader];
    rangeHeaders.add(range);
    if (rangeHeaders.length == 1) {
      final split = bytes.length ~/ 2;
      final stream = Stream<List<int>>.multi((controller) {
        controller.add(bytes.sublist(0, split));
      });
      return http.StreamedResponse(
        stream,
        HttpStatus.ok,
        contentLength: bytes.length,
      );
    }

    final offset =
        int.parse(range!.substring('bytes='.length, range.length - 1));
    final remaining = bytes.sublist(offset);
    return http.StreamedResponse(
      Stream<List<int>>.value(remaining),
      HttpStatus.partialContent,
      contentLength: remaining.length,
      headers: {
        HttpHeaders.contentRangeHeader:
            'bytes $offset-${bytes.length - 1}/${bytes.length}',
      },
    );
  }
}

class _StaticFilesClient extends http.BaseClient {
  _StaticFilesClient(this.files);

  final Map<String, Uint8List> files;
  final List<Uri> requests = <Uri>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    final bytes = files[request.url.toString()];
    if (bytes == null) {
      return http.StreamedResponse(const Stream<List<int>>.empty(), 404);
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      HttpStatus.ok,
      contentLength: bytes.length,
    );
  }
}
