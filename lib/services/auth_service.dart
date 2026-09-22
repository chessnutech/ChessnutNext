import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'chessnut_endpoint_config.dart';
import 'chessnut_api_client.dart';

// Project-specific OAuth values must be supplied with --dart-define or
// --dart-define-from-file. Keep the checked-in defaults empty.
const chessnutGoogleServerClientId = '';
const chessnutAppleServiceId = '';
const chessnutAppleRedirectUri = '';
const _googleSignInTimeout = Duration(seconds: 45);

enum SocialAuthProvider { apple, google }

enum AuthFailureReason {
  cancelled,
  needsConfiguration,
  providerUnavailable,
  backendRejected,
  network,
  unknown,
}

class AuthRuntimeConfig {
  const AuthRuntimeConfig({
    this.backendBaseUrl = const String.fromEnvironment(
      'CHESSNUT_API_BASE_URL',
      defaultValue: ChessnutEndpointConfig.defaultApiBaseUrl,
    ),
    this.googleServerClientId = const String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
      defaultValue: chessnutGoogleServerClientId,
    ),
    this.appleServiceId = const String.fromEnvironment(
      'APPLE_SERVICE_ID',
      defaultValue: chessnutAppleServiceId,
    ),
    this.appleRedirectUri = const String.fromEnvironment(
      'APPLE_REDIRECT_URI',
      defaultValue: chessnutAppleRedirectUri,
    ),
  });

  final String backendBaseUrl;
  final String googleServerClientId;
  final String appleServiceId;
  final String appleRedirectUri;

  bool get hasBackend => backendBaseUrl.trim().isNotEmpty;
  bool get hasGoogleServerClientId => googleServerClientId.trim().isNotEmpty;
  String get resolvedAppleRedirectUri {
    final configured = appleRedirectUri.trim();
    if (configured.isNotEmpty) return configured;
    return chessnutAppleRedirectUri;
  }

  bool get hasAppleWebConfig =>
      appleServiceId.trim().isNotEmpty && resolvedAppleRedirectUri.isNotEmpty;

  WebAuthenticationOptions appleWebAuthenticationOptions() {
    final serviceId = appleServiceId.trim();
    final redirectUri = Uri.tryParse(resolvedAppleRedirectUri);
    if (serviceId.isEmpty ||
        redirectUri == null ||
        !redirectUri.hasScheme ||
        redirectUri.host.isEmpty) {
      throw const AuthException.needsConfiguration(
        'Apple sign in needs a Service ID and redirect URL for this platform.',
      );
    }
    return WebAuthenticationOptions(
      clientId: serviceId,
      redirectUri: redirectUri,
    );
  }
}

class ExternalAuthCredential {
  const ExternalAuthCredential({
    required this.provider,
    required this.providerUserId,
    this.identityToken,
    this.authorizationCode,
    this.email,
    this.displayName,
  });

  final SocialAuthProvider provider;
  final String providerUserId;
  final String? identityToken;
  final String? authorizationCode;
  final String? email;
  final String? displayName;

  Map<String, Object?> toJson() => {
        'provider': provider.name,
        'providerUserId': providerUserId,
        'identityToken': identityToken,
        'authorizationCode': authorizationCode,
        'email': email,
        'displayName': displayName,
      };
}

class AuthFailure {
  const AuthFailure({
    required this.reason,
    required this.message,
  });

  final AuthFailureReason reason;
  final String message;
}

class AuthResult {
  const AuthResult._({this.session, this.error});

  const AuthResult.success(ChessnutLoginSession session)
      : this._(session: session);

  const AuthResult.failure(AuthFailure error) : this._(error: error);

  final ChessnutLoginSession? session;
  final AuthFailure? error;

  bool get isSuccess => session != null;
}

class AuthException implements Exception {
  const AuthException(this.reason, this.message);

  const AuthException.cancelled()
      : this(AuthFailureReason.cancelled, 'Sign in was cancelled.');

  const AuthException.needsConfiguration(String message)
      : this(AuthFailureReason.needsConfiguration, message);

  const AuthException.providerUnavailable(String message)
      : this(AuthFailureReason.providerUnavailable, message);

  const AuthException.backendRejected(String message)
      : this(AuthFailureReason.backendRejected, message);

  const AuthException.network(String message)
      : this(AuthFailureReason.network, message);

  final AuthFailureReason reason;
  final String message;
}

abstract class SocialAuthBroker {
  Future<ExternalAuthCredential> signInWithApple(AuthRuntimeConfig config);

  Future<ExternalAuthCredential> signInWithGoogle(AuthRuntimeConfig config);
}

abstract class ChessnutAuthBackend {
  bool get isConfigured;

  Future<ChessnutLoginSession> exchangeExternalCredential(
    ExternalAuthCredential credential,
  );
}

class MissingAuthBackend implements ChessnutAuthBackend {
  const MissingAuthBackend();

  @override
  bool get isConfigured => false;

  @override
  Future<ChessnutLoginSession> exchangeExternalCredential(
    ExternalAuthCredential credential,
  ) {
    throw const AuthException.needsConfiguration(
      'Sign-in service is unavailable. Please try again later.',
    );
  }
}

class LegacyChessnutAuthBackend implements ChessnutAuthBackend {
  const LegacyChessnutAuthBackend({required this.apiClient});

  final ChessnutApiClient apiClient;

  @override
  bool get isConfigured => true;

  @override
  Future<ChessnutLoginSession> exchangeExternalCredential(
    ExternalAuthCredential credential,
  ) async {
    final result = switch (credential.provider) {
      SocialAuthProvider.apple => await apiClient.loginWithApple(
          credential.identityToken ?? '',
          authorizationCode: credential.authorizationCode,
        ),
      SocialAuthProvider.google => await apiClient.loginWithGoogle(
          credential.identityToken ?? '',
        ),
    };
    if (!result.isSuccess || result.data == null) {
      if (result.status.networkError != null) {
        throw AuthException.network(result.status.errorMessage!);
      }
      throw AuthException.backendRejected(
        result.status.errorMessage ??
            'Chessnut could not complete ${credential.provider.name} sign in. Try again or use email sign in.',
      );
    }
    final session = result.data!;
    if (session.token.trim().isEmpty) {
      throw const AuthException.backendRejected(
        'Sign in did not finish. Please try again.',
      );
    }
    return session;
  }
}

class FlutterSocialAuthBroker implements SocialAuthBroker {
  FlutterSocialAuthBroker({GoogleSignIn? googleSignIn})
      : googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn googleSignIn;

  @override
  Future<ExternalAuthCredential> signInWithApple(
    AuthRuntimeConfig config,
  ) async {
    final useWebFlow = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.fuchsia;
    final WebAuthenticationOptions? webOptions = useWebFlow
        ? config.appleWebAuthenticationOptions()
        : config.hasAppleWebConfig
            ? config.appleWebAuthenticationOptions()
            : null;

    if (!useWebFlow) {
      final available = await SignInWithApple.isAvailable();
      if (!available) {
        throw const AuthException.providerUnavailable(
          'Apple sign in is not available on this device yet.',
        );
      }
    }

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: webOptions,
      );
      final providerUserId =
          credential.userIdentifier ?? _appleSubject(credential.identityToken);

      return ExternalAuthCredential(
        provider: SocialAuthProvider.apple,
        providerUserId: providerUserId,
        identityToken: credential.identityToken,
        authorizationCode: credential.authorizationCode,
        email: credential.email,
        displayName: [
          credential.givenName,
          credential.familyName,
        ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' '),
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const AuthException.cancelled();
      }
      throw AuthException.providerUnavailable(error.message);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException.providerUnavailable(
        'Apple sign in is not available on this device yet.',
      );
    }
  }

  @override
  Future<ExternalAuthCredential> signInWithGoogle(
    AuthRuntimeConfig config,
  ) async {
    if (!config.hasGoogleServerClientId) {
      throw const AuthException.needsConfiguration(
        'Google sign in is not ready yet. Please use another sign-in method.',
      );
    }

    try {
      await googleSignIn
          .initialize(
            serverClientId: config.googleServerClientId,
          )
          .timeout(_googleSignInTimeout);
      final account =
          await googleSignIn.authenticate().timeout(_googleSignInTimeout);
      final auth = account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.trim().isEmpty) {
        throw const AuthException.providerUnavailable(
          'Google sign in did not finish. Please try again.',
        );
      }

      return ExternalAuthCredential(
        provider: SocialAuthProvider.google,
        providerUserId: account.id,
        identityToken: idToken,
        email: account.email,
        displayName: account.displayName,
      );
    } on TimeoutException {
      throw const AuthException.providerUnavailable(
        'Google sign in timed out. Please try again.',
      );
    } on GoogleSignInException catch (error) {
      final description = error.description?.trim();
      if (error.code == GoogleSignInExceptionCode.canceled &&
          (description == null || description.isEmpty)) {
        throw const AuthException.cancelled();
      }
      throw AuthException.providerUnavailable(
        description ?? 'Google sign in failed.',
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException.providerUnavailable(
        'Google sign in is not available on this device yet.',
      );
    }
  }
}

class AuthService {
  AuthService({
    SocialAuthBroker? broker,
    ChessnutAuthBackend? backend,
    ChessnutApiClient? apiClient,
    AuthRuntimeConfig? config,
  })  : config = config ?? const AuthRuntimeConfig(),
        broker = broker ?? FlutterSocialAuthBroker(),
        backend = backend ??
            (apiClient == null
                ? const MissingAuthBackend()
                : LegacyChessnutAuthBackend(apiClient: apiClient));

  final SocialAuthBroker broker;
  final ChessnutAuthBackend backend;
  final AuthRuntimeConfig config;

  Future<AuthResult> signInWith(SocialAuthProvider provider) async {
    try {
      if (!backend.isConfigured) {
        throw const AuthException.needsConfiguration(
          'Sign-in service is unavailable. Please try again later.',
        );
      }

      final credential = switch (provider) {
        SocialAuthProvider.apple => await broker.signInWithApple(config),
        SocialAuthProvider.google => await broker.signInWithGoogle(config),
      };

      if (credential.providerUserId.trim().isEmpty) {
        throw const AuthException.providerUnavailable(
          'Sign in did not finish. Please try again.',
        );
      }

      return AuthResult.success(
        await backend.exchangeExternalCredential(credential),
      );
    } on AuthException catch (error) {
      return AuthResult.failure(
        AuthFailure(reason: error.reason, message: error.message),
      );
    } catch (_) {
      return const AuthResult.failure(
        AuthFailure(
          reason: AuthFailureReason.unknown,
          message: 'Sign in failed. Please try again.',
        ),
      );
    }
  }
}

String _appleSubject(String? identityToken) {
  final token = identityToken?.trim();
  if (token == null || token.isEmpty) return '';
  final parts = token.split('.');
  if (parts.length < 2) return '';
  try {
    final payload =
        String.fromCharCodes(base64Url.decode(base64Url.normalize(parts[1])));
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) {
      return decoded['sub']?.toString() ?? '';
    }
  } catch (_) {
    return '';
  }
  return '';
}
