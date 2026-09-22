import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'chessnut_api_client.dart';

const savedAccountValidity = Duration(days: 7);

bool supportsAccountSwitcherPlatform(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.windows ||
    TargetPlatform.macOS =>
      true,
    TargetPlatform.linux || TargetPlatform.fuchsia => false,
  };
}

/// A locally remembered account that can be restored without re-entering a
/// password. Only the refresh token is stored; the access token is refreshed
/// when the account is selected.
class SavedChessnutAccount {
  const SavedChessnutAccount({
    required this.userId,
    required this.refreshToken,
    required this.displayName,
    this.avatarUrl = '',
    this.email = '',
    this.authenticatedAt,
  });

  factory SavedChessnutAccount.fromSession(ChessnutLoginSession session) {
    return SavedChessnutAccount(
      userId: session.userId,
      refreshToken: session.refreshToken?.trim() ?? '',
      displayName: _displayName(session),
      avatarUrl: session.avatarUrl,
      email: session.email,
      authenticatedAt: DateTime.now().toUtc(),
    );
  }

  factory SavedChessnutAccount.fromJson(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    return SavedChessnutAccount(
      userId: _int(json['user_id']),
      refreshToken: json['refresh_token']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      authenticatedAt: _dateTime(json['authenticated_at']),
    );
  }

  final int userId;
  final String refreshToken;
  final String displayName;
  final String avatarUrl;
  final String email;
  final DateTime? authenticatedAt;

  bool get isValid => userId > 0 && refreshToken.isNotEmpty;

  bool isExpired(DateTime now) {
    final authenticatedAt = this.authenticatedAt;
    return authenticatedAt != null &&
        !now.toUtc().isBefore(authenticatedAt.add(savedAccountValidity));
  }

  SavedChessnutAccount copyWith({DateTime? authenticatedAt}) {
    return SavedChessnutAccount(
      userId: userId,
      refreshToken: refreshToken,
      displayName: displayName,
      avatarUrl: avatarUrl,
      email: email,
      authenticatedAt: authenticatedAt ?? this.authenticatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'user_id': userId,
        'refresh_token': refreshToken,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'email': email,
        'authenticated_at': authenticatedAt?.toUtc().toIso8601String(),
      };
}

abstract class AccountSwitcherStore {
  Future<List<SavedChessnutAccount>> read();

  Future<void> upsert(
    SavedChessnutAccount account, {
    bool renewValidity = false,
  });

  Future<void> remove(int userId);
}

class MemoryAccountSwitcherStore implements AccountSwitcherStore {
  MemoryAccountSwitcherStore({List<SavedChessnutAccount>? accounts})
      : accounts = List<SavedChessnutAccount>.from(accounts ?? const []);

  List<SavedChessnutAccount> accounts;

  @override
  Future<List<SavedChessnutAccount>> read() async =>
      List<SavedChessnutAccount>.unmodifiable(accounts);

  @override
  Future<void> upsert(
    SavedChessnutAccount account, {
    bool renewValidity = false,
  }) async {
    final existing =
        accounts.where((item) => item.userId == account.userId).firstOrNull;
    final authenticatedAt = renewValidity
        ? DateTime.now().toUtc()
        : existing?.authenticatedAt ??
            account.authenticatedAt ??
            DateTime.now().toUtc();
    accounts.removeWhere((item) => item.userId == account.userId);
    accounts.insert(0, account.copyWith(authenticatedAt: authenticatedAt));
  }

  @override
  Future<void> remove(int userId) async {
    accounts.removeWhere((item) => item.userId == userId);
  }
}

class SecureAccountSwitcherStore implements AccountSwitcherStore {
  const SecureAccountSwitcherStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  static const _accountsKey = 'chessnut_saved_accounts';
  final FlutterSecureStorage _storage;

  @override
  Future<List<SavedChessnutAccount>> read() async {
    try {
      final raw = await _storage.read(key: _accountsKey);
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      var migrated = false;
      final now = DateTime.now().toUtc();
      final accounts = decoded
          .map(SavedChessnutAccount.fromJson)
          .where((account) => account.isValid)
          .map((account) {
            if (account.authenticatedAt != null) return account;
            migrated = true;
            return account.copyWith(authenticatedAt: now);
          })
          .take(8)
          .toList(growable: false);
      if (migrated) await _write(accounts);
      return accounts;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> upsert(
    SavedChessnutAccount account, {
    bool renewValidity = false,
  }) async {
    if (!account.isValid) return;
    final accounts = (await read()).toList();
    final existing =
        accounts.where((item) => item.userId == account.userId).firstOrNull;
    final authenticatedAt = renewValidity
        ? DateTime.now().toUtc()
        : existing?.authenticatedAt ??
            account.authenticatedAt ??
            DateTime.now().toUtc();
    accounts
      ..removeWhere((item) => item.userId == account.userId)
      ..insert(0, account.copyWith(authenticatedAt: authenticatedAt));
    await _write(accounts.take(8).toList(growable: false));
  }

  @override
  Future<void> remove(int userId) async {
    final accounts = (await read()).where((item) => item.userId != userId);
    await _write(accounts.toList(growable: false));
  }

  Future<void> _write(List<SavedChessnutAccount> accounts) async {
    try {
      await _storage.write(
        key: _accountsKey,
        value: jsonEncode(accounts.map((account) => account.toJson()).toList()),
      );
    } catch (_) {}
  }
}

String _displayName(ChessnutLoginSession session) {
  for (final value in [session.username, session.email, session.phone]) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return 'Chessnut account';
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _dateTime(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed?.toUtc();
}
