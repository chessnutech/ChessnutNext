import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredLoginCredentials {
  const StoredLoginCredentials({
    required this.account,
    required this.password,
  });

  final String account;
  final String password;

  bool get isValid => account.trim().isNotEmpty && password.isNotEmpty;
}

abstract class LoginCredentialStore {
  Future<StoredLoginCredentials?> read();

  Future<void> write(StoredLoginCredentials credentials);

  Future<void> clear();
}

class MemoryLoginCredentialStore implements LoginCredentialStore {
  MemoryLoginCredentialStore({this.stored});

  StoredLoginCredentials? stored;

  @override
  Future<StoredLoginCredentials?> read() async => stored;

  @override
  Future<void> write(StoredLoginCredentials credentials) async {
    stored = credentials;
  }

  @override
  Future<void> clear() async {
    stored = null;
  }
}

class SecureLoginCredentialStore implements LoginCredentialStore {
  const SecureLoginCredentialStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  static const _credentialsKey = 'chessnut_login_credentials';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredLoginCredentials?> read() async {
    try {
      final value = await _storage.read(key: _credentialsKey);
      if (value == null) return null;
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) return null;
      final credentials = StoredLoginCredentials(
        account: decoded['account']?.toString() ?? '',
        password: decoded['password']?.toString() ?? '',
      );
      return credentials.isValid ? credentials : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(StoredLoginCredentials credentials) async {
    if (!credentials.isValid) return;
    try {
      await _storage.write(
        key: _credentialsKey,
        value: jsonEncode({
          'account': credentials.account,
          'password': credentials.password,
        }),
      );
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _credentialsKey);
    } catch (_) {}
  }
}
