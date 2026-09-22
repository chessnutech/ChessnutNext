import 'package:flutter/widgets.dart';

enum AppLanguagePreference {
  system('system', null, 'Follow system'),
  zhHans(
    'zh-CN',
    Locale.fromSubtags(languageCode: 'zh', countryCode: 'CN'),
    '简体中文',
  ),
  zhHant(
    'zh-Hant',
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    '繁體中文',
  ),
  en('en', Locale('en'), 'English'),
  ja('ja', Locale('ja'), '日本語'),
  ko('ko', Locale('ko'), '한국어'),
  de('de', Locale('de'), 'Deutsch'),
  fr('fr', Locale('fr'), 'Français'),
  ru('ru', Locale('ru'), 'Русский'),
  pt('pt', Locale('pt'), 'Português'),
  es('es', Locale('es'), 'Español'),
  it('it', Locale('it'), 'Italiano'),
  nl('nl', Locale('nl'), 'Nederlands'),
  pl('pl', Locale('pl'), 'Polski'),
  ro('ro', Locale('ro'), 'Română'),
  cs('cs', Locale('cs'), 'Čeština'),
  ar('ar', Locale('ar'), 'العربية'),
  he('he', Locale('he'), 'עברית');

  const AppLanguagePreference(this.tag, this.locale, this.nativeLabel);

  final String tag;
  final Locale? locale;
  final String nativeLabel;

  static const supportedLocales = [
    Locale('en'),
    Locale.fromSubtags(languageCode: 'zh', countryCode: 'CN'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('de'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('nl'),
    Locale('ru'),
    Locale('pt'),
    Locale('pl'),
    Locale('ro'),
    Locale('cs'),
    Locale('ar'),
    Locale('he'),
  ];

  static AppLanguagePreference fromTag(String? tag) {
    final normalized = _normalizeTag(tag);
    if (const {'zh-cn', 'zh-hans', 'zh-sg'}.contains(normalized)) {
      return zhHans;
    }
    if (const {
      'zh-hant',
      'zh-tw',
      'zh-hk',
      'zh-mo',
    }.contains(normalized)) {
      return zhHant;
    }
    for (final preference in values) {
      if (preference.tag.toLowerCase() == normalized) return preference;
    }
    return system;
  }

  static Locale resolve(Locale? preferred, Iterable<Locale> supported) {
    final candidates = [
      if (preferred != null) preferred,
      WidgetsBinding.instance.platformDispatcher.locale,
    ];

    for (final candidate in candidates) {
      final matched = _matchLocale(candidate, supported);
      if (matched != null) return matched;
    }

    return supportedLocales.first;
  }

  static Locale? _matchLocale(Locale locale, Iterable<Locale> supported) {
    final normalized = _normalizeLocale(locale);
    for (final candidate in supported) {
      if (_sameLocale(candidate, normalized)) return candidate;
    }
    for (final candidate in supported) {
      if (candidate.languageCode == normalized.languageCode &&
          candidate.scriptCode == null) {
        return candidate;
      }
    }
    return null;
  }

  static bool _sameLocale(Locale a, Locale b) {
    return a.languageCode == b.languageCode &&
        (a.scriptCode ?? '') == (b.scriptCode ?? '') &&
        (a.countryCode ?? '') == (b.countryCode ?? '');
  }

  static Locale _normalizeLocale(Locale locale) {
    if (locale.languageCode.toLowerCase() == 'zh') {
      final country = locale.countryCode?.toUpperCase();
      if (locale.scriptCode == 'Hant' ||
          country == 'TW' ||
          country == 'HK' ||
          country == 'MO') {
        return const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
        );
      }
      return const Locale.fromSubtags(
        languageCode: 'zh',
        countryCode: 'CN',
      );
    }
    return locale;
  }

  String apiLanguage(Locale systemLocale) {
    final effective = _normalizeLocale(locale ?? systemLocale);
    final languageCode = effective.languageCode.toLowerCase();
    return _supportedLanguageCodes.contains(languageCode) ? languageCode : 'en';
  }

  String contentLanguage(Locale systemLocale) {
    final effective = _normalizeLocale(locale ?? systemLocale);
    if (effective.languageCode == 'zh') {
      return effective.scriptCode == 'Hant' ? 'zh-Hant' : 'zh-CN';
    }
    final languageCode = effective.languageCode.toLowerCase();
    return _supportedLanguageCodes.contains(languageCode) ? languageCode : 'en';
  }

  String commentaryLanguage(Locale systemLocale) {
    final effective = _normalizeLocale(locale ?? systemLocale);
    if (effective.languageCode == 'zh') {
      return effective.scriptCode == 'Hant' ? 'yue-HK' : 'zh-CN';
    }
    final languageCode = effective.languageCode.toLowerCase();
    return _commentaryLanguageCodes.contains(languageCode)
        ? languageCode
        : 'en';
  }
}

const _supportedLanguageCodes = <String>{
  'en',
  'zh',
  'de',
  'es',
  'fr',
  'it',
  'ja',
  'ko',
  'nl',
  'ru',
};

const _commentaryLanguageCodes = <String>{
  'en',
  'ja',
  'ko',
  'de',
  'fr',
  'ru',
  'pt',
  'es',
  'it',
  'nl',
  'pl',
  'ro',
  'cs',
  'ar',
  'he',
};

String _normalizeTag(String? tag) {
  final value = tag?.trim();
  if (value == null || value.isEmpty) return 'system';
  return value.replaceAll('_', '-').toLowerCase();
}
