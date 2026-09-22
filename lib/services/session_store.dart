import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class StoredChessnutSession {
  const StoredChessnutSession({
    required this.userId,
    required this.refreshToken,
  });

  final int userId;
  final String refreshToken;

  bool get canRefresh => userId > 0 && refreshToken.trim().isNotEmpty;
}

abstract class ChessnutSessionStore {
  Future<StoredChessnutSession?> read();

  Future<void> write(StoredChessnutSession session);

  Future<void> clear();
}

class MemoryChessnutSessionStore implements ChessnutSessionStore {
  MemoryChessnutSessionStore({this.stored});

  StoredChessnutSession? stored;

  @override
  Future<StoredChessnutSession?> read() async => stored;

  @override
  Future<void> write(StoredChessnutSession session) async {
    stored = session;
  }

  @override
  Future<void> clear() async {
    stored = null;
  }
}

class NoopChessnutSessionStore implements ChessnutSessionStore {
  const NoopChessnutSessionStore();

  @override
  Future<StoredChessnutSession?> read() async => null;

  @override
  Future<void> write(StoredChessnutSession session) async {}

  @override
  Future<void> clear() async {}
}

typedef LegacySessionFileProvider = Future<File> Function();

class SecureChessnutSessionStore implements ChessnutSessionStore {
  const SecureChessnutSessionStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    LegacySessionFileProvider? legacySessionFileProvider,
  })  : _storage = storage,
        _legacySessionFileProvider = legacySessionFileProvider;

  static const _sessionKey = 'chessnut_session';
  static const _legacyFileName = 'chessnut_session.json';

  final FlutterSecureStorage _storage;
  final LegacySessionFileProvider? _legacySessionFileProvider;

  @override
  Future<StoredChessnutSession?> read() async {
    try {
      final stored = _decodeSession(await _storage.read(key: _sessionKey));
      if (stored != null) {
        await _deleteLegacySessionFile();
        return stored;
      }
    } catch (_) {
      // Fall through to the one-time plaintext session migration.
    }

    final legacy = await _readLegacySession();
    if (legacy == null) return null;
    if (await _writeSecureSession(legacy)) {
      await _deleteLegacySessionFile();
    }
    return legacy;
  }

  @override
  Future<void> write(StoredChessnutSession session) async {
    if (!session.canRefresh) return;
    if (await _writeSecureSession(session)) {
      await _deleteLegacySessionFile();
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _sessionKey);
    } catch (_) {}
    await _deleteLegacySessionFile();
  }

  Future<bool> _writeSecureSession(StoredChessnutSession session) async {
    try {
      await _storage.write(
        key: _sessionKey,
        value: jsonEncode({
          'user_id': session.userId,
          'refresh_token': session.refreshToken,
        }),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<StoredChessnutSession?> _readLegacySession() async {
    try {
      final file = await _legacySessionFile();
      if (!await file.exists()) return null;
      return _decodeSession(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteLegacySessionFile() async {
    try {
      final file = await _legacySessionFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<File> _legacySessionFile() async {
    final provider = _legacySessionFileProvider;
    if (provider != null) return provider();
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_legacyFileName');
  }
}

StoredChessnutSession? _decodeSession(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) return null;
    final session = StoredChessnutSession(
      userId: _int(decoded['user_id']),
      refreshToken: decoded['refresh_token']?.toString() ?? '',
    );
    return session.canRefresh ? session : null;
  } catch (_) {
    return null;
  }
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
