import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

abstract interface class CourseLessonRepository {
  Future<List<CourseCatalogItem>> fetchCatalog();

  Future<CourseLessonBundle> fetchLesson(
    CourseCatalogItem course, {
    Locale? locale,
  });
}

class NetworkCourseLessonRepository extends CourseLessonService {
  NetworkCourseLessonRepository();
}

class CourseLessonService implements CourseLessonRepository {
  CourseLessonService({
    http.Client? httpClient,
    this.catalogUrl = defaultCatalogUrl,
    this.cacheEnabled = true,
    Future<Directory> Function()? cacheDirectoryProvider,
  })  : _httpClient = httpClient ?? http.Client(),
        _cacheDirectoryProvider = cacheDirectoryProvider;

  static const defaultCatalogUrl =
      'https://chessnut.us-east-1.linodeobjects.com/ChessCourses%2Fcourses.json';

  final http.Client _httpClient;
  final String catalogUrl;
  final bool cacheEnabled;
  final Future<Directory> Function()? _cacheDirectoryProvider;

  @override
  Future<List<CourseCatalogItem>> fetchCatalog() async {
    final content = await _fetchText(catalogUrl, refresh: true);
    final decoded = jsonDecode(content);
    if (decoded is! List) {
      throw const FormatException('Course catalog must be a JSON array.');
    }
    return decoded
        .whereType<Map>()
        .map(
          (item) => CourseCatalogItem.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<CourseLessonBundle> fetchLesson(
    CourseCatalogItem course, {
    Locale? locale,
  }) async {
    final results = await Future.wait([
      _fetchLocalizedSubtitle(course, locale),
      _fetchText(course.scriptUrl),
    ]);
    return CourseLessonBundle(
      course: course,
      subtitles: parseSbv(results[0]),
      scriptItems: parseScript(results[1]),
    );
  }

  Future<String> _fetchLocalizedSubtitle(
    CourseCatalogItem course,
    Locale? locale,
  ) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (final url in course.subtitleUrlCandidates(locale)) {
      final isEnglishFallback = url == course.subtitleUrl;
      try {
        return await _fetchText(
          url,
          refresh: true,
          fallbackToCacheOnFailure: isEnglishFallback,
        );
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (isEnglishFallback) break;
      }
    }
    if (lastError != null && lastStackTrace != null) {
      Error.throwWithStackTrace(lastError, lastStackTrace);
    }
    return _fetchText(course.subtitleUrl, refresh: true);
  }

  Future<String> _fetchText(
    String url, {
    bool refresh = false,
    bool fallbackToCacheOnFailure = true,
  }) async {
    if (cacheEnabled && !refresh) {
      final cached = await _readCache(url);
      if (cached != null) return cached;
    }

    try {
      final uri = Uri.parse(url);
      final response = await _httpClient.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Course request failed with ${response.statusCode}.',
          uri: uri,
        );
      }
      final content = utf8.decode(response.bodyBytes);
      if (cacheEnabled) {
        await _writeCache(url, content);
      }
      return content;
    } catch (_) {
      if (cacheEnabled && fallbackToCacheOnFailure) {
        final cached = await _readCache(url);
        if (cached != null) return cached;
      }
      rethrow;
    }
  }

  Future<String?> _readCache(String url) async {
    try {
      final file = await _cacheFile(url);
      if (!await file.exists() || await file.length() == 0) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String url, String content) async {
    try {
      final file = await _cacheFile(url);
      await file.parent.create(recursive: true);
      await file.writeAsString(content, flush: true);
    } catch (_) {
      // Cache failures should not block lessons.
    }
  }

  Future<File> _cacheFile(String url) async {
    final dir = await (_cacheDirectoryProvider?.call() ??
        getApplicationSupportDirectory());
    final digest = md5.convert(utf8.encode(url)).toString();
    return File(
      '${dir.path}${Platform.pathSeparator}course_cache'
      '${Platform.pathSeparator}$digest.txt',
    );
  }

  static List<CourseSubtitleCue> parseSbv(String content) {
    final cues = <CourseSubtitleCue>[];
    final lines = const LineSplitter().convert(content);
    Duration? start;
    Duration? end;
    final text = StringBuffer();

    void flush() {
      if (start == null || end == null) return;
      final value = text.toString().trim();
      if (value.isNotEmpty) {
        cues.add(CourseSubtitleCue(start: start!, end: end!, text: value));
      }
      start = null;
      end = null;
      text.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        flush();
        continue;
      }
      final range = _parseSbvRange(line);
      if (range != null) {
        flush();
        start = range.$1;
        end = range.$2;
        continue;
      }
      if (text.isNotEmpty) text.write('\n');
      text.write(line);
    }
    flush();
    return List.unmodifiable(_normalizeSubtitleCues(cues));
  }

  static List<CourseScriptItem> parseScript(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! List) {
      throw const FormatException('Course script must be a JSON array.');
    }
    return decoded.whereType<Map>().map((item) {
      final json = item.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      return CourseScriptItem(
        startTime: Duration(
          milliseconds: _readInt(json['start_time'], field: 'start_time'),
        ),
        checkpointTitle: _readNullableString(json['check_point_title']),
        startTimePause: json['start_time_pause'] == true,
        destFen: _readNullableString(json['dest_fen']),
        destFenMatchToContinue: json['dest_fen_match_to_continue'] == true,
        led: _readLedArray(json['led']),
        ledWhenContinue: _readLedArray(json['led_when_continue']),
      );
    }).toList(growable: false);
  }

  static (Duration, Duration)? _parseSbvRange(String line) {
    final parts = line.split(',');
    if (parts.length != 2) return null;
    final start = _parseSbvTimestamp(parts[0]);
    final end = _parseSbvTimestamp(parts[1]);
    if (start == null || end == null) return null;
    return (start, end);
  }

  static Duration? _parseSbvTimestamp(String value) {
    final match =
        RegExp(r'^(\d+):(\d{2}):(\d{2})\.(\d{3})$').firstMatch(value.trim());
    if (match == null) return null;
    final hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    final seconds = int.parse(match.group(3)!);
    final millis = int.parse(match.group(4)!);
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: millis,
    );
  }

  static int _readInt(Object? value, {required String field}) {
    if (value is int) return value;
    if (value is num) return value.round();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
    throw FormatException('Course script field $field must be an integer.');
  }

  static String? _readNullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static List<int>? _readLedArray(Object? value) {
    if (value is! List) return null;
    final colors = <int>[];
    for (final raw in value.take(64)) {
      colors.add(_readColor(raw));
    }
    if (colors.length < 64) {
      colors.addAll(List<int>.filled(64 - colors.length, 0));
    }
    return List<int>.unmodifiable(colors);
  }

  static int _readColor(Object? value) {
    if (value is int) return value;
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text.isEmpty) return 0;
    return int.tryParse(text) ??
        int.tryParse(text.replaceFirst('0x', ''), radix: 16) ??
        0;
  }
}

List<CourseSubtitleCue> _normalizeSubtitleCues(
  List<CourseSubtitleCue> cues,
) {
  if (cues.length < 2) return cues;
  final normalized = <CourseSubtitleCue>[];
  for (final cue in cues) {
    final text = normalized.isEmpty
        ? cue.text.trim()
        : _trimRepeatedPrefix(normalized.last.text, cue.text);
    normalized.add(
      CourseSubtitleCue(start: cue.start, end: cue.end, text: text),
    );
  }
  return normalized;
}

String _trimRepeatedPrefix(String previous, String current) {
  final previousText = previous.trim();
  final currentText = current.trim();
  if (previousText.isEmpty || currentText.isEmpty) return currentText;
  final previousComparable =
      _trimSubtitleEdgePunctuation(previousText, trailing: true);
  final currentComparable =
      _trimSubtitleEdgePunctuation(currentText, leading: true);
  final maxOverlap = previousComparable.length < currentComparable.length
      ? previousComparable.length
      : currentComparable.length;
  for (var overlap = maxOverlap; overlap >= 4; overlap--) {
    if (previousComparable.substring(previousComparable.length - overlap) ==
        currentComparable.substring(0, overlap)) {
      return currentText.substring(overlap).trimLeft();
    }
  }
  return currentText;
}

String _trimSubtitleEdgePunctuation(
  String text, {
  bool leading = false,
  bool trailing = false,
}) {
  var start = 0;
  var end = text.length;
  if (leading) {
    while (start < end && _isSubtitleEdgeCharacter(text.codeUnitAt(start))) {
      start++;
    }
  }
  if (trailing) {
    while (end > start && _isSubtitleEdgeCharacter(text.codeUnitAt(end - 1))) {
      end--;
    }
  }
  return text.substring(start, end);
}

bool _isSubtitleEdgeCharacter(int codeUnit) {
  return switch (codeUnit) {
    0x09 || 0x0A || 0x0D || 0x20 => true,
    0x22 ||
    0x27 ||
    0x28 ||
    0x29 ||
    0x2C ||
    0x2D ||
    0x2E ||
    0x3A ||
    0x3B ||
    0x3F ||
    0x5B ||
    0x5D ||
    0x7B ||
    0x7D =>
      true,
    0x2014 || 0x2018 || 0x2019 || 0x201C || 0x201D => true,
    0x3001 || 0x3002 || 0xFF01 || 0xFF0C || 0xFF1A || 0xFF1B || 0xFF1F => true,
    _ => false,
  };
}

class CourseCatalogItem {
  const CourseCatalogItem({
    required this.title,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.subtitleUrl,
    required this.scriptUrl,
    this.localizedSubtitleUrls = const {},
  });

  final String title;
  final String thumbnailUrl;
  final String videoUrl;
  final String subtitleUrl;
  final String scriptUrl;
  final Map<String, String> localizedSubtitleUrls;

  String get id {
    final match = RegExp(r'^(\d+[a-zA-Z]?)\b').firstMatch(title.trim());
    return match?.group(1) ?? title.trim();
  }

  factory CourseCatalogItem.fromJson(Map<String, dynamic> json) {
    return CourseCatalogItem(
      title: json['title']?.toString() ?? '',
      thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
      videoUrl: json['videoUrl']?.toString() ?? '',
      subtitleUrl: json['subTitleUrl']?.toString() ?? '',
      scriptUrl: json['scriptUrl']?.toString() ?? '',
      localizedSubtitleUrls: _localizedSubtitleUrlsFromJson(json),
    );
  }

  List<String> subtitleUrlCandidates(Locale? locale) {
    final urls = <String>[];

    void addUrl(String? value) {
      final url = value?.trim();
      if (url == null || url.isEmpty || urls.contains(url)) return;
      urls.add(url);
    }

    final languageTags = _subtitleLanguageTags(locale);
    for (final tag in languageTags) {
      addUrl(localizedSubtitleUrls[tag.toLowerCase()]);
    }
    if (!languageTags.contains('en')) {
      for (final tag in languageTags) {
        for (final suffix in _subtitleLanguageSuffixes(tag)) {
          addUrl(_appendSuffixBeforeExtension(subtitleUrl, suffix));
        }
      }
    }
    addUrl(localizedSubtitleUrls['en']);
    addUrl(subtitleUrl);
    return urls;
  }
}

Map<String, String> _localizedSubtitleUrlsFromJson(Map<String, dynamic> json) {
  final urls = <String, String>{};

  void readMap(Object? value) {
    if (value is! Map) return;
    for (final entry in value.entries) {
      final key = entry.key.toString().trim().toLowerCase();
      final url = entry.value?.toString().trim() ?? '';
      if (key.isNotEmpty && url.isNotEmpty) urls[key] = url;
    }
  }

  readMap(json['subtitleUrls']);
  readMap(json['subTitleUrls']);
  readMap(json['localizedSubtitleUrls']);
  readMap(json['localizedSubTitleUrls']);
  return urls;
}

List<String> _subtitleLanguageTags(Locale? locale) {
  if (locale == null) return const ['en'];
  final languageCode = locale.languageCode.toLowerCase();
  if (languageCode == 'en') return const ['en'];
  if (languageCode == 'zh') {
    final country = locale.countryCode?.toUpperCase();
    final isTraditional = locale.scriptCode == 'Hant' ||
        country == 'TW' ||
        country == 'HK' ||
        country == 'MO';
    return isTraditional
        ? const ['zh-Hant', 'zh-TW', 'zh']
        : const ['zh-Hans', 'zh-CN', 'zh'];
  }
  final tags = <String>[];
  void add(String value) {
    if (!tags.contains(value)) tags.add(value);
  }

  add(_localeLanguageTag(locale));
  add(languageCode);
  return tags;
}

String _localeLanguageTag(Locale locale) {
  final languageCode = locale.languageCode.toLowerCase();
  final scriptCode = locale.scriptCode;
  if (scriptCode != null && scriptCode.isNotEmpty) {
    return '$languageCode-$scriptCode';
  }
  final countryCode = locale.countryCode;
  if (countryCode != null && countryCode.isNotEmpty) {
    return '$languageCode-${countryCode.toUpperCase()}';
  }
  return languageCode;
}

List<String> _subtitleLanguageSuffixes(String tag) {
  final lowerTag = tag.toLowerCase();
  return [
    '_$tag',
    '.$tag',
    if (lowerTag != tag) '_$lowerTag',
    if (lowerTag != tag) '.$lowerTag',
  ];
}

String _appendSuffixBeforeExtension(String url, String suffix) {
  final queryStart = url.indexOf(RegExp(r'[?#]'));
  final pathEnd = queryStart == -1 ? url.length : queryStart;
  final path = url.substring(0, pathEnd);
  final trailer = url.substring(pathEnd);
  final lastSlash = path.lastIndexOf('/');
  final lastDot = path.lastIndexOf('.');
  if (lastDot <= lastSlash) {
    return '$path$suffix$trailer';
  }
  return '${path.substring(0, lastDot)}$suffix${path.substring(lastDot)}'
      '$trailer';
}

class CourseLessonBundle {
  const CourseLessonBundle({
    required this.course,
    required this.subtitles,
    required this.scriptItems,
  });

  final CourseCatalogItem course;
  final List<CourseSubtitleCue> subtitles;
  final List<CourseScriptItem> scriptItems;

  List<CourseScriptItem> get checkpoints =>
      scriptItems.where((item) => item.startTimePause).toList(growable: false);
}

class CourseSubtitleCue {
  const CourseSubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;
}

String courseSubtitleTextAtPosition(
  Duration position,
  List<CourseSubtitleCue> cues,
) {
  for (var i = cues.length - 1; i >= 0; i--) {
    final cue = cues[i];
    if (position >= cue.start && position <= cue.end) {
      return cue.text;
    }
  }
  return '';
}

class CourseScriptItem {
  const CourseScriptItem({
    required this.startTime,
    this.checkpointTitle,
    this.startTimePause = false,
    this.destFen,
    this.destFenMatchToContinue = false,
    this.led,
    this.ledWhenContinue,
  });

  final Duration startTime;
  final String? checkpointTitle;
  final bool startTimePause;
  final String? destFen;
  final bool destFenMatchToContinue;
  final List<int>? led;
  final List<int>? ledWhenContinue;
}
