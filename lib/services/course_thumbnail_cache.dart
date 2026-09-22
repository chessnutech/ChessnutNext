import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class CourseThumbnailCache extends ChangeNotifier {
  CourseThumbnailCache({
    http.Client? httpClient,
    Directory? cacheDirectory,
    this.cacheEnabled = true,
  })  : _httpClient = httpClient ?? http.Client(),
        _cacheDirectory = cacheDirectory;

  final http.Client _httpClient;
  final Directory? _cacheDirectory;
  final bool cacheEnabled;
  final Map<String, File> _memory = <String, File>{};
  final Map<String, Future<File>> _inFlight = <String, Future<File>>{};

  File? fileFor(String url) => _memory[url];

  Future<File> load(String url) {
    if (url.trim().isEmpty) {
      return Future<File>.error(
        const FormatException('Thumbnail URL cannot be empty.'),
      );
    }
    return _inFlight[url] ??= _load(url).whenComplete(() {
      _inFlight.remove(url);
    });
  }

  Future<void> preloadSequential(Iterable<String> urls) async {
    for (final url in urls) {
      if (url.trim().isEmpty) continue;
      try {
        await load(url);
      } catch (_) {
        // Individual thumbnail failures should not block later lessons.
      }
    }
  }

  Future<File> _load(String url) async {
    final file = await _cacheFile(url);
    if (cacheEnabled && await file.exists() && await file.length() > 0) {
      _remember(url, file);
      return file;
    }

    final response = await _httpClient.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Thumbnail request failed with ${response.statusCode}.',
        uri: Uri.parse(url),
      );
    }
    await file.parent.create(recursive: true);
    await file.writeAsBytes(response.bodyBytes, flush: true);
    _remember(url, file);
    return file;
  }

  void _remember(String url, File file) {
    _memory[url] = file;
    notifyListeners();
  }

  Future<File> _cacheFile(String url) async {
    final dir = _cacheDirectory ?? await _defaultCacheDirectory();
    final digest = md5.convert(utf8.encode(url)).toString();
    return File('${dir.path}${Platform.pathSeparator}$digest.img');
  }

  Future<Directory> _defaultCacheDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory(
      '${support.path}${Platform.pathSeparator}course_thumbnail_cache',
    );
  }
}
