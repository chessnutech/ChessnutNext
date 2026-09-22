import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/l10n/app_language.dart';
import 'package:chessnut_flutter_export/l10n/app_strings.dart';
import 'package:chessnut_flutter_export/l10n/complete_visible_strings.dart';
import 'package:chessnut_flutter_export/l10n/generated_app_strings.dart';
import 'package:chessnut_flutter_export/l10n/manual_language_strings.dart';
import 'package:chessnut_flutter_export/l10n/localized_material.dart'
    as localized;
import 'package:chessnut_flutter_export/screens/settings_screen.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';

void main() {
  test('Lichess friend play copy covers every supported language', () {
    const sources = <String>[
      'Random match',
      'Friend match',
      'Challenge a Lichess player',
      'Lichess username',
      'Enter any Lichess username or select a followed user.',
      'Challenge player',
      'Waiting for the player to accept the challenge...',
      'The player declined the challenge.',
      'Play with a Lichess friend',
      'Refresh friends',
      'Checking whether this authorization can access your followed users...',
      'This Lichess authorization does not include friend-list access. Re-authorize Lichess to play with followed users.',
      'Incoming challenges',
      'Search followed users',
      'You are not following any Lichess users yet.',
      'No followed users match this search.',
      'Your color',
      'Cancel challenge',
      'Checking friend access...',
      'Challenge selected friend',
      'Retry friend access',
      'Friend access could not be checked. Check the network and try again.',
      'Sending Lichess challenge...',
      'Waiting for your friend to accept the challenge...',
      'Lichess authorization was not completed. Your existing authorization is unchanged.',
      'The new Lichess authorization is not ready yet. Please try again.',
      'Challenge accepted.',
      'Your friend declined the challenge.',
      'Challenge canceled.',
      'The challenge expired.',
      'This challenge is not compatible with Board API play.',
      'Challenge declined.',
      'Accept challenge',
      'Decline challenge',
      'Lichess could not create this challenge.',
      'Lichess could not cancel the challenge.',
      'Lichess could not accept the challenge.',
      'Lichess could not decline the challenge.',
      'Casual',
    ];
    for (final locale in AppLanguagePreference.supportedLocales) {
      if (locale.languageCode == 'en') continue;
      final strings = AppStrings(locale);
      final missing = sources.where((source) => strings.t(source) == source);
      expect(
        missing,
        isEmpty,
        reason: '${strings.localeKey} is missing Lichess friend copy: '
            '${missing.join(', ')}',
      );
    }
  });

  test('language preferences default to system and expose native labels', () {
    expect(AppLanguagePreference.system.locale, isNull);
    expect(AppLanguagePreference.fromTag(null), AppLanguagePreference.system);
    expect(
        AppLanguagePreference.fromTag('zh-Hans'), AppLanguagePreference.zhHans);
    expect(
        AppLanguagePreference.fromTag('zh-Hant'), AppLanguagePreference.zhHant);
    expect(
        AppLanguagePreference.fromTag('zh-CN'), AppLanguagePreference.zhHans);
    expect(
        AppLanguagePreference.fromTag('zh-Hans'), AppLanguagePreference.zhHans);
    expect(AppLanguagePreference.fromTag('pt'), AppLanguagePreference.pt);
    expect(AppLanguagePreference.fromTag('pl'), AppLanguagePreference.pl);
    expect(AppLanguagePreference.fromTag('ro'), AppLanguagePreference.ro);
    expect(AppLanguagePreference.fromTag('cs'), AppLanguagePreference.cs);
    expect(AppLanguagePreference.fromTag('ar'), AppLanguagePreference.ar);
    expect(AppLanguagePreference.fromTag('he'), AppLanguagePreference.he);
    expect(AppLanguagePreference.zhHans.nativeLabel, '简体中文');
    expect(AppLanguagePreference.zhHant.nativeLabel, '繁體中文');
    expect(AppLanguagePreference.ja.nativeLabel, '日本語');
    expect(AppLanguagePreference.ko.nativeLabel, '한국어');
    expect(AppLanguagePreference.ru.nativeLabel, 'Русский');
    expect(AppLanguagePreference.es.nativeLabel, 'Español');
    expect(
      AppLanguagePreference.values.map((language) => language.tag),
      [
        'system',
        'zh-CN',
        'zh-Hant',
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
      ],
    );
  });

  test('locale resolution maps Chinese regions to the right script', () {
    expect(
      AppLanguagePreference.resolve(
        const Locale('zh', 'CN'),
        AppLanguagePreference.supportedLocales,
      ),
      const Locale.fromSubtags(languageCode: 'zh', countryCode: 'CN'),
    );
    expect(
      AppLanguagePreference.resolve(
        const Locale('zh', 'TW'),
        AppLanguagePreference.supportedLocales,
      ),
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    );
    expect(
      AppLanguagePreference.resolve(
        const Locale('pt', 'BR'),
        AppLanguagePreference.supportedLocales,
      ),
      const Locale('pt'),
    );
  });

  test('content language follows every supported app language', () {
    const systemLocale = Locale('en');
    expect(AppLanguagePreference.en.contentLanguage(systemLocale), 'en');
    expect(AppLanguagePreference.zhHans.contentLanguage(systemLocale), 'zh-CN');
    expect(
        AppLanguagePreference.zhHant.contentLanguage(systemLocale), 'zh-Hant');
    expect(AppLanguagePreference.de.contentLanguage(systemLocale), 'de');
    expect(AppLanguagePreference.es.contentLanguage(systemLocale), 'es');
    expect(AppLanguagePreference.fr.contentLanguage(systemLocale), 'fr');
    expect(AppLanguagePreference.it.contentLanguage(systemLocale), 'it');
    expect(AppLanguagePreference.ja.contentLanguage(systemLocale), 'ja');
    expect(AppLanguagePreference.ko.contentLanguage(systemLocale), 'ko');
    expect(AppLanguagePreference.nl.contentLanguage(systemLocale), 'nl');
    expect(AppLanguagePreference.ru.contentLanguage(systemLocale), 'ru');
    expect(AppLanguagePreference.pt.contentLanguage(systemLocale), 'en');
    expect(AppLanguagePreference.pl.contentLanguage(systemLocale), 'en');
    expect(AppLanguagePreference.ro.contentLanguage(systemLocale), 'en');
    expect(AppLanguagePreference.cs.contentLanguage(systemLocale), 'en');
    expect(AppLanguagePreference.ar.contentLanguage(systemLocale), 'en');
    expect(AppLanguagePreference.he.contentLanguage(systemLocale), 'en');
    expect(
      AppLanguagePreference.system.contentLanguage(
        const Locale.fromSubtags(languageCode: 'zh', countryCode: 'TW'),
      ),
      'zh-Hant',
    );
    expect(
      AppLanguagePreference.system.contentLanguage(const Locale('pt', 'BR')),
      'en',
    );
    expect(AppLanguagePreference.zhHans.apiLanguage(systemLocale), 'zh');
    expect(AppLanguagePreference.zhHant.apiLanguage(systemLocale), 'zh');
    expect(AppLanguagePreference.fr.apiLanguage(systemLocale), 'fr');
    expect(AppLanguagePreference.ja.apiLanguage(systemLocale), 'ja');
    expect(
      AppLanguagePreference.system.apiLanguage(const Locale('pt', 'BR')),
      'en',
    );
  });

  test('commentary language uses the Grandeur request mapping', () {
    const systemLocale = Locale('en');
    const expected = <AppLanguagePreference, String>{
      AppLanguagePreference.zhHans: 'zh-CN',
      AppLanguagePreference.zhHant: 'yue-HK',
      AppLanguagePreference.en: 'en',
      AppLanguagePreference.ja: 'ja',
      AppLanguagePreference.ko: 'ko',
      AppLanguagePreference.de: 'de',
      AppLanguagePreference.fr: 'fr',
      AppLanguagePreference.ru: 'ru',
      AppLanguagePreference.pt: 'pt',
      AppLanguagePreference.es: 'es',
      AppLanguagePreference.it: 'it',
      AppLanguagePreference.nl: 'nl',
      AppLanguagePreference.pl: 'pl',
      AppLanguagePreference.ro: 'ro',
      AppLanguagePreference.cs: 'cs',
      AppLanguagePreference.ar: 'ar',
      AppLanguagePreference.he: 'he',
    };

    for (final entry in expected.entries) {
      expect(entry.key.commentaryLanguage(systemLocale), entry.value);
    }
    expect(
      AppLanguagePreference.system.commentaryLanguage(
        const Locale.fromSubtags(languageCode: 'zh', countryCode: 'HK'),
      ),
      'yue-HK',
    );
    expect(
      AppLanguagePreference.system.commentaryLanguage(
        const Locale.fromSubtags(languageCode: 'zh', countryCode: 'CN'),
      ),
      'zh-CN',
    );
    expect(
      AppLanguagePreference.system.commentaryLanguage(const Locale('pt', 'BR')),
      'pt',
    );
    expect(
      AppLanguagePreference.system.commentaryLanguage(const Locale('tr')),
      'en',
    );
  });

  test('new app languages expose translated core UI and RTL direction', () {
    const expectations = <String, String>{
      'pt': 'Configurações',
      'pl': 'Ustawienia',
      'ro': 'Setări',
      'cs': 'Nastavení',
      'ar': 'الإعدادات',
      'he': 'הגדרות',
    };

    for (final entry in expectations.entries) {
      final locale = Locale(entry.key);
      expect(AppStrings(locale).t('Settings'), entry.value);
      expect(AppStrings(locale).t('Board settings'), isNot('Board settings'));
    }

    expect(GlobalWidgetsLocalizations.delegate.isSupported(const Locale('ar')),
        isTrue);
    expect(GlobalWidgetsLocalizations.delegate.isSupported(const Locale('he')),
        isTrue);
  });

  test('commentary voice labels are translated for every non-English locale',
      () {
    const locales = <Locale>[
      Locale.fromSubtags(languageCode: 'zh', countryCode: 'CN'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      Locale('ja'),
      Locale('ko'),
      Locale('de'),
      Locale('fr'),
      Locale('ru'),
      Locale('pt'),
      Locale('es'),
      Locale('it'),
      Locale('nl'),
      Locale('pl'),
      Locale('ro'),
      Locale('cs'),
      Locale('ar'),
      Locale('he'),
    ];
    const labels = <String>[
      'Commentary voice',
      'Female voice',
      'Male voice',
    ];

    for (final locale in locales) {
      final strings = AppStrings(locale);
      for (final label in labels) {
        expect(
          strings.t(label),
          isNot(label),
          reason: '${strings.localeKey} falls back to English for "$label"',
        );
      }
    }
  });

  test('Vision recognition-only setting is translated for every locale', () {
    const locales = <Locale>[
      Locale.fromSubtags(languageCode: 'zh', countryCode: 'CN'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      Locale('ja'),
      Locale('ko'),
      Locale('de'),
      Locale('fr'),
      Locale('ru'),
      Locale('pt'),
      Locale('es'),
      Locale('it'),
      Locale('nl'),
      Locale('pl'),
      Locale('ro'),
      Locale('cs'),
      Locale('ar'),
      Locale('he'),
    ];
    const labels = <String>[
      'Vision recognition only',
      'Recognize and guide the physical board without simulating taps on the screen',
    ];

    for (final locale in locales) {
      final strings = AppStrings(locale);
      for (final label in labels) {
        expect(
          strings.t(label),
          isNot(label),
          reason: '${strings.localeKey} falls back to English for "$label"',
        );
      }
    }
  });

  test('French board labels preserve the accented capital E', () {
    const french = AppStrings(Locale('fr'));
    expect(french.t('Board'), 'Échiquier');
    expect(french.t('Board analyzer'), 'Échiquier analyseur');
    expect(french.t('Board settings'), 'Réglages de l’échiquier');
    expect(french.t('Board-aware'), 'Échiquier conscient');
  });

  test('completed manual languages cover every generated app string', () {
    final sources = {
      ...generatedAppStringMaps['zh-Hans']!.keys,
      'Analyze game',
      'Delete',
      'Refresh',
      'Draw',
      'Copy URL',
      'URL copied',
      'Live analysis',
      'Stockfish analysis in progress',
      'No games found',
      'Refresh PGN',
      'Puzzle ID',
      'Puzzle not found.',
      'Microphone permission denied.',
      'Connected',
      'Disconnected',
      'Keep playing while screen is off',
      'When enabled, active games continue while the screen is off. When disabled, screen-off play stops and the board LEDs turn off.',
      'Main menu',
      'Current move',
      'No Grandeur commentary is available for this move yet.',
      'Preparing PGN positions for evaluation.',
    };
    for (final language in const ['pt', 'pl', 'ro', 'cs', 'ar', 'he']) {
      final translations = manualLanguageStringMaps[language]!;
      final missing = sources.where(
        (source) => !translations.containsKey(source),
      );
      expect(missing, isEmpty, reason: '$language has missing translations');
      expect(translations.length, greaterThanOrEqualTo(sources.length));
    }
  });

  test('localization audit additions cover every supported app language', () {
    const unchangedTechnicalLabels = <String>{
      'Bluetooth',
      'Chess.com 10+5',
      'Lichess 10+5',
      'Maia 1500 / 10+5',
    };

    for (final locale in AppLanguagePreference.supportedLocales) {
      final strings = AppStrings(locale);
      if (strings.localeKey == 'en') continue;
      final missing = completeVisibleSourceStrings.where((source) {
        return !unchangedTechnicalLabels.contains(source) &&
            strings.t(source) == source;
      }).toList();
      expect(
        missing,
        isEmpty,
        reason: '${strings.localeKey} has untranslated audited UI strings:\n'
            '${missing.map((value) => '- $value').join('\n')}',
      );
    }
  });

  testWidgets('Arabic and Hebrew app localization use right-to-left layout', (
    tester,
  ) async {
    for (final language in const ['ar', 'he']) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: AppLanguagePreference.supportedLocales,
          localizationsDelegates: AppStrings.localizationsDelegates,
          home: const Scaffold(body: Text('RTL')),
        ),
      );

      expect(
        Directionality.of(tester.element(find.text('RTL'))),
        TextDirection.rtl,
      );
    }
  });

  test('screen-off play setting is translated in every app language', () {
    const sources = <String>[
      'Keep playing while screen is off',
      'When enabled, active games continue while the screen is off. When disabled, screen-off play stops and the board LEDs turn off.',
    ];

    for (final locale in AppLanguagePreference.supportedLocales) {
      if (!_hasCompleteTranslation(locale)) continue;
      final strings = AppStrings(locale);
      for (final source in sources) {
        expect(
          strings.t(source),
          locale.languageCode == 'en' ? source : isNot(source),
          reason: '${strings.localeKey}: $source',
        );
      }
    }
  });

  test('mistake book not-mastered label is translated in every app language',
      () {
    for (final locale in AppLanguagePreference.supportedLocales) {
      final strings = AppStrings(locale);
      expect(
        strings.t('Not mastered'),
        locale.languageCode == 'en' ? 'Not mastered' : isNot('Not mastered'),
        reason: '${strings.localeKey}: Not mastered',
      );
    }
  });

  testWidgets('settings language menu uses native names and applies locale', (
    tester,
  ) async {
    AppLanguagePreference selected = AppLanguagePreference.system;

    await tester.pumpWidget(
      _settingsHarness(
        preference: selected,
        locale: const Locale('en'),
        onChanged: (next) => selected = next,
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Follow system'), findsOneWidget);

    await tester
        .tap(find.byType(DropdownButtonFormField<AppLanguagePreference>).first);
    await tester.pumpAndSettle();

    expect(find.text('简体中文'), findsOneWidget);
    expect(find.text('繁體中文'), findsOneWidget);
    expect(find.text('日本語'), findsOneWidget);
    expect(find.text('한국어'), findsOneWidget);
    expect(find.text('Simplified Chinese'), findsNothing);

    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();

    expect(selected, AppLanguagePreference.zhHans);

    await tester.pumpWidget(
      _settingsHarness(
        preference: selected,
        locale:
            const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        onChanged: (next) => selected = next,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('界面'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
    expect(find.text('Interface'), findsNothing);
    expect(find.text('Language'), findsNothing);
    expect(find.text('Theme'), findsNothing);
    expect(find.text('Voice'), findsNothing);
    expect(find.text('Follow system'), findsNothing);

    final noticesTile = find.byKey(
      const ValueKey('settings-open-source-notices-tile'),
    );
    await tester.scrollUntilVisible(
      noticesTile,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(noticesTile);
    await tester.pumpAndSettle();

    expect(find.text('开源许可说明'), findsWidgets);
    expect(
      find.textContaining('Chessnut 使用开源国际象棋引擎和库'),
      findsOneWidget,
    );
    expect(
      find.text('用于评估、提示、机器人对局和分析的国际象棋引擎。'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.textContaining('为 Maia 3 机器人走棋和真人复盘提供支持'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('为 Maia 3 机器人走棋和真人复盘提供支持'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Chessnut uses open-source chess engines'),
      findsNothing,
    );
    expect(
      find.textContaining('Independent cloud service for Maia 3'),
      findsNothing,
    );
  });

  testWidgets('Android settings can toggle Vision recognition-only mode', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    var recognitionOnly = false;

    await tester.pumpWidget(
      _settingsHarness(
        preference: AppLanguagePreference.system,
        locale: const Locale('en'),
        onChanged: (_) {},
        visionRecognitionOnly: recognitionOnly,
        onVisionRecognitionOnlyChanged: (value) => recognitionOnly = value,
      ),
    );

    final setting = find.byKey(
      const ValueKey('settings-vision-recognition-only-switch'),
    );
    await tester.scrollUntilVisible(
      setting,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(setting, findsOneWidget);

    await tester.tap(setting);
    await tester.pump();
    expect(recognitionOnly, isTrue);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('localized material wrappers translate fields and tooltips', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        supportedLocales: AppLanguagePreference.supportedLocales,
        localizationsDelegates: AppStrings.localizationsDelegates,
        home: Scaffold(
          body: Column(
            children: [
              const localized.TextField(
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'Email',
                ),
              ),
              const localized.TextFormField(
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: 'Create a secure password.',
                ),
              ),
              localized.DropdownButtonFormField<String>(
                initialValue: 'all',
                decoration: const InputDecoration(labelText: 'Source'),
                items: const [
                  DropdownMenuItem(value: 'all', child: localized.Text('All')),
                ],
                onChanged: (_) {},
              ),
              localized.IconButton(
                tooltip: 'Show password',
                icon: const Icon(Icons.visibility_outlined),
                onPressed: () {},
              ),
              const localized.Tooltip(
                message: 'First move',
                child: SizedBox(width: 8, height: 8),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('邮箱'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('创建一个安全的密码。'), findsOneWidget);
    expect(find.text('来源'), findsOneWidget);
    expect(find.byTooltip('显示密码'), findsOneWidget);
    expect(find.byTooltip('第一步'), findsOneWidget);
  });

  testWidgets('offline auth copy is localized for Chinese users',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        supportedLocales: AppLanguagePreference.supportedLocales,
        localizationsDelegates: AppStrings.localizationsDelegates,
        home: Scaffold(
          body: Column(
            children: [
              localized.Text('Connection issue'),
              localized.Text(
                'No internet connection. Check Wi-Fi or mobile data, then try again.',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('连接异常'), findsOneWidget);
    expect(find.text('设备当前无法联网，请检查 Wi-Fi 或移动网络后重试。'), findsOneWidget);
  });

  test('generated visible-string translations cover representative pages', () {
    final representativeStrings = <String>{
      'Board settings',
      'Board diagnostics',
      'Disconnect board',
      'Move LEDs',
      'Board coordinates',
      'Game records',
      'Search games',
      'Opponent, opening, event, source',
      'Open report',
      'Download',
      'Engine Lab',
      'Train your chess style',
      'Train engines from your own games',
      'Training / pending',
      'Game Review',
      'Review a full PGN with Stockfish, Maia, and Grandeur to find strong moves, weak moves, turning points, and understand the game.',
      'Live analysis',
      'Game Record',
      'Choose from Game Record',
      'Filter your saved games here, preview the usable PGNs, then start training without leaving Engine Lab.',
      'Search player or event',
      'Min moves',
      'Max games',
      'Preview matching games',
      'Preview ready',
      'Preparing preview',
      'Game Record preview',
      'Lichess Player',
      'PGN Files',
      'Bot game',
      'Choose bot',
      'Bot game time uses minutes plus increment seconds.',
      'Thinking time',
      'Random side',
      'Ready to retry',
      'Loading themed puzzle...',
      'Puzzle number',
      'Puzzle ID',
      'Enter a valid puzzle number.',
      'Puzzle not found.',
      'Choose theme',
      'Change theme',
      'Choose one theme below the board.',
      'Puzzle themes could not load.',
      'This theme is not available yet. Try another theme.',
      'No puzzle was returned for this theme. Try another theme.',
      'More puzzle themes available for this session',
      'Fresh puzzle theme from the live library.',
      'Theme not available yet',
      'More themes',
      'Practice flow',
      'Practice with curated positions from the public Lichess puzzle set. Each run mixes themes and difficulty so the next tactic stays fresh.',
      'Local QA wallet tools',
      'Hidden unless the local QA build flag is enabled.',
      'No point activity yet.',
      'Analyze',
      'Bug report sent. Thank you for helping us fix it.',
      'Could not send the report. Please try again.',
      'Go to Daily Tasks',
      'Go to Daily Tasks to earn points, then return to Analysis.',
      'Grandeur review costs 100 wallet points.',
      'Grandeur Summary',
      'Position ready.',
      'FEN loaded.',
      'FEN load failed.',
      'Move the pieces to start analysis.',
      'Stockfish live analysis ready.',
      'Share a Standard or Grandeur report image.',
      'Share one report',
      'Your Chessnut Move firmware is current. If an update becomes available, it will appear here.',
      'Chessnut trains with most games and keeps a smaller set to check quality.',
      'Choose your games',
      'Train safely in the cloud',
      'Play your engine',
      'Completed builds become Bot game choices.',
      'Personal engines',
      'Cloud sync',
      'This quality score estimates how well the model predicts held-out games. Use it as the first signal for whether the model is useful in real play.',
      'Playable personal engines appear here and can be selected as Bot game choices when available.',
      'Default 791556',
      'Built-in',
      'Local file',
      'Playable engine library',
      'No playable personal engines yet. Finished builds will appear here once they are ready for Bot game.',
      'Manage in Engine Lab',
      'Training, reports, and playable personal engines live in Engine Lab.',
      'Unavailable',
      'Chessnut checks your uploaded games for style consistency and keeps a separate quality check set before the model is offered for play.',
      'Expected move prediction quality on games kept out of training.',
      'Whether the uploaded games follow one clear style.',
      'How useful the held-out games are for checking the model.',
      'Report generated from your training games and quality checks.',
      'Open-source notices',
      'Licenses and Maia 3 source code',
      'Maia 3 inference service',
      'Maia 3 is integrated through an independent cloud service. That service is published under AGPL-3.0, while the Chessnut app and main backend communicate with it only through network APIs.',
      'Open source code',
      'Could not open the source link. Please try again later.',
      'The app fetches public Lichess PGNs directly, then uploads the loaded PGNs when training starts.',
      'Grandeur is temporarily unavailable. Please try again later.',
      'The Grandeur summary is still being generated. Once it is ready, this page will show the full-game summary.',
      'The Grandeur coach report is still being generated. Once it is ready, this card will show the move commentary.',
      'LC0 uses trained weights from your local model library.',
      'Choose from 100ms to 60s. Auto adapts when clocks are active.',
      'Bot games only. Color LEDs rate moves when a piece is lifted.',
      'Move quality lights',
      'Use color LEDs when a piece is lifted',
      'QA wallet tools are unavailable.',
      'Wallet test tools are unavailable.',
      'Start training',
      'Personal engine training started',
      'Refresh training status',
      'Cloud records',
      'Find opponents and sync board moves',
      'Lichess online game',
      'Sign-in needed',
      'Play permission',
      'Include app logs and device details',
      'Importing Lichess history',
      'Import saved board games',
      'Saved games',
      'Import OTB',
      'Pull stored games from the connected board into Game Record.',
      'Sign in before importing saved board games.',
      'Connect a Chessnut board before importing saved games.',
      'Connect a board that supports saved game import.',
      'Saved game import is available through the Chessnut USB board service in this build.',
      'Reading board storage count.',
      'Chessnut could not read the board storage count.',
      'No saved games were found on the connected board.',
      'Found 2 saved games on the board. Chessnut will import every readable game.',
      'Checking board storage',
      'Cannot read storage count',
      'Saved games found',
      'No saved games found',
      'Chessnut is checking how many games are saved on the board.',
      'Try again after confirming the board is still connected.',
      '2 saved games will be imported after you tap Import.',
      'The connected board does not report any saved games.',
      'Clear imported game from board',
      'Optional. Leave this off until you confirm the game appears in Game records.',
      'Importing',
      'Clear',
      'Board games imported',
      'No readable saved game',
      'Ready to import',
      'Already imported',
      'Cannot import',
      'This saved game cannot be imported',
      'No saved board game is ready on the connected board.',
      'This saved game already exists in Game records and will be skipped.',
      'The game was imported, but Chessnut could not confirm it was cleared from board storage.',
      'This board record has too few positions to build a game.',
      'Move 1 could not be converted into a legal chess move.',
      'This board record could not be read as a legal game.',
      'A board game could not be imported.',
      '2 ply detected. Duplicate games will be skipped automatically.',
      'Records have been refreshed.',
      'You can leave this page and refresh records later.',
      'Collecting matching games',
      'Chessnut keeps working in the background.',
      'Confirm to start training from these games.',
      'Start training when the usable game count is enough.',
      'Verification took too long. Check your connection and try again.',
      'Verification could not open. Check your connection and try again.',
      'Verification failed. Please try again.',
      'Verification was incomplete. Please try again.',
      'Verification was cancelled.',
      'Verification could not open in the app',
      'Verification could not open in the app. Continue to try another way.',
      'Verification could not open in the app. Try the browser verification.',
      'Use 8+ characters and at least two types: uppercase, lowercase, number, or symbol.',
      '8+ characters',
      'At least two character types',
      'Uppercase',
      'Lowercase',
      'Number',
      'Symbol',
      'This PGN could not be read. Check the PGN text and try again.',
      'This PGN has no playable moves. Check the PGN text and try again.',
      'This PGN includes a move Chessnut cannot read. Check the move list and try again.',
      'Stockfish analysis failed. Please try again.',
      'Stockfish is not ready on this device. Showing a quick local review instead.',
      'Could not start the Lichess game search. Check your connection and authorize Lichess again.',
      'Looking for a Lichess game...',
      'Still looking for a game. You can wait a little longer or try again.',
      'Google sign in did not finish. Please try again.',
      'Apple sign in did not finish. Please try again.',
      'Courses could not load',
      'Check your connection and try refreshing the course library.',
      'Lesson could not load',
      'Check your connection and try opening this lesson again.',
      'Video could not load. Check your connection and try again.',
      'Copy failed. Please try again.',
      'Authorization could not open in the app. Check WebView2 and try again.',
      'Chess.com board could not open in the app',
      'Sign-in method unavailable',
      'Inbox is not available right now. Check your connection and try again.',
      'Message status could not be updated. Please try again.',
      'Lichess authorization is not available right now. Please try again later.',
      'Lichess sign-in status could not be checked. Please try again later.',
      'Linked account update failed. Please try again.',
      'Profile update is not available right now. Please try again later.',
      'Profile update failed. Check your connection and try again.',
      'Refresh records',
      'Games played on Chessnut will appear here after they sync.',
      'No cloud games found',
      'Try fewer filters or import games from Lichess first.',
      'Back to local list',
      'Finish this game before generating an analysis report.',
      'Game record deleted.',
      'Unable to delete this game record.',
      'Unable to search your cloud archive. Check your connection and try again.',
      'Delete record',
      'Delete game record?',
      'This removes the saved PGN from your Chessnut account. This action cannot be undone.',
      'From PGN',
      'From Lichess player',
      'From Chess.com username',
      'Local list',
      'Cloud search failed',
      'Previous page',
      'Next page',
      'Import Chess.com games',
      'Import Lichess games',
      'Import public finished games from one Chess.com username into Game Record. Chess.com archives can take a little time to publish very recent games.',
      'Import finished games from one Lichess player into Game Record. Duplicate games are skipped automatically.',
      'Player ID',
      'Rated only',
      'Casual only',
      'Rated and casual',
      'White games',
      'Black games',
      'Start import',
      'Enter a Chess.com username.',
      'Enter a Lichess player ID.',
      'Unable to start personal engine training.',
      'Personal engine training started. You can keep using the app while Chessnut trains it.',
      'Personal engine training is unavailable. Check Premium, points, or try again later.',
      'A personal engine training job is already running. Please wait for it to finish before starting a new one.',
      'Use points or upgrade Premium',
      'Standard plan',
      'Unable to preview Game Record.',
      'Unable to check training progress.',
      'Unable to cancel personal engine training.',
      'Training needs attention',
      'Training failed',
      'Training canceled',
      'Premium active / Grandeur and personal engine training unlimited',
      'Checked in today / Grandeur 100 / personal engine training 500',
      'Daily check-in available / Grandeur 100 / personal engine training 500',
      'Grandeur and personal engine training become unlimited.',
      'Paste a PGN before starting review.',
      'Unable to start Grandeur review.',
      'Grandeur is unlocked. Continuing the coach analysis...',
      'Report image ready to share.',
      'Unable to share report image.',
      'Grandeur review is being prepared...',
      'Grandeur review is preparing. You can come back later.',
      'Spend 100 points?',
      'Grandeur uses wallet points for the LLM coach review.',
      'Current balance',
      'Original cost',
      'Member discount',
      'Pay today',
      'Balance after review',
      'Start Grandeur review?',
      'Chessnut checks membership and wallet balance.',
      'Start Grandeur review',
      'Not enough points',
      'Sign in required',
      'Grandeur review uses your wallet balance.',
      'Wallet unavailable',
      'Checking wallet',
      'Grandeur report generating',
      'You can leave this page. Chessnut will keep working and save the report when it is ready.',
      'Analyze game',
      'Main menu',
      'Current move',
      'No Grandeur commentary is available for this move yet.',
      'Stockfish analysis in progress',
      'Preparing PGN positions for evaluation.',
      'Purchase was not completed. You can try again when ready.',
      'Auto-renewing plans get the best price',
      'Processing purchase',
      'Continue purchase',
      'Restore purchase',
      'One-time access',
      'Best price',
      'Sign in before upgrading membership.',
      'Sign in before restoring purchases.',
      'In-app purchase is available on iOS and Android.',
      'Restore purchase is available on iOS and Android.',
      'Store purchase is unavailable on this device. Install the official test or store version, sign in to the store, then try again.',
      'This Premium plan is not available in the store yet. Try another plan or come back later.',
      'The store could not start this purchase. Check your store account and payment setup, then try again.',
      'Purchase canceled. Your membership was not changed.',
      'Purchase is still pending. Check your store account later.',
      'No active membership purchase was found for this store account.',
      'Premium is active.',
      'Purchase verification failed. Check your network and try Restore purchase.',
      'Purchase failed. Check your store account and try again.',
      'Restore failed. Check your store account and try again.',
      'This record cannot be deleted from the cloud.',
      'Lichess authorization expired. Re-authorize before continuing.',
      'Linked accounts',
      'Linked account updated.',
      'Not linked',
    };

    for (final locale in AppLanguagePreference.supportedLocales) {
      if (!_hasCompleteTranslation(locale) || locale.languageCode == 'en') {
        continue;
      }
      final strings = AppStrings(locale);
      final missing = <String>[];
      for (final source in representativeStrings) {
        final translated = strings.t(source);
        if (translated == source) {
          missing.add(source);
        }
      }
      expect(
        missing,
        isEmpty,
        reason: '${strings.localeKey} is missing ${missing.length} strings:\n'
            '${missing.map((value) => '- $value').join('\n')}',
      );
    }
  });

  test('game over action translations are readable', () {
    const sources = <String>[
      'Analyze',
      'Analyze game',
      'Main menu',
    ];

    for (final locale in AppLanguagePreference.supportedLocales) {
      if (!_hasCompleteTranslation(locale) || locale.languageCode == 'en') {
        continue;
      }
      final strings = AppStrings(locale);
      for (final source in sources) {
        final translated = strings.t(source);
        expect(translated, isNot(source));
        expect(
          translated,
          isNot(contains('??')),
          reason: '${strings.localeKey} translated "$source" to "$translated"',
        );
      }
    }
  });

  test('Lichess seek setup copy is natural in Chinese', () {
    const zhHans = AppStrings(
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    );
    const zhHant = AppStrings(
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    );

    expect(
      zhHans.t(
        'Lichess is authorized. Once a 15+10 game is matched, Chessnut will sync moves to your board.',
      ),
      'Lichess 已授权。匹配到 15+10 对局后，Chessnut 会把走法同步到你的棋盘。',
    );
    expect(
      zhHant.t(
        'Lichess is authorized. Once a 15+10 game is matched, Chessnut will sync moves to your board.',
      ),
      'Lichess 已授權。配對到 15+10 對局後，Chessnut 會把著法同步到你的棋盤。',
    );
  });

  test('spectator URL copy action is localized in Chinese', () {
    const zhHans = AppStrings(
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    );
    const zhHant = AppStrings(
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    );

    expect(zhHans.t('Copy URL'), '复制URL');
    expect(zhHans.t('URL copied'), 'URL已复制');
    expect(zhHant.t('Copy URL'), '複製URL');
    expect(zhHant.t('URL copied'), 'URL已複製');
  });

  test('recent full-page strings are localized and readable', () {
    const sourceGroups = <String, List<String>>{
      'Lichess authorization': <String>[
        'Lichess authorization is not available right now. Please try again later.',
        'Lichess authorization could not open. Try again later.',
        'Opening Lichess authorization...',
        'Authorization could not open in the app. Check WebView2 and try again.',
        'Lichess authorization was not completed. Try again when the Lichess page finishes.',
        'Complete authorization on this page.',
        'Chessnut will return automatically after Lichess shows the authorization callback.',
        'Lichess authorization complete.',
        'Returning to Chessnut...',
        'Close authorization',
      ],
      'LC0 weights': <String>[
        'Playable engine library',
        'No playable personal engines yet. Finished builds will appear here once they are ready for Bot game.',
        'Manage in Engine Lab',
        'Training, reports, and playable personal engines live in Engine Lab.',
        'Unavailable',
      ],
      'Game over': <String>[
        'Game over',
        'Analyze game',
        'Main menu',
      ],
      'Turnstile errors': <String>[
        'Verification took too long. Check your connection and try again.',
        'Verification could not open. Check your connection and try again.',
        'Verification failed. Please try again.',
        'Verification was incomplete. Please try again.',
        'Verification was cancelled.',
        'Verification could not open in the app',
        'Verification could not open in the app. Continue to try another way.',
        'Verification could not open in the app. Try the browser verification.',
      ],
      'Common actions': <String>[
        'Cancel',
        'Checking',
        'Close',
        'Continue',
        'Continue bot game',
        'Continue online game',
        'Done',
        'Save',
        'Sign in',
        'Try again',
        'Not now',
        'Resume',
        'Restore purchase',
        'Continue purchase',
        'Sign out?',
        'You will return to the login screen. Your saved games remain on this device.',
      ],
    };

    final unreadableByLocale = <String>[];
    for (final locale in AppLanguagePreference.supportedLocales) {
      if (!_hasCompleteTranslation(locale) || locale.languageCode == 'en') {
        continue;
      }
      final strings = AppStrings(locale);
      final unreadable = <String>[];
      for (final entry in sourceGroups.entries) {
        for (final source in entry.value) {
          final issue = _readableTranslationIssue(
            strings: strings,
            source: source,
            group: entry.key,
          );
          if (issue != null) unreadable.add(issue);
        }
      }
      unreadableByLocale.addAll(
        unreadable.map((issue) => '${strings.localeKey}: $issue'),
      );
    }
    expect(
      unreadableByLocale,
      isEmpty,
      reason: 'Unreadable recent strings:\n'
          '${unreadableByLocale.map((value) => '- $value').join('\n')}',
    );
  });

  test('latest UI copy is localized across supported languages', () {
    const sourceGroups = <String, List<String>>{
      'Daily Tasks': <String>[
        'Complete daily activities to earn Chessnut points',
        'Complete one Career challenge',
        'Finish a Career Mode challenge game.',
        'A compact daily loop for learning, playing, Career challenges, and reviews.',
      ],
      'Voice moves': <String>[
        'Voice moves require a network connection. Choose the correct speech language to improve recognition success.',
        'Chessnut uses the microphone only while voice moves are on.',
        'Voice moves use online speech recognition. Check your network connection and try again.',
      ],
      'Grandeur coach styles': <String>[
        'Deep analyst',
        'Calm, careful, detailed',
        'About 2 min',
        'A full-game study with patient explanations, turning points, plans, missed chances, move quality, and concrete training takeaways. Best when you want the richest report and can wait longer.',
        'Rapid coach',
        'Faster, focused review',
        'About 30 sec',
        'Highlights the most important moments first, keeps explanations shorter, and gives clear next steps. Good for quickly understanding what changed the game.',
        'Friendly guide',
        'Beginner and kid friendly',
        'Guided',
        'Uses plain language, encouragement, and guiding questions. It explains ideas gently so newer players can understand mistakes, strong moves, and better habits.',
      ],
      'Grandeur generation': <String>[
        'Summary in progress',
        'The Grandeur summary is still being generated. The full-game summary will appear here when the report is ready.',
      ],
      'Engine Lab': <String>[
        'Engine market',
        'Manage custom LC0 models trained from your own games.',
        'Download Chessnut-provided LC0 engines.',
        'Build your own LC0 engines and enable completed models.',
        'Bot game engine library',
        'Enabled personal and market engines appear in Bot game LC0 choices.',
        'Curated LC0 engines',
        'Popular LC0 community weights selected and provided by Chessnut. Download and enable the engines you want in Bot game.',
        'No curated LC0 engines are available right now. Pull to refresh later.',
        'Search personal engines',
        'No personal engines yet',
        'Start training from Game Record, Lichess, or PGN files. Your real cloud jobs will appear here after they are created.',
        'New personal engine',
        'My personal engine',
        'Choose one PGN source. Minimum 20 games, 50+ recommended.',
        'Premium training is unlimited',
        'Use one clean source and keep games from the same player or style for better results.',
        'Engine details',
        'Engine name',
        'Training rules',
        'Use one source only. Choose games from the same player or style. Training continues in the background after submission.',
        'Choose from Game Record',
        'Filter your saved games here, preview the usable PGNs, then start training without leaving Engine Lab.',
        'Preview matching games',
        'Preview found games',
        'Too many games selected',
        'Select more games',
        'Use selected',
        'No games loaded for this page.',
        'Select page',
        'Clear page',
        'Keep first 200',
        'Import by Lichess player id',
        'The app fetches public Lichess PGNs directly, then uploads the loaded PGNs when training starts.',
        'Any speed',
        'Rated only',
        'Casual only',
        'Rated and casual',
        'White games',
        'Black games',
        'Any color',
        'Choose PGN files',
        'Desktop can select one multi-game PGN or multiple single-game PGNs. The app merges them before upload.',
        'Reading files',
        'Selected PGN files',
        'Training games',
        'Model Fitting Degree',
        'Data Effectiveness',
        'PGN samples',
        'This engine cannot be liked yet.',
        'Unable to update like. Try again later.',
        'Engine enabled for Bot game.',
        'Engine disabled.',
        'Unable to update this engine. Try again later.',
        'This LC0 engine is not ready to download yet.',
        'Unable to download this LC0 engine. Check your connection and try again.',
        'This personal engine is still training.',
        'This personal engine does not have a weight file yet.',
        'Unable to download this personal engine. Check your connection and try again.',
        'Unable to update this personal engine. Check your connection and try again.',
        'Personal engine deleted.',
        'Unable to delete this personal engine. Try again later.',
        'Enter an engine name before saving.',
        'This personal engine cannot be renamed yet.',
        'Engine name updated.',
        'Unable to update this engine name. Try again later.',
        'Add an engine name before starting training.',
        'No usable PGN games matched these filters.',
        'Unable to load the matched Game Record preview.',
        'Submitting selected games for personal engine training...',
        'Import or preview games before starting training.',
        'Downloaded personal engine',
        'This personal engine is downloaded locally and ready for Bot game.',
        'Local engine library',
        'Local download',
        'Imported training games',
        'Lichess games',
        'Chessnut game records',
        'Imported PGN batch',
        'Chessnut training games',
        'Ready for Bot game',
        'Training in cloud',
        'Waiting for training',
        'Personal style',
        'Popular LC0 community weight selected and packaged by Chessnut for Bot game play.',
      ],
    };

    final unreadableByLocale = <String>[];
    for (final locale in AppLanguagePreference.supportedLocales) {
      if (!_hasCompleteTranslation(locale) || locale.languageCode == 'en') {
        continue;
      }
      final strings = AppStrings(locale);
      for (final entry in sourceGroups.entries) {
        for (final source in entry.value) {
          final issue = _readableTranslationIssue(
            strings: strings,
            source: source,
            group: entry.key,
          );
          if (issue != null) {
            unreadableByLocale.add('${strings.localeKey}: $issue');
          }
        }
      }
    }

    expect(
      unreadableByLocale,
      isEmpty,
      reason: 'Unlocalized latest UI copy:\n'
          '${unreadableByLocale.map((value) => '- $value').join('\n')}',
    );
  });

  test('Board analyzer Stockfish status copy is localized', () {
    const sources = <String>[
      'Stockfish is evaluating the current board.',
      'Stockfish is analyzing without a depth limit.',
      'Stockfish live analysis ready.',
      'Lightweight analysis ready.',
      'Stockfish is not available here. Check engine files or try another platform.',
      'Unlimited analysis selected.',
      'Stockfish is still thinking at depth 12.',
      'Analysis depth 12 selected.',
    ];
    for (final locale in AppLanguagePreference.supportedLocales) {
      if (locale.languageCode == 'en') continue;
      final strings = AppStrings(locale);
      for (final source in sources) {
        expect(
          strings.t(source),
          isNot(source),
          reason: '${strings.localeKey} still shows English: $source',
        );
      }
    }
  });

  test('critical visible strings do not fall back to English or placeholders',
      () {
    const sourceGroups = <String, List<String>>{
      'IAP and membership': <String>[
        'Purchase was not completed. You can try again when ready.',
        'Store purchase is unavailable on this device. Install the official test or store version, sign in to the store, then try again.',
        'This Premium plan is not available in the store yet. Try another plan or come back later.',
        'The store could not start this purchase. Check your store account and payment setup, then try again.',
        'Purchase failed. Check your store account and try again.',
        'Restore failed. Check your store account and try again.',
        'Purchase verification failed. Check your network and try Restore purchase.',
        'Auto-renewing plans get the best price',
        'Processing purchase',
        'One-time access',
      ],
      'Game Record': <String>[
        'Refresh records',
        'Games played on Chessnut will appear here after they sync.',
        'No cloud games found',
        'Records have been refreshed.',
        'Importing Lichess history',
        'You can leave this page and refresh records later.',
        'Collecting matching games',
        'Cloud records',
        'Cloud search failed',
        'This record cannot be deleted from the cloud.',
      ],
      'Personal engine training': <String>[
        'Unable to start personal engine training.',
        'Personal engine training started. You can keep using the app while Chessnut trains it.',
        'Personal engine training is unavailable. Check Premium, points, or try again later.',
        'A personal engine training job is already running. Please wait for it to finish before starting a new one.',
        'Train safely in the cloud',
        'Preparing preview',
        'Chessnut keeps working in the background.',
        'Confirm to start training from these games.',
        'Start training when the usable game count is enough.',
        'Unable to check training progress.',
        'Unable to cancel personal engine training.',
        'Training needs attention',
        'Training failed',
        'Training canceled',
      ],
      'Maia 3': <String>[
        'Maia3 review',
        'Open-source notices',
        'Licenses and Maia 3 source code',
        'Maia 3 inference service',
        'Maia 3 is integrated through an independent cloud service. That service is published under AGPL-3.0, while the Chessnut app and main backend communicate with it only through network APIs.',
        'Chessnut uses open-source chess engines and libraries. The package includes license notices, and corresponding source links are listed below.',
        'Chess engine used for evaluation, hints, bots, and analysis.',
        'Neural-network chess engine used for LC0 and Maia-compatible play.',
        'Chess rules, move generation, FEN, and PGN handling.',
        'Chess board UI used by the virtual board.',
        'Maia 1 weights',
        'See Maia Chess project notices',
        'Human-like chess model weights for Maia bot play.',
        'Independent cloud service for Maia 3 bot moves and human review. The service source is published separately.',
        'Open source code',
        'Could not open the source link. Please try again later.',
      ],
      'Maia3 Human Review': <String>[
        'Maia3 Human Review is preparing...',
        'Maia3 Human Review ready.',
        'Maia3 Human Review',
        'Review settings',
        'Maia3 official rating model',
        'Compare with Stockfish',
        'Show human likelihood next to the engine verdict.',
        'Start Maia3 Review',
        'Choose the human rating to review against, then start Maia3.',
        'Human move model',
        'Maia3 estimates likely human choices, not engine-best moves.',
        'Engine comparison',
        'Maia3 explains human likelihood. Stockfish checks objective quality.',
        'Human move probabilities',
        'Human likelihood',
        'Maia3 estimates what humans at this strength are likely to play.',
        'Human match',
        'More typical side',
        'Move likelihood',
        'Candidate moves are human probabilities, not best-move scores.',
        'Select a move after Maia3 finishes to see human move probabilities.',
        'Played move',
        'Natural and strong',
        'Common mistake',
        'Engine-like move',
        'Unusual mistake',
        'Stockfish ready',
        'Stockfish pending',
      ],
      'Terms and privacy': <String>[
        'Terms of Use',
        'Privacy Policy',
        'Service changes and availability',
        'Optional tools and third-party links',
        'Prohibited uses',
        'Disclaimer and limitation of liability',
        'Account, board, and game data',
        'Contact support',
      ],
      'Return and exit prompts': <String>[
        'Game still in progress',
        'Leave for now and continue later from Game Record, or resign to end the game as a loss.',
        'Leave for now and continue later from Game Record or Home. The online clock may keep running. You can also resign to end the game as a loss.',
        'Leave for now',
        'Resign and exit',
        'Confirm resignation?',
        'This will end the game immediately and record it as a loss. You cannot continue this game after resigning.',
        'Confirm resign',
      ],
      'Game Record filters': <String>[
        'Filters',
        '3 active',
        'Since',
        'Until',
        'Import at least 1 game.',
      ],
      'Grandeur summary': <String>[
        'Summary',
        'Close Grandeur',
        'Statistics List',
        'Accuracy and move quality by side',
      ],
      'Mistake Book': <String>[
        'Loading mistakes from your saved reviews...',
        'No review mistakes yet',
        'Run a Standard report from Game Review. Mistakes and blunders will appear here automatically.',
        'Analyze a game',
        'No due reviews right now. New analysis mistakes will appear here.',
        'Replay the position before the mistake and find the better move.',
        'Total saved',
        'No active themes',
        'Best move: Qh7#',
        'All caught up. New review mistakes will appear when they are due.',
        'Correct. This position is scheduled for later review.',
        'Try again, or compare with the best move above.',
      ],
      'Release cleanup errors': <String>[
        'Stockfish analysis failed. Please try again.',
        'Stockfish is not ready on this device. Showing a quick local review instead.',
        'This PGN could not be read. Check the PGN text and try again.',
        'This PGN has no playable moves. Check the PGN text and try again.',
        'This PGN includes a move Chessnut cannot read. Check the move list and try again.',
        'Could not start the Lichess game search. Check your connection and authorize Lichess again.',
        'Looking for a Lichess game...',
        'Still looking for a game. You can wait a little longer or try again.',
        'Google sign in did not finish. Please try again.',
        'Apple sign in did not finish. Please try again.',
        'Courses could not load',
        'Check your connection and try refreshing the course library.',
        'Lesson could not load',
        'Check your connection and try opening this lesson again.',
        'Video could not load. Check your connection and try again.',
        'Copy failed. Please try again.',
        'Inbox is not available right now. Check your connection and try again.',
        'Message status could not be updated. Please try again.',
        'Lichess sign-in status could not be checked. Please try again later.',
        'Linked account update failed. Please try again.',
        'Profile update is not available right now. Please try again later.',
        'Profile update failed. Check your connection and try again.',
      ],
      'Visible sweep': <String>[
        'Lichess authorized.',
        'Lichess authorized',
        'Spend 0 points',
        'Spend 100 points',
        'Verifying',
        'Live evaluation',
        'Firmware update',
        'Board link ready',
        'Waiting for piece status',
        'Keep Chessnut Move connected. Piece positions and batteries will appear when the board reports them.',
        'Continue learning',
        'Learn with your board',
        'Videos pause for hands-on checkpoints.',
        'Checkpoints can resume automatically when the position matches.',
        'Interactive lesson',
        'Lesson board',
        'Watch the video. The board will pause when a move is needed.',
        'Canceling',
        'Deleting',
        'Low battery',
        'What went wrong?',
        'Add screenshot or video',
        'Minutes',
        'Play style',
        'Official no-search Maia. More human-distribution faithful, but may allow obvious mistakes.',
        'More stable Maia play with a small search to reduce obvious blunders.',
        'Tactical depth',
        'Higher depth feels stronger, but less like raw Maia Elo.',
        'Sign in and choose games on Chess.com.',
        'Move control can be changed',
        'Place the pieces on your physical board to match the lesson position.',
        'USB Clock Test',
        'Connection Status',
        'Last Button Pressed',
        'Set LEFT',
        'Set RIGHT',
        'Event Log',
        'No events yet',
        'Complete authorization on this page.',
        'Report ready',
        'Pre-analyzing report',
        'Local estimate',
        'Local analysis status',
        'Stockfish analysis in progress',
        'Preparing PGN positions for evaluation.',
        'Solved puzzles add points after sync',
        'Loading puzzle database...',
        'One theme',
        'This FEN is not legal.',
        'Paste a valid board FEN before sending.',
        'Board not connected',
        'Connect a physical board before sending FEN.',
        'FEN send failed',
        'The app preview updated and the physical board now guides the setup.',
        'The physical board did not accept the FEN command.',
        'Move delay',
        'Automatic switch press',
        'Choose when the clock hardware switch is pressed for you.',
        'Confirm moves with switch',
        'Hold board moves until the clock switch is pressed.',
        'No firmware update is available from the connected board service right now.',
        'Import saved board games',
        'Saved games',
        'Import OTB',
        'Pull stored games from the connected board into Game Record.',
        'Sign in before importing saved board games.',
        'Connect a Chessnut board before importing saved games.',
        'Connect a board that supports saved game import.',
        'Saved game import is available through the Chessnut USB board service in this build.',
        'Reading board storage count.',
        'Chessnut could not read the board storage count.',
        'No saved games were found on the connected board.',
        'Found 2 saved games on the board. Chessnut will import every readable game.',
        'Checking board storage',
        'Cannot read storage count',
        'Saved games found',
        'No saved games found',
        'Chessnut is checking how many games are saved on the board.',
        'Try again after confirming the board is still connected.',
        '2 saved games will be imported after you tap Import.',
        'The connected board does not report any saved games.',
        'Clear imported game from board',
        'Optional. Leave this off until you confirm the game appears in Game records.',
        'Importing',
        'Clear',
        'Board games imported',
        'No readable saved game',
        'Ready to import',
        'Already imported',
        'Cannot import',
        'This saved game cannot be imported',
        'No saved board game is ready on the connected board.',
        'This saved game already exists in Game records and will be skipped.',
        'The game was imported, but Chessnut could not confirm it was cleared from board storage.',
        'This board record has too few positions to build a game.',
        'Move 1 could not be converted into a legal chess move.',
        'This board record could not be read as a legal game.',
        'A board game could not be imported.',
        '2 ply detected. Duplicate games will be skipped automatically.',
        'Connect a board to change live hardware settings.',
        'No piece status yet',
        'Refresh courses',
        'Loading courses',
        'No courses found',
        'Preparing lesson',
        'Send report',
        'Sending',
        'Local Maia weights, 1100-1900 strength',
        'Maia 3 strength',
        'Linked accounts',
        'Linked account updated.',
        'Keep linked',
        'Unlink Lichess',
        'Connected as',
        'Your Chessnut account is already connected to Lichess. You can keep this link, or unlink it if you want to authorize a different Lichess account.',
        'Models',
        'Spend 100 points?',
        'Grandeur uses wallet points for the LLM coach review.',
        'Current balance',
        'Original cost',
        'Member discount',
        'Pay today',
        'Balance after review',
        'Start Grandeur review?',
        'Start Grandeur review',
        'Grandeur normally costs 100 wallet points. Members pay 0 points automatically. If your points are not enough, you can earn more from Daily Tasks.',
        'Not enough points',
        'Go to Daily Tasks',
        'Wallet unavailable',
        'Grandeur report generating',
        'You can leave this page. Chessnut will keep working and save the report when it is ready.',
        'From PGN',
        'From Lichess player',
        'From Chess.com username',
        'Local list',
        'Cloud search failed',
        'Previous page',
        'Next page',
        'Start import',
        'Delete record',
        'Delete game record?',
        'This removes the saved PGN from your Chessnut account. This action cannot be undone.',
        '2 selected',
        'Delete selected records',
        'Delete selected records?',
        'Delete 2 records',
        '2 game records deleted.',
        'This removes the selected PGNs from your Chessnut account. This action cannot be undone.',
        'Video lessons that pause for your Chessnut board',
        'Fetching the latest Chessnut lesson library.',
        'The course catalog is empty right now.',
        'Board checks',
        'Physical board',
        'Playable engine library',
        'No playable personal engines yet. Finished builds will appear here once they are ready for Bot game.',
        'Manage in Engine Lab',
        'Training, reports, and playable personal engines live in Engine Lab.',
        'Sign in required',
        'Grandeur review uses your wallet balance.',
        'Current move',
        'This record cannot be deleted from the cloud.',
        'Invalid FEN',
        'Piece pairing will use the connected Chessnut Move and save the selected channel to its board profile.',
        'Press clock switch',
        'Loading subtitles and board checkpoints.',
        'Refresh records',
        'No cloud games found',
        'Try fewer filters or import games from Lichess first.',
        'Ignore continue reminder',
        'Show files and ranks on virtual boards',
        'Board Settings lets you choose Direct control or Web control for physical board moves.',
        'Close authorization',
        'Chessnut will return automatically after Lichess shows the authorization callback.',
        'Lichess authorization complete.',
        'Returning to Chessnut...',
        'Lichess authorization could not open.',
        'Auto-renewing plans get the best price',
        'Restore purchase',
        'Best price',
        'Store restore failed. Please try again.',
        'Direct control',
        'Web control',
        'Faster when supported, with automatic fallback.',
        'More compatible with website changes.',
        'Modern motion',
        'Tap to use',
        'Training modes',
        '4 tools',
        'pts',
      ],
    };

    final unreadableByLocale = <String>[];
    for (final locale in AppLanguagePreference.supportedLocales) {
      if (!_hasCompleteTranslation(locale) || locale.languageCode == 'en') {
        continue;
      }
      final strings = AppStrings(locale);
      for (final entry in sourceGroups.entries) {
        for (final source in entry.value) {
          final issue = _readableTranslationIssue(
            strings: strings,
            source: source,
            group: entry.key,
          );
          if (issue != null) {
            unreadableByLocale.add('${strings.localeKey}: $issue');
          }
        }
      }
    }

    expect(
      unreadableByLocale,
      isEmpty,
      reason: 'Unreadable critical strings:\n'
          '${unreadableByLocale.map((value) => '- $value').join('\n')}',
    );
  });

  test('Engine Lab dynamic copy keeps counts while localizing labels', () {
    final sources = <String>[
      '500 points per training',
      'Premium active until 2026-07-03.',
      'Personal engine 42',
      'LC0 weight 99',
      'Alice\'s games',
      'My Engine is ready for Bot game.',
      'My Engine is enabled for Bot game.',
      'My Engine is disabled.',
      '2 enabled',
      '8 engines',
      'Page 1 / 4',
      '64 games / Lichess storm123',
      '64 matched / 80 total / 20 selected. Select 20-200 games for training.',
      '64 matched / page 1 of 4',
      '200 selected / 20 on this page',
      '64 games ready',
      '64 games ready / 50+ recommended',
      '220 games / maximum 200',
      'Showing 20 sample games from 200 matched games.',
      '2 PGN files',
      'Preparing 180 selected Game Record PGNs for training...',
      'Select at most 200 games before starting training.',
      'Select at least 20 games before starting training.',
      'Only 10 usable games were selected. At least 20 games are required before starting training.',
      'White: Alice / Black: Bob',
      'Bot / Time: 10+5',
      'Date: 2026-07-03',
      'Location: Chessnut App',
      'Trained from 64 games / Source: Lichess games / Ready for Bot game.',
      'Trained from selected games / Source: Chessnut game records / Training in cloud.',
      'Model accuracy 72.0%',
      'Target > 50%',
    ];

    final unreadableByLocale = <String>[];
    for (final locale in AppLanguagePreference.supportedLocales) {
      if (!_hasCompleteTranslation(locale) || locale.languageCode == 'en') {
        continue;
      }
      final strings = AppStrings(locale);
      for (final source in sources) {
        final issue = _readableTranslationIssue(
          strings: strings,
          source: source,
          group: 'Engine Lab dynamic',
        );
        if (issue != null) {
          unreadableByLocale.add('${strings.localeKey}: $issue');
        }
      }
    }

    expect(
      unreadableByLocale,
      isEmpty,
      reason: 'Unreadable Engine Lab dynamic copy:\n'
          '${unreadableByLocale.map((value) => '- $value').join('\n')}',
    );
  });

  test('generated visible string maps do not keep known placeholder values',
      () {
    const generatedSources = <String>{
      'Additional live tags returned by the puzzle backend',
      'Analyze',
      'Building / queued',
      'Download',
      'Example: Air+ connected, then bot game showed an illegal move warning after ...',
      'Includes app version, platform, current screen, board status, and recent logs.',
      'Loading themed puzzle...',
      'More themes',
      'No point activity yet.',
      'Practice flow',
      'Ready to retry',
      'Reset board',
      'Use one clean PGN source, queue training on the server, then play it in Bot game.',
    };

    final unreadable = <String>[];
    for (final entry in generatedAppStringMaps.entries) {
      for (final source in generatedSources) {
        final translated = entry.value[source];
        if (translated == null) continue;
        final issue = _readableValueIssue(
          localeKey: entry.key,
          source: source,
          translated: translated,
          group: 'generated',
        );
        if (issue != null) unreadable.add('${entry.key}: $issue');
      }
    }

    expect(
      unreadable,
      isEmpty,
      reason: 'Unreadable generated visible strings:\n'
          '${unreadable.map((value) => '- $value').join('\n')}',
    );
  });

  test('background task progress keeps counts when localized', () {
    const locale = Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hans',
    );
    const strings = AppStrings(locale);

    final importStatus = strings.t(
      '23/100 processed / 18 new / 4 skipped / 1 failed You can leave this page and refresh records later.',
    );
    expect(importStatus, contains('23/100'));
    expect(importStatus, contains('18'));
    expect(importStatus, contains('4'));
    expect(importStatus, contains('1'));
    expect(importStatus, isNot(contains('processed')));

    final modelBuildStatus = strings.t(
      '12/20 checked / 10 usable / 1 skipped / 1 failed Chessnut keeps working in the background.',
    );
    expect(modelBuildStatus, contains('12/20'));
    expect(modelBuildStatus, contains('10'));
    expect(modelBuildStatus, contains('1'));
    expect(modelBuildStatus, isNot(contains('checked')));
  });

  test('account wallet clock and motion labels localize without losing terms',
      () {
    const strings = AppStrings(
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    );

    expect(strings.t('Account settings'), '账户设置');
    expect(strings.t('Off'), '关闭');
    expect(strings.t('Opponent move only'), '仅对手走棋后自动');
    expect(strings.t('Both sides'), '双方走棋后都自动');
    expect(strings.t('Modern motion'), '现代动效');
    expect(
      strings.t(
        'Visual effects improve motion and polish, but can feel slower on older devices.',
      ),
      isNot(contains('Visual effects')),
    );
    expect(strings.t('Daily tasks'), '每日任务');
    expect(strings.t('Daily Tasks'), '每日任务');
    expect(strings.t('points'), '积分');
    expect(strings.t('pts'), '积分');
    expect(strings.t('3/6 done'), '3/6 已完成');
    expect(strings.t('daily reward available'), '每日奖励可领取');

    final walletHint = strings.t(
      'Daily check-in available / Grandeur 100 / Model Build 500',
    );
    expect(walletHint, isNot(contains('Daily check-in')));
    expect(walletHint, contains('Grandeur'));

    final reviewTask = strings.t('Review a PGN with Stockfish or Grandeur.');
    expect(reviewTask, contains('PGN'));
    expect(reviewTask, contains('Stockfish'));
    expect(reviewTask, contains('Grandeur'));
  });

  test('dynamic visible strings keep user data while localizing labels', () {
    const zhHans = AppStrings(
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    );
    const japanese = AppStrings(Locale('ja'));
    const russian = AppStrings(Locale('ru'));

    final samples = <String>[
      'No openings match "Sicilian"',
      'Best move: Bc4',
      '7 / 12 positions',
      '7 / 12 PGN positions evaluated.',
      '65% complete',
      'Resume at 01:22',
      'Add more files (2/4)',
      '2 active',
      'This Lichess game has ended: mate.',
      'Channel 3',
      '5 detected',
      'Connect beep disabled by the buzzer master switch',
      '64 games are ready for personal engine training.',
      'Personal engine training started from 64 games.',
      'Add an engine name and at least 20 PGN games before starting training.',
    ];

    for (final source in samples) {
      final translated = zhHans.t(source);
      expect(translated, isNot(source), reason: source);
      expect(translated, isNot(contains('??')), reason: source);
    }

    expect(zhHans.t('No openings match "Sicilian"'), contains('Sicilian'));
    expect(zhHans.t('Best move: Bc4'), contains('Bc4'));
    expect(zhHans.t('7 / 12 PGN positions evaluated.'), contains('7 / 12'));
    expect(zhHans.t('Add more files (2/4)'), contains('2/4'));
    expect(zhHans.t('2 active'), contains('2'));
    expect(japanese.t('65% complete'), contains('65%'));
    expect(russian.t('Channel 3'), contains('3'));
    expect(
      zhHans.t('64 games are ready for personal engine training.'),
      contains('64'),
    );
    expect(
      zhHans.t('Personal engine training started from 64 games.'),
      contains('64'),
    );
    expect(
      zhHans.t(
        'Add an engine name and at least 20 PGN games before starting training.',
      ),
      contains('20'),
    );
  });

  test('Chinese Turnstile verification errors are readable', () {
    final sources = <String>[
      'Verification took too long. Check your connection and try again.',
      'Verification could not open. Check your connection and try again.',
      'Verification failed. Please try again.',
      'Verification was incomplete. Please try again.',
      'Verification was cancelled.',
      'Verification could not open in the app',
      'Verification could not open in the app. Continue to try another way.',
      'Verification could not open in the app. Try the browser verification.',
    ];

    const locales = <Locale>[
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ];

    for (final locale in locales) {
      final strings = AppStrings(locale);
      for (final source in sources) {
        final translated = strings.t(source);
        expect(translated, isNot(source));
        expect(translated, isNot(contains('????')));
        expect(translated, contains(locale.scriptCode == 'Hant' ? '驗證' : '验证'));
      }
    }
  });

  test('generated map does not reuse legacy or first-pass machine translations',
      () {
    final zhHans = generatedAppStringMaps['zh-Hans']!;
    final zhHant = generatedAppStringMaps['zh-Hant']!;
    final ja = generatedAppStringMaps['ja']!;
    final ko = generatedAppStringMaps['ko']!;
    final ru = generatedAppStringMaps['ru']!;

    expect(zhHans['Board settings'], '棋盘设置');
    expect(zhHans['Engine Lab'], '引擎实验室');
    expect(zhHans['Bot game'], '电脑对局');
    expect(zhHans['Game records'], '对局记录');
    expect(zhHans.values, isNot(contains(contains('董事会'))));
    expect(zhHans.values, isNot(contains(contains('发动机'))));
    expect(zhHans.values, isNot(contains(contains('机器人游戏'))));
    expect(zhHant.values, isNot(contains(contains('董事會'))));
    expect(ja['Engine Lab'], 'エンジンラボ');
    expect(ja['Bot game'], 'コンピューター対局');
    expect(ko['Engine Lab'], '엔진 연구실');
    expect(ko['Bot game'], '컴퓨터 대국');
    expect(ru['Engine Lab'], 'Лаборатория движков');
    expect(ru['Bot game'], 'Игра с компьютером');
  });

  test('generated map preserves protected product and protocol names', () {
    const protectedTerms = <String>{
      'Chessnut',
      'Lichess',
      'Chess.com',
      'Stockfish',
      'Maia',
      'LC0',
      'PGN',
      'FEN',
      'SAN',
      'UCI',
      'Elo',
      'OTB',
      'USB',
      'BLE',
      'LED',
      'RGB',
      'WebView',
      'Turnstile',
      'Grandeur',
      'MultiPV',
      'OAuth',
      'API',
      'Apple',
      'Google',
      'Meta',
      'EasyLinkSDK',
    };

    for (final entry in generatedAppStringMaps.entries) {
      for (final translation in entry.value.entries) {
        for (final term in protectedTerms) {
          if (translation.key.contains(term)) {
            expect(
              translation.value,
              contains(term),
              reason: '${entry.key} changed "$term" in "${translation.key}"',
            );
          }
        }
      }
    }
  });

  test('Japanese and Korean strings use generated visible UI translations', () {
    const japanese = AppStrings(Locale('ja'));
    const korean = AppStrings(Locale('ko'));

    expect(japanese.t('Engine Lab'), 'エンジンラボ');
    expect(japanese.t('Bot game'), 'コンピューター対局');
    expect(japanese.t('Show password'), 'パスワードを表示');
    expect(korean.t('Engine Lab'), '엔진 연구실');
    expect(korean.t('Bot game'), '컴퓨터 대국');
    expect(korean.t('Show password'), '비밀번호 표시');
  });

  test('dynamic visible strings localize numeric UI patterns', () {
    const zhHans = AppStrings(
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    );
    const japanese = AppStrings(Locale('ja'));

    expect(zhHans.t('Detected 42 games'), '识别到 42 盘对局');
    expect(zhHans.t('Found 21 games'), '找到 21 盘对局');
    expect(zhHans.t('17 moments'), '17 个关键时刻');
    expect(zhHans.t('64 lessons with board checkpoints'), '64 节含棋盘检查点的课程');
    expect(japanese.t('Detected 42 games'), '42 局を検出');
    expect(japanese.t('17 moments'), '17 件の重要局面');
  });

  test('custom FEN bot game copy is localized in Simplified Chinese', () {
    const zhHans = AppStrings(
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    );

    expect(zhHans.t('Connected'), '已连接');
    expect(zhHans.t('Disconnected'), '已断开');
    expect(zhHans.t('FEN position / White side'), 'FEN 局面 / 白方');
    expect(
      zhHans.t('Board editor / thinking 600ms'),
      '棋盘编辑器 / 思考时间 600ms',
    );
    expect(zhHans.t('Stockfish 600 / Unlimited'), 'Stockfish 600 / 无限');
  });

  test('AppStrings does not merge legacy ARB translations', () {
    const japanese = AppStrings(Locale('ja'));
    const korean = AppStrings(Locale('ko'));
    const russian = AppStrings(Locale('ru'));

    expect(japanese.t('Board Settings'), 'ボード設定');
    expect(korean.t('Board Settings'), '보드 설정');
    expect(russian.t('Board Settings'), 'Настройки доски');
  });
}

String? _readableTranslationIssue({
  required AppStrings strings,
  required String source,
  required String group,
}) {
  final translated = strings.t(source);
  return _readableValueIssue(
    localeKey: strings.localeKey,
    source: source,
    translated: translated,
    group: group,
  );
}

String? _readableValueIssue({
  required String localeKey,
  required String source,
  required String translated,
  required String group,
}) {
  if (translated == source) {
    return '$group: missing "$source"';
  }
  if (translated.contains('??') ||
      translated.contains('\uFFFD') ||
      _containsReplacementQuestionMark(translated)) {
    return '$group: "$source" -> "$translated"';
  }

  final expectedScript = switch (localeKey) {
    'zh-Hans' => RegExp(r'[\u4e00-\u9fff]'),
    'zh-Hant' => RegExp(r'[\u4e00-\u9fff]'),
    'ja' => RegExp(r'[\u3040-\u30ff\u4e00-\u9fff]'),
    'ko' => RegExp(r'[\uac00-\ud7af]'),
    'ru' => RegExp(r'[\u0400-\u04ff]'),
    _ => null,
  };
  if (expectedScript != null) {
    if (!expectedScript.hasMatch(translated)) {
      return '$group: "$source" -> "$translated" lacks expected script';
    }
  }
  return null;
}

bool _containsReplacementQuestionMark(String value) {
  return RegExp(r'[A-Za-zÀ-ž]\?[A-Za-zÀ-ž]').hasMatch(value);
}

bool _hasCompleteTranslation(Locale locale) => const {
      'en',
      'zh-Hans',
      'zh-Hant',
      'de',
      'es',
      'fr',
      'it',
      'ja',
      'ko',
      'nl',
      'ru',
    }.contains(AppStrings(locale).localeKey);

Widget _settingsHarness({
  required AppLanguagePreference preference,
  required Locale locale,
  required ValueChanged<AppLanguagePreference> onChanged,
  bool visionRecognitionOnly = false,
  ValueChanged<bool>? onVisionRecognitionOnlyChanged,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLanguagePreference.supportedLocales,
    localizationsDelegates: AppStrings.localizationsDelegates,
    theme: ChessnutTheme.light(),
    home: Scaffold(
      body: SettingsScreen(
        onNavigate: (_) {},
        themeMode: ThemeMode.system,
        onThemeModeChanged: (_) {},
        visualTheme: ChessnutVisualTheme.modern,
        onVisualThemeChanged: (_) {},
        pageAnimations: true,
        onPageAnimationsChanged: (_) {},
        boardCoordinatesEnabled: false,
        onBoardCoordinatesChanged: (_) {},
        keepBoardConnectedInBackground: false,
        onKeepBoardConnectedInBackgroundChanged: (_) {},
        soundEffectsEnabled: true,
        onSoundEffectsChanged: (_) {},
        moveAnnouncementEnabled: false,
        onMoveAnnouncementChanged: (_) {},
        visionRecognitionOnly: visionRecognitionOnly,
        onVisionRecognitionOnlyChanged: onVisionRecognitionOnlyChanged,
        languagePreference: preference,
        onLanguagePreferenceChanged: onChanged,
        apiClient: ChessnutApiClient(
          session: const ChessnutApiSession(
            userId: 1,
            token: '12345678901234567890123456789012',
          ),
        ),
        bugReportDiagnosticsBuilder: () => const BugReportDiagnostics(
          appVersion: '0.1.0',
          platform: 'android',
          locale: 'en-US',
          route: 'Settings',
          boardModel: 'Chessnut board',
          boardConnected: false,
          signedIn: true,
          log: '',
        ),
      ),
    ),
  );
}
