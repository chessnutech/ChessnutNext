import 'dart:convert';
import 'dart:io';

import 'package:chessnut_flutter_export/services/app_update_service.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('compareVersions detects semantic and build updates', () {
    expect(AppUpdateService.compareVersions('0.1.5', '0.1.4'), greaterThan(0));
    expect(
        AppUpdateService.compareVersions('0.1.4+7', '0.1.4+6'), greaterThan(0));
    expect(AppUpdateService.compareVersions('0.1.4', '0.1.4+6'), equals(0));
    expect(AppUpdateService.compareVersions('0.1.3', '0.1.4'), lessThan(0));
  });

  test('resolveUpdateDecision falls back to local comparison', () {
    const info = AppVersionInfo(
      changeLog: 'Bug fixes',
      downloadUrl: 'https://download.chessnut.com/windows',
      platform: 1,
      version: '0.1.5',
    );

    final decision = AppUpdateService.resolveUpdateDecision(
      info,
      currentVersion: '0.1.4',
    );

    expect(decision.hasUpdate, isTrue);
    expect(decision.forceUpdate, isFalse);
    expect(decision.latestVersion, '0.1.5');
    expect(decision.releaseNotes, 'Bug fixes');
  });

  test('checkForUpdate detects newer build with the same semantic version',
      () async {
    late http.Request captured;
    final client = ChessnutApiClient(
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': {
              'version': '0.1.4+7',
              'platform': 12,
              'download_url': 'https://play.google.com/store/apps/details',
              'change_log': '',
              'update_available': false,
              'force_update': false,
              'update_method': 'store',
            },
          }),
          200,
        );
      }),
    );
    final service = AppUpdateService(
      apiClient: client,
      platformProvider: () => 'android',
      versionProvider: () async => const AppInstalledVersion(
        version: '0.1.4',
        buildNumber: '6',
      ),
    );

    final decision = await service.checkForUpdate();

    expect(captured.bodyFields['current_version'], '0.1.4');
    expect(captured.bodyFields['build_number'], '6');
    expect(decision?.hasUpdate, isTrue);
    expect(decision?.currentVersion, '0.1.4+6');
  });

  test('iOS update check uses iTunes lookup instead of backend version',
      () async {
    late http.Request captured;
    var backendVersionChecks = 0;
    final client = ChessnutApiClient(
      httpClient: MockClient((request) async {
        captured = request;
        if (request.url.path == '/api/version') {
          backendVersionChecks++;
        }
        return http.Response(
          jsonEncode({
            'resultCount': 1,
            'results': [
              {
                'bundleId': 'com.chessnut.chessnutnext',
                'kind': 'software',
                'version': '1.2.0',
                'trackViewUrl':
                    'https://apps.apple.com/us/app/chessnut/id123456789',
                'releaseNotes': 'App Store fixes',
              },
            ],
          }),
          200,
        );
      }),
    );
    final service = AppUpdateService(
      apiClient: client,
      platformProvider: () => 'ios',
      versionProvider: () async => const AppInstalledVersion(
        version: '1.1.0',
        buildNumber: '10',
      ),
    );

    final decision = await service.checkForUpdate();

    expect(captured.method, 'GET');
    expect(captured.url.host, 'itunes.apple.com');
    expect(captured.url.path, '/lookup');
    expect(
        captured.url.queryParameters['bundleId'], 'com.chessnut.chessnutnext');
    expect(captured.url.queryParameters['country'], 'us');
    expect(captured.url.queryParameters['media'], 'software');
    expect(captured.url.queryParameters['entity'], 'software');
    expect(backendVersionChecks, 0);
    expect(decision?.hasUpdate, isTrue);
    expect(decision?.latestVersion, '1.2.0');
    expect(decision?.releaseNotes, 'App Store fixes');
    expect(decision?.downloadUrl,
        'https://apps.apple.com/us/app/chessnut/id123456789');
    expect(decision?.updateMethod, 'app_store');
  });

  test('macOS update check reports unavailable if App Store listing is missing',
      () async {
    late http.Request captured;
    var backendVersionChecks = 0;
    final client = ChessnutApiClient(
      httpClient: MockClient((request) async {
        captured = request;
        if (request.url.path == '/api/version') {
          backendVersionChecks++;
        }
        return http.Response(
          jsonEncode({
            'resultCount': 0,
            'results': [],
          }),
          200,
        );
      }),
    );
    final service = AppUpdateService(
      apiClient: client,
      platformProvider: () => 'macos',
      versionProvider: () async => const AppInstalledVersion(
        version: '1.1.0',
        buildNumber: '10',
      ),
    );

    await expectLater(
      service.checkForUpdate(),
      throwsA(isA<AppUpdateCheckUnavailableException>()),
    );

    expect(captured.method, 'GET');
    expect(captured.url.host, 'itunes.apple.com');
    expect(captured.url.path, '/lookup');
    expect(
        captured.url.queryParameters['bundleId'], 'com.chessnut.chessnutnext');
    expect(captured.url.queryParameters['country'], 'us');
    expect(captured.url.queryParameters['media'], 'software');
    expect(captured.url.queryParameters['entity'], 'macSoftware');
    expect(backendVersionChecks, 0);
  });

  test('iTunes lookup URI keeps custom base query parameters', () {
    final uri = AppUpdateService.itunesLookupUri(
      platformName: 'ios',
      bundleId: ' com.chessnut.chessnutnext ',
      country: 'CN',
      baseUri: Uri.parse('https://itunes.apple.com/lookup?lang=zh_cn'),
    );

    expect(uri.toString(), contains('/lookup'));
    expect(uri.queryParameters['lang'], 'zh_cn');
    expect(uri.queryParameters['bundleId'], 'com.chessnut.chessnutnext');
    expect(uri.queryParameters['country'], 'cn');
    expect(uri.queryParameters['media'], 'software');
    expect(uri.queryParameters['entity'], 'software');
    expect(uri.queryParameters['limit'], '10');
  });

  test('direct Android download policy keeps backend APK URL', () {
    const info = AppVersionInfo(
      changeLog: 'Bug fixes',
      downloadUrl: 'https://download.chessnutech.com/chessnut-next.apk',
      platform: 12,
      version: '0.1.5',
      updateAvailable: true,
      updateMethod: 'download',
    );

    final decision = AppUpdateService.resolveUpdateDecision(
      info,
      currentVersion: '0.1.4',
      platformName: 'android',
      distributionChannel: 'direct',
    );

    expect(decision.updateMethod, 'download');
    expect(
      decision.downloadUrl,
      'https://download.chessnutech.com/chessnut-next.apk',
    );
  });

  test('Google Play channel prefers Play in-app update flow on Android', () {
    const info = AppVersionInfo(
      changeLog: 'Bug fixes',
      downloadUrl: 'https://download.chessnutech.com/chessnut-next.apk',
      platform: 12,
      version: '0.1.5',
      updateAvailable: true,
      updateMethod: 'download',
    );

    final decision = AppUpdateService.resolveUpdateDecision(
      info,
      currentVersion: '0.1.4',
      platformName: 'android',
      distributionChannel: 'google_play',
      packageName: 'com.chessnut.newchessnut',
    );

    expect(decision.updateMethod, 'play_in_app');
    expect(
      decision.downloadUrl,
      'https://play.google.com/store/apps/details?id=com.chessnut.newchessnut',
    );
  });

  test('platformCode maps supported app platforms to legacy backend codes', () {
    expect(AppUpdateService.platformCodeFor(Platform.operatingSystem),
        isNonNegative);
    expect(AppUpdateService.platformCodeFor('android'), 12);
    expect(AppUpdateService.platformCodeFor('ios'), 13);
    expect(AppUpdateService.platformCodeFor('windows'), 1);
    expect(AppUpdateService.platformCodeFor('macos'), 2);
  });
}
