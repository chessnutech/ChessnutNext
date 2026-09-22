import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'chessnut_api_client.dart';

class AppUpdateDecision {
  const AppUpdateDecision({
    required this.hasUpdate,
    required this.forceUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.updateMethod,
    required this.platformName,
    this.preferImmediatePlayUpdate = false,
  });

  final bool hasUpdate;
  final bool forceUpdate;
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final String updateMethod;
  final String platformName;
  final bool preferImmediatePlayUpdate;
}

class AppUpdateCheckUnavailableException implements Exception {
  const AppUpdateCheckUnavailableException([
    this.message = 'App update check is unavailable.',
  ]);

  final String message;

  @override
  String toString() => 'AppUpdateCheckUnavailableException: $message';
}

class AppUpdateService {
  const AppUpdateService({
    required this.apiClient,
    this.versionProvider,
    this.platformProvider,
    this.distributionChannelProvider,
    this.packageNameProvider,
    this.appleBundleIdProvider,
    this.appStoreCountryProvider,
    this.itunesLookupBaseUri,
  });

  static const defaultGooglePlayPackageName = 'com.chessnut.newchessnut';
  static const defaultAppleBundleId = 'com.chessnut.chessnutnext';
  static const defaultAppStoreCountry = String.fromEnvironment(
    'CHESSNUT_APP_STORE_COUNTRY',
    defaultValue: 'us',
  );
  static const distributionChannel = String.fromEnvironment(
    'CHESSNUT_DISTRIBUTION_CHANNEL',
    defaultValue: 'direct',
  );
  static final defaultItunesLookupBaseUri =
      Uri.parse('https://itunes.apple.com/lookup');

  final ChessnutApiClient apiClient;
  final Future<AppInstalledVersion> Function()? versionProvider;
  final String Function()? platformProvider;
  final String Function()? distributionChannelProvider;
  final String Function()? packageNameProvider;
  final String Function()? appleBundleIdProvider;
  final String Function()? appStoreCountryProvider;
  final Uri? itunesLookupBaseUri;

  Future<AppUpdateDecision?> checkForUpdate() async {
    final installed = await (versionProvider?.call() ?? readInstalledVersion());
    final platformName = platformProvider?.call() ?? currentPlatformName();
    final channel = distributionChannelProvider?.call() ?? distributionChannel;
    final packageName =
        packageNameProvider?.call() ?? defaultGooglePlayPackageName;
    final platform = platformCodeFor(platformName);
    if (platform <= 0) return null;

    if (isAppleStorePlatform(platformName)) {
      final info = await _lookupAppleStoreVersion(
        platformName: platformName,
        bundleId: appleBundleIdProvider?.call() ?? defaultAppleBundleId,
        country: appStoreCountryProvider?.call() ?? defaultAppStoreCountry,
      );
      return resolveUpdateDecision(
        info,
        currentVersion: installed.fullVersion,
        platformName: platformName,
      );
    }

    final result = await apiClient.version(
      platform,
      currentVersion: installed.version,
      buildNumber: installed.buildNumber,
      platformName: platformName,
    );
    if (!result.isSuccess || result.data == null) return null;
    final installedVersion = installed.fullVersion;
    return resolveUpdateDecision(
      result.data!,
      currentVersion: installedVersion,
      platformName: platformName,
      distributionChannel: channel,
      packageName: packageName,
    );
  }

  Future<AppVersionInfo> _lookupAppleStoreVersion({
    required String platformName,
    required String bundleId,
    required String country,
  }) async {
    final cleanBundleId = bundleId.trim();
    if (cleanBundleId.isEmpty) {
      throw const AppUpdateCheckUnavailableException('Missing bundle id.');
    }
    final uri = itunesLookupUri(
      platformName: platformName,
      bundleId: cleanBundleId,
      country: country,
      baseUri: itunesLookupBaseUri,
    );
    try {
      final response = await apiClient.httpClient.get(uri);
      if (response.statusCode != 200) {
        throw AppUpdateCheckUnavailableException(
          'iTunes lookup returned HTTP ${response.statusCode}.',
        );
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const AppUpdateCheckUnavailableException(
          'iTunes lookup response was not a JSON object.',
        );
      }
      final rawResults = decoded['results'];
      if (rawResults is! List || rawResults.isEmpty) {
        throw const AppUpdateCheckUnavailableException(
          'iTunes lookup did not return an app listing.',
        );
      }
      final selected = _selectAppleLookupResult(
        rawResults,
        platformName: platformName,
        bundleId: cleanBundleId,
      );
      if (selected == null) {
        throw const AppUpdateCheckUnavailableException(
          'iTunes lookup did not include the requested bundle id.',
        );
      }
      final version = _stringValue(selected['version']);
      final url = _stringValue(selected['trackViewUrl']);
      if (version.isEmpty || url.isEmpty) {
        throw const AppUpdateCheckUnavailableException(
          'iTunes lookup listing did not include a version or store URL.',
        );
      }
      return AppVersionInfo(
        changeLog: _stringValue(selected['releaseNotes']),
        downloadUrl: url,
        platform: platformCodeFor(platformName),
        version: version,
        updateMethod: 'app_store',
      );
    } on AppUpdateCheckUnavailableException {
      rethrow;
    } catch (_) {
      throw const AppUpdateCheckUnavailableException();
    }
  }

  static AppUpdateDecision resolveUpdateDecision(
    AppVersionInfo info, {
    required String currentVersion,
    String platformName = '',
    String distributionChannel = AppUpdateService.distributionChannel,
    String packageName = defaultGooglePlayPackageName,
  }) {
    final hasUpdate = info.updateAvailable ||
        compareVersions(info.version, currentVersion) > 0;
    final updateMethod = normalizeUpdateMethod(
      info.updateMethod,
      platformName,
      distributionChannel: distributionChannel,
    );
    return AppUpdateDecision(
      hasUpdate: hasUpdate,
      forceUpdate: info.forceUpdate,
      currentVersion:
          info.currentVersion.isNotEmpty ? info.currentVersion : currentVersion,
      latestVersion: info.version,
      downloadUrl: resolveUpdateUrl(
        info.downloadUrl,
        updateMethod,
        packageName: packageName,
      ),
      releaseNotes: info.changeLog,
      updateMethod: updateMethod,
      platformName: platformName,
    );
  }

  static Future<AppInstalledVersion> readInstalledVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return AppInstalledVersion(
        version: info.version,
        buildNumber: info.buildNumber,
      );
    } catch (_) {
      return const AppInstalledVersion(
        version: String.fromEnvironment(
          'CHESSNUT_APP_VERSION',
          defaultValue: '0.1.4',
        ),
        buildNumber: String.fromEnvironment(
          'CHESSNUT_APP_BUILD_NUMBER',
          defaultValue: '0',
        ),
      );
    }
  }

  static String currentPlatformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  static int platformCodeFor(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return 1;
      case 'macos':
        return 2;
      case 'android':
        return 12;
      case 'ios':
        return 13;
      default:
        return 0;
    }
  }

  static String defaultUpdateMethodFor(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return isGooglePlayDistribution(distributionChannel)
            ? 'play_in_app'
            : 'download';
      case 'ios':
      case 'macos':
        return 'app_store';
      case 'windows':
        return 'download';
      default:
        return 'external';
    }
  }

  static String normalizeUpdateMethod(
    String method,
    String platform, {
    String distributionChannel = AppUpdateService.distributionChannel,
  }) {
    final normalized = method.trim().toLowerCase();
    if (isAppleStorePlatform(platform)) {
      if (normalized.isEmpty ||
          normalized == 'store' ||
          normalized == 'app_store' ||
          normalized == 'mac_app_store') {
        return 'app_store';
      }
      return normalized;
    }
    if (platform.toLowerCase() == 'android') {
      if (isGooglePlayDistribution(distributionChannel)) return 'play_in_app';
      if (normalized == 'store' || normalized == 'play_in_app') {
        return 'download';
      }
      if (normalized.isNotEmpty) return normalized;
      return 'download';
    }
    if (normalized.isNotEmpty) return normalized;
    return defaultUpdateMethodFor(platform);
  }

  static String resolveUpdateUrl(
    String url,
    String updateMethod, {
    String packageName = defaultGooglePlayPackageName,
  }) {
    if (updateMethod == 'play_in_app' || updateMethod == 'store') {
      return googlePlayUrlForPackage(packageName);
    }
    return url.trim();
  }

  static bool isAppleStorePlatform(String platform) {
    final normalized = platform.trim().toLowerCase();
    return normalized == 'ios' || normalized == 'macos';
  }

  static bool isGooglePlayDistribution(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('-', '_');
    return normalized == 'google_play' || normalized == 'play';
  }

  static String googlePlayUrlForPackage(String packageName) {
    final clean = packageName.trim().isEmpty
        ? defaultGooglePlayPackageName
        : packageName.trim();
    return 'https://play.google.com/store/apps/details?id=$clean';
  }

  static Uri itunesLookupUri({
    required String platformName,
    required String bundleId,
    required String country,
    Uri? baseUri,
  }) {
    final base = baseUri ?? defaultItunesLookupBaseUri;
    final query = Map<String, String>.from(base.queryParameters);
    query.addAll({
      'bundleId': bundleId.trim(),
      'country': _normalizeAppStoreCountry(country),
      'media': 'software',
      'entity': platformName.trim().toLowerCase() == 'macos'
          ? 'macSoftware'
          : 'software',
      'limit': '10',
    });
    return base.replace(queryParameters: query);
  }

  static int compareVersions(String latest, String current) {
    final latestParts = _versionParts(latest.split('+').first);
    final currentParts = _versionParts(current.split('+').first);
    final maxLength = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;
    for (var i = 0; i < maxLength; i++) {
      final a = i < latestParts.length ? latestParts[i] : 0;
      final b = i < currentParts.length ? currentParts[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    final latestBuild = _buildNumber(latest);
    final currentBuild = _buildNumber(current);
    if (latestBuild != null && currentBuild != null) {
      return latestBuild.compareTo(currentBuild);
    }
    return 0;
  }

  static List<int> _versionParts(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return const [0];
    return normalized
        .split(RegExp(r'[^0-9]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => int.tryParse(part) ?? 0)
        .toList(growable: false);
  }

  static int? _buildNumber(String value) {
    final pieces = value.split('+');
    if (pieces.length < 2) return null;
    return int.tryParse(pieces.last.trim());
  }

  static Map<String, dynamic>? _selectAppleLookupResult(
    List<dynamic> rawResults, {
    required String platformName,
    required String bundleId,
  }) {
    final maps = rawResults.whereType<Map<String, dynamic>>();
    final bundleMatches = maps.where((result) {
      final resultBundleId = _stringValue(result['bundleId']);
      return resultBundleId.isEmpty || resultBundleId == bundleId;
    }).toList(growable: false);
    if (bundleMatches.isEmpty) return null;
    for (final result in bundleMatches) {
      if (_appleLookupKindMatchesPlatform(result, platformName)) {
        return result;
      }
    }
    return bundleMatches.first;
  }

  static bool _appleLookupKindMatchesPlatform(
    Map<String, dynamic> result,
    String platformName,
  ) {
    final platform = platformName.trim().toLowerCase();
    final kind = _stringValue(result['kind']).toLowerCase();
    if (platform == 'macos') {
      return kind.contains('mac');
    }
    if (platform == 'ios') {
      return kind.isEmpty || kind == 'software';
    }
    return false;
  }

  static String _normalizeAppStoreCountry(String value) {
    final normalized = value.trim().toLowerCase();
    if (RegExp(r'^[a-z]{2}$').hasMatch(normalized)) return normalized;
    return 'us';
  }

  static String _stringValue(Object? value) => value?.toString().trim() ?? '';
}

class AppInstalledVersion {
  const AppInstalledVersion({
    required this.version,
    required this.buildNumber,
  });

  final String version;
  final String buildNumber;

  String get fullVersion {
    final cleanVersion = version.trim();
    final cleanBuild = buildNumber.trim();
    if (cleanBuild.isEmpty || cleanBuild == '0' || cleanVersion.contains('+')) {
      return cleanVersion;
    }
    return '$cleanVersion+$cleanBuild';
  }
}
