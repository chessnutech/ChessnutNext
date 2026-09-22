class ChessnutEndpointConfig {
  const ChessnutEndpointConfig._();

  static const defaultApiBaseUrl = 'https://api.chessnutech.com';
  static const defaultTurnstileChallengeUrl =
      'https://api.chessnutech.com/captcha/turnstile';
  static const defaultPuzzleBaseUrl = 'http://puzzle.chessnutech.com';
  static const defaultMoveUpdateUrl =
      'https://move.chessnutech.com/update.json';
  static const defaultSupportUrl =
      'https://www.chessnutech.com/pages/contact-form';
  static const defaultWatchBaseUrl = 'https://app.chessnutech.com';
  static const defaultAndroidPackageName = 'com.chessnut.newchessnut';

  static const _apiBaseUrl = String.fromEnvironment(
    'CHESSNUT_API_BASE_URL',
    defaultValue: defaultApiBaseUrl,
  );
  static const _puzzleBaseUrl = String.fromEnvironment(
    'CHESSNUT_PUZZLE_BASE_URL',
    defaultValue: defaultPuzzleBaseUrl,
  );
  static const _moveUpdateUrl = String.fromEnvironment(
    'CHESSNUT_MOVE_UPDATE_URL',
    defaultValue: defaultMoveUpdateUrl,
  );
  static const _supportUrl = String.fromEnvironment(
    'CHESSNUT_SUPPORT_URL',
    defaultValue: defaultSupportUrl,
  );
  static const _watchBaseUrl = String.fromEnvironment(
    'CHESSNUT_WATCH_BASE_URL',
    defaultValue: defaultWatchBaseUrl,
  );
  static const androidPackageName = String.fromEnvironment(
    'CHESSNUT_ANDROID_PACKAGE_NAME',
    defaultValue: defaultAndroidPackageName,
  );

  static Uri get apiBaseUri => _parseUri(_apiBaseUrl, defaultApiBaseUrl);

  static Uri get puzzleBaseUri =>
      _parseUri(_puzzleBaseUrl, defaultPuzzleBaseUrl);

  static Uri get moveUpdateUri =>
      _parseUri(_moveUpdateUrl, defaultMoveUpdateUrl);

  static Uri get supportUri => _parseUri(_supportUrl, defaultSupportUrl);

  static Uri get watchBaseUri => _parseUri(_watchBaseUrl, defaultWatchBaseUrl);

  static Uri watchUri(String roomId) {
    final normalizedRoomId =
        roomId.startsWith('/') ? roomId.substring(1) : roomId;
    return watchBaseUri.replace(
        path: _joinPath(watchBaseUri.path, normalizedRoomId));
  }

  static Uri _parseUri(String value, String fallback) {
    final trimmed = value.trim();
    final parsed = Uri.tryParse(trimmed.isEmpty ? fallback : trimmed);
    if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
      return parsed;
    }
    return Uri.parse(fallback);
  }

  static String _joinPath(String basePath, String suffix) {
    final normalizedBase = basePath.endsWith('/')
        ? basePath.substring(0, basePath.length - 1)
        : basePath;
    final normalizedSuffix =
        suffix.startsWith('/') ? suffix.substring(1) : suffix;
    if (normalizedBase.isEmpty) {
      return normalizedSuffix;
    }
    if (normalizedSuffix.isEmpty) {
      return normalizedBase;
    }
    return '$normalizedBase/$normalizedSuffix';
  }
}
