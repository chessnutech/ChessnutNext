import 'dart:io';

import 'package:chessnut_flutter_export/services/course_thumbnail_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('load stores thumbnails on disk and reuses cached files', () async {
    final tempDir = await Directory.systemTemp.createTemp('course_thumbs_');
    var requests = 0;
    final client = MockClient((request) async {
      requests += 1;
      return http.Response.bytes([1, 2, 3, 4], 200);
    });
    final cache = CourseThumbnailCache(
      httpClient: client,
      cacheDirectory: tempDir,
    );

    final first = await cache.load('https://cdn.example/a.png');
    final second = await cache.load('https://cdn.example/a.png');

    expect(requests, 1);
    expect(first.path, second.path);
    expect(await second.readAsBytes(), [1, 2, 3, 4]);

    await tempDir.delete(recursive: true);
  });

  test('preloadSequential downloads thumbnails in list order', () async {
    final tempDir = await Directory.systemTemp.createTemp('course_thumbs_');
    final requestOrder = <String>[];
    final client = MockClient((request) async {
      requestOrder.add(request.url.toString());
      return http.Response.bytes(request.url.path.codeUnits, 200);
    });
    final cache = CourseThumbnailCache(
      httpClient: client,
      cacheDirectory: tempDir,
    );
    final urls = [
      'https://cdn.example/01.png',
      'https://cdn.example/02.png',
      'https://cdn.example/03.png',
    ];

    await cache.preloadSequential(urls);

    expect(requestOrder, urls);
    expect(cache.fileFor(urls[0]), isNotNull);
    expect(cache.fileFor(urls[1]), isNotNull);
    expect(cache.fileFor(urls[2]), isNotNull);

    await tempDir.delete(recursive: true);
  });
}
