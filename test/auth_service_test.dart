import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/services/auth_service.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/services/session_store.dart';

void main() {
  test('Apple web configuration accepts explicit project settings', () {
    const config = AuthRuntimeConfig(
      appleServiceId: 'com.example.app.signin',
      appleRedirectUri: 'https://example.com/apple/callback',
    );

    expect(config.appleServiceId, 'com.example.app.signin');
    expect(
      config.resolvedAppleRedirectUri,
      'https://example.com/apple/callback',
    );
    expect(
      config.appleWebAuthenticationOptions().redirectUri.path,
      '/apple/callback',
    );
  });

  test('social login is unconfigured when no OAuth settings are supplied', () {
    const config = AuthRuntimeConfig();

    expect(config.hasGoogleServerClientId, isFalse);
    expect(config.hasAppleWebConfig, isFalse);
  });

  test('exchanges Google identity with Chessnut backend', () async {
    final backend = RecordingAuthBackend(
      session: _session(
        token: 'access',
        refreshToken: 'refresh',
        userId: 1,
        email: 'player@example.com',
        username: 'Chessnut Player',
      ),
    );
    final broker = FakeSocialAuthBroker(
      googleCredential: const ExternalAuthCredential(
        provider: SocialAuthProvider.google,
        providerUserId: 'google-sub',
        identityToken: 'google-id-token',
        authorizationCode: 'google-auth-code',
        email: 'player@example.com',
        displayName: 'Chessnut Player',
      ),
    );

    final result = await AuthService(
      broker: broker,
      backend: backend,
    ).signInWith(SocialAuthProvider.google);

    expect(result.isSuccess, isTrue);
    expect(result.session?.token, 'access');
    expect(backend.lastCredential?.provider, SocialAuthProvider.google);
    expect(backend.lastCredential?.identityToken, 'google-id-token');
    expect(backend.lastCredential?.authorizationCode, 'google-auth-code');
  });

  test('exchanges Apple authorization code with Chessnut backend', () async {
    final backend = RecordingAuthBackend(
      session: _session(
        token: 'apple-access',
        refreshToken: 'apple-refresh',
        userId: 2,
      ),
    );
    final broker = FakeSocialAuthBroker(
      appleCredential: const ExternalAuthCredential(
        provider: SocialAuthProvider.apple,
        providerUserId: 'apple-user',
        identityToken: 'apple-id-token',
        authorizationCode: 'apple-auth-code',
        email: 'private-relay@example.com',
        displayName: 'Apple Player',
      ),
    );

    final result = await AuthService(
      broker: broker,
      backend: backend,
    ).signInWith(SocialAuthProvider.apple);

    expect(result.isSuccess, isTrue);
    expect(result.session?.userId, 2);
    expect(backend.lastCredential?.provider, SocialAuthProvider.apple);
    expect(backend.lastCredential?.providerUserId, 'apple-user');
    expect(backend.lastCredential?.authorizationCode, 'apple-auth-code');
  });

  test('reports missing backend configuration before opening provider flow',
      () async {
    final broker = FakeSocialAuthBroker(
      googleCredential: const ExternalAuthCredential(
        provider: SocialAuthProvider.google,
        providerUserId: 'google-sub',
        identityToken: 'google-id-token',
      ),
    );

    final result = await AuthService(
      broker: broker,
      backend: const MissingAuthBackend(),
    ).signInWith(SocialAuthProvider.google);

    expect(result.isSuccess, isFalse);
    expect(result.error?.reason, AuthFailureReason.needsConfiguration);
    expect(broker.googleCalls, 0);
  });

  test('keeps user on auth screen when provider flow is cancelled', () async {
    final result = await AuthService(
      broker: FakeSocialAuthBroker(cancelGoogle: true),
      backend: RecordingAuthBackend(
        session: _session(token: 'access'),
      ),
    ).signInWith(SocialAuthProvider.google);

    expect(result.isSuccess, isFalse);
    expect(result.error?.reason, AuthFailureReason.cancelled);
  });

  test('memory session store saves and clears refresh token', () async {
    final store = MemoryChessnutSessionStore();

    await store.write(
      const StoredChessnutSession(
        userId: 7,
        refreshToken: 'refresh-token',
      ),
    );

    expect((await store.read())?.userId, 7);
    expect((await store.read())?.refreshToken, 'refresh-token');

    await store.clear();

    expect(await store.read(), isNull);
  });
}

class FakeSocialAuthBroker implements SocialAuthBroker {
  FakeSocialAuthBroker({
    this.googleCredential,
    this.appleCredential,
    this.cancelGoogle = false,
  });

  final ExternalAuthCredential? googleCredential;
  final ExternalAuthCredential? appleCredential;
  final bool cancelGoogle;

  int googleCalls = 0;

  @override
  Future<ExternalAuthCredential> signInWithApple(
      AuthRuntimeConfig config) async {
    final credential = appleCredential;
    if (credential == null) throw const AuthException.cancelled();
    return credential;
  }

  @override
  Future<ExternalAuthCredential> signInWithGoogle(
      AuthRuntimeConfig config) async {
    googleCalls++;
    if (cancelGoogle) throw const AuthException.cancelled();
    final credential = googleCredential;
    if (credential == null) throw const AuthException.cancelled();
    return credential;
  }
}

class RecordingAuthBackend implements ChessnutAuthBackend {
  RecordingAuthBackend({required this.session});

  final ChessnutLoginSession session;
  ExternalAuthCredential? lastCredential;

  @override
  bool get isConfigured => true;

  @override
  Future<ChessnutLoginSession> exchangeExternalCredential(
    ExternalAuthCredential credential,
  ) async {
    lastCredential = credential;
    return session;
  }
}

ChessnutLoginSession _session({
  required String token,
  String? refreshToken,
  int userId = 1,
  String email = '',
  String username = 'Chessnut Player',
}) {
  return ChessnutLoginSession(
    avatarUrl: '',
    bindApple: false,
    bindChess: false,
    bindGoogle: false,
    bindLichess: false,
    chessName: '',
    email: email,
    lichessName: '',
    noPassword: true,
    phone: '',
    region: '',
    token: token,
    refreshToken: refreshToken,
    userId: userId,
    username: username,
  );
}
