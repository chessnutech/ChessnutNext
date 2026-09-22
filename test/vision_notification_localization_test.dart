import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chessnut_flutter_export/l10n/app_language.dart';

void main() {
  test('Vision notification and widget prompts cover every app language', () {
    Map<String, String> strings(String directory) {
      final xml = File('android/app/src/main/res/$directory/strings.xml')
          .readAsStringSync();
      return {
        for (final match
            in RegExp(r'<string name="(vision_[^"]+)">([^<]+)</string>')
                .allMatches(xml))
          match[1]!: match[2]!,
      };
    }

    final english = strings('values');
    expect(
        english.keys,
        containsAll([
          'vision_notification_channel',
          'vision_notification_title',
          'vision_notification_active_title',
          'vision_notification_recognizing',
          'vision_notification_ready',
          'vision_notification_board',
          'vision_accessibility_required',
        ]));
    for (final locale in AppLanguagePreference.supportedLocales) {
      final directory = switch (locale.languageCode) {
        'en' => 'values',
        'zh' when locale.scriptCode == 'Hant' => 'values-b+zh+Hant',
        'zh' => 'values-zh',
        'he' => 'values-iw',
        final language => 'values-$language',
      };
      final translated = strings(directory);
      expect(translated.keys, unorderedEquals(english.keys), reason: '$locale');
      for (final entry in translated.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: '$locale: ${entry.key}');
        if (locale.languageCode != 'en') {
          expect(entry.value, isNot(english[entry.key]),
              reason: '$locale: ${entry.key} must not fall back to English.');
        }
      }
    }
  });
}
