import 'dart:io';
import 'dart:ui' show Locale;

import 'package:chessnut_flutter_export/services/course_lesson_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('fetchCatalog parses the EVO course catalog shape', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), CourseLessonService.defaultCatalogUrl);
      return http.Response('''
[
  {
    "title": "02 - Coordinates",
    "thumbnailUrl": "https://cdn.example/thumbnail.png",
    "videoUrl": "https://cdn.example/video.mp4",
    "subTitleUrl": "https://cdn.example/subtitles.sbv",
    "scriptUrl": "https://cdn.example/cuesheet.json"
  }
]
''', 200);
    });

    final service = CourseLessonService(
      httpClient: client,
      cacheEnabled: false,
    );

    final courses = await service.fetchCatalog();

    expect(courses, hasLength(1));
    expect(courses.single.id, '02');
    expect(courses.single.title, '02 - Coordinates');
    expect(courses.single.thumbnailUrl, 'https://cdn.example/thumbnail.png');
    expect(courses.single.videoUrl, 'https://cdn.example/video.mp4');
    expect(courses.single.subtitleUrl, 'https://cdn.example/subtitles.sbv');
    expect(courses.single.scriptUrl, 'https://cdn.example/cuesheet.json');
  });

  test(
    'fetchLesson loads localized subtitle suffix for app language',
    () async {
      final requestedUrls = <String>[];
      final client = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        return switch (request.url.toString()) {
          'https://cdn.example/subtitles_zh-Hans.sbv' => http.Response('''
0:00:00.000,0:00:02.000
Localized lesson subtitle
''', 200),
          'https://cdn.example/cuesheet.json' => http.Response('[]', 200),
          _ => http.Response('Not found', 404),
        };
      });
      final service = CourseLessonService(
        httpClient: client,
        cacheEnabled: false,
      );

      final lesson = await service.fetchLesson(
        const CourseCatalogItem(
          title: '02 - Coordinates',
          thumbnailUrl: 'https://cdn.example/thumbnail.png',
          videoUrl: 'https://cdn.example/video.mp4',
          subtitleUrl: 'https://cdn.example/subtitles.sbv',
          scriptUrl: 'https://cdn.example/cuesheet.json',
        ),
        locale: const Locale.fromSubtags(languageCode: 'zh', countryCode: 'CN'),
      );

      expect(
        requestedUrls,
        contains('https://cdn.example/subtitles_zh-Hans.sbv'),
      );
      expect(lesson.subtitles.single.text, 'Localized lesson subtitle');
    },
  );

  test(
    'fetchLesson falls back to English subtitle when localized file is absent',
    () async {
      final requestedUrls = <String>[];
      final client = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        return switch (request.url.toString()) {
          'https://cdn.example/subtitles.sbv' => http.Response('''
0:00:00.000,0:00:02.000
English lesson subtitle
''', 200),
          'https://cdn.example/cuesheet.json' => http.Response('[]', 200),
          _ => http.Response('Not found', 404),
        };
      });
      final service = CourseLessonService(
        httpClient: client,
        cacheEnabled: false,
      );

      final lesson = await service.fetchLesson(
        const CourseCatalogItem(
          title: '02 - Coordinates',
          thumbnailUrl: 'https://cdn.example/thumbnail.png',
          videoUrl: 'https://cdn.example/video.mp4',
          subtitleUrl: 'https://cdn.example/subtitles.sbv',
          scriptUrl: 'https://cdn.example/cuesheet.json',
        ),
        locale: const Locale('de'),
      );

      expect(requestedUrls, contains('https://cdn.example/subtitles_de.sbv'));
      expect(requestedUrls, contains('https://cdn.example/subtitles.sbv'));
      expect(lesson.subtitles.single.text, 'English lesson subtitle');
    },
  );

  test(
    'fetchLesson uses explicit localized subtitle URLs from catalog',
    () async {
      final requestedUrls = <String>[];
      final client = MockClient((request) async {
        requestedUrls.add(request.url.toString());
        return switch (request.url.toString()) {
          'https://cdn.example/zh/subtitles.sbv' => http.Response('''
0:00:00.000,0:00:02.000
Catalog mapped subtitle
''', 200),
          'https://cdn.example/cuesheet.json' => http.Response('[]', 200),
          _ => http.Response('Not found', 404),
        };
      });
      final service = CourseLessonService(
        httpClient: client,
        cacheEnabled: false,
      );

      final courses = CourseCatalogItem.fromJson({
        'title': '02 - Coordinates',
        'thumbnailUrl': 'https://cdn.example/thumbnail.png',
        'videoUrl': 'https://cdn.example/video.mp4',
        'subTitleUrl': 'https://cdn.example/subtitles.sbv',
        'scriptUrl': 'https://cdn.example/cuesheet.json',
        'subTitleUrls': {'zh-Hans': 'https://cdn.example/zh/subtitles.sbv'},
      });
      final lesson = await service.fetchLesson(
        courses,
        locale: const Locale.fromSubtags(languageCode: 'zh', countryCode: 'CN'),
      );

      expect(requestedUrls.first, 'https://cdn.example/zh/subtitles.sbv');
      expect(lesson.subtitles.single.text, 'Catalog mapped subtitle');
    },
  );

  test(
    'fetchLesson refreshes cached subtitle content for the same URL',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'course_cache_test',
      );
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });

      var subtitleText = 'First subtitle';
      final client = MockClient((request) async {
        return switch (request.url.toString()) {
          'https://cdn.example/subtitles.sbv' => http.Response('''
0:00:00.000,0:00:02.000
$subtitleText
''', 200),
          'https://cdn.example/cuesheet.json' => http.Response('[]', 200),
          _ => http.Response('Not found', 404),
        };
      });
      final service = CourseLessonService(
        httpClient: client,
        cacheDirectoryProvider: () async => tempDir,
      );
      const course = CourseCatalogItem(
        title: '02 - Coordinates',
        thumbnailUrl: 'https://cdn.example/thumbnail.png',
        videoUrl: 'https://cdn.example/video.mp4',
        subtitleUrl: 'https://cdn.example/subtitles.sbv',
        scriptUrl: 'https://cdn.example/cuesheet.json',
      );

      final firstLesson = await service.fetchLesson(course);
      subtitleText = 'Second subtitle';
      final secondLesson = await service.fetchLesson(course);

      expect(firstLesson.subtitles.single.text, 'First subtitle');
      expect(secondLesson.subtitles.single.text, 'Second subtitle');
    },
  );

  test('parseSbv parses timestamp ranges and multiline subtitle text', () {
    final cues = CourseLessonService.parseSbv('''
0:00:00.599,0:00:04.160
Welcome to the board.
This is a second subtitle line.

0:01:02.005,0:01:04.015
Find e4.
''');

    expect(cues, hasLength(2));
    expect(cues.first.start.inMilliseconds, 599);
    expect(cues.first.end.inMilliseconds, 4160);
    expect(
      cues.first.text,
      'Welcome to the board.\nThis is a second subtitle line.',
    );
    expect(cues.last.start.inMilliseconds, 62005);
    expect(cues.last.end.inMilliseconds, 64015);
    expect(cues.last.text, 'Find e4.');
  });

  test('parseSbv trims repeated tail overlap between consecutive cues', () {
    final cues = CourseLessonService.parseSbv('''
0:00:00.000,0:00:02.000
Welcome to the board and thanks for joining.

0:00:02.000,0:00:04.000
joining the course today.
''');

    expect(cues, hasLength(2));
    expect(cues.first.text, 'Welcome to the board and thanks for joining.');
    expect(cues.last.text, 'the course today.');
  });

  test('courseSubtitleTextAtPosition picks a single active cue', () {
    final cues = [
      const CourseSubtitleCue(
        start: Duration(seconds: 0),
        end: Duration(seconds: 5),
        text: 'First line',
      ),
      const CourseSubtitleCue(
        start: Duration(seconds: 3),
        end: Duration(seconds: 7),
        text: 'Second line',
      ),
    ];

    expect(courseSubtitleTextAtPosition(const Duration(seconds: 4), cues),
        'Second line');
  });

  test('parseScript parses checkpoint, target FEN, and LED arrays', () {
    final script = CourseLessonService.parseScript('''
[
  {
    "start_time": 1500,
    "check_point_title": "Put the knight on f3",
    "start_time_pause": true,
    "dest_fen": "8/8/8/8/8/5N2/8/8 w - - 0 1",
    "dest_fen_match_to_continue": true,
    "led": [
      "0x000000", "0xff0000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000",
      "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000",
      "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000",
      "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000",
      "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000",
      "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000",
      "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000",
      "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x000000", "0x00ff00"
    ]
  }
]
''');

    expect(script, hasLength(1));
    expect(script.single.startTime.inMilliseconds, 1500);
    expect(script.single.checkpointTitle, 'Put the knight on f3');
    expect(script.single.startTimePause, isTrue);
    expect(script.single.destFen, '8/8/8/8/8/5N2/8/8 w - - 0 1');
    expect(script.single.destFenMatchToContinue, isTrue);
    expect(script.single.led, hasLength(64));
    expect(script.single.led![1], 0xff0000);
    expect(script.single.led![63], 0x00ff00);
  });
}
