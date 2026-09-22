import 'dart:convert';
import 'dart:io';

import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/services/model_build_source_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('batch PGN upload posts selected games and platform source', () async {
    late http.Request captured;
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': 2,
          }),
          200,
        );
      }),
    );

    final result = await client.uploadPgnList(
      pgnList: '[Event "One"]\n\n1. e4 e5 1-0',
      source: 'lichess',
    );

    expect(captured.url.path, '/api/uploadPgnList');
    expect(captured.bodyFields['pgnList'], contains('[Event "One"]'));
    expect(captured.bodyFields['source'], 'lichess');
    expect(captured.bodyFields['user_id'], '7');
    expect(result.isSuccess, isTrue);
    expect(result.data, 2);
  });

  test('bug report diagnostics serializes real app and device metadata', () {
    const diagnostics = BugReportDiagnostics(
      appVersion: '0.5.10',
      appBuildNumber: '5010',
      platform: 'android',
      locale: 'zh-Hans',
      route: 'Settings',
      boardModel: 'Not connected',
      boardConnected: false,
      signedIn: true,
      log: 'gateway_state=disconnected',
      generatedAt: '2026-07-21T12:00:00.000Z',
      deviceManufacturer: 'Samsung',
      deviceModel: 'SM-S9110',
      osVersion: '15',
      osSdk: 35,
    );

    expect(diagnostics.toJson(), {
      'app_version': '0.5.10',
      'app_build_number': '5010',
      'platform': 'android',
      'locale': 'zh-Hans',
      'route': 'Settings',
      'board_model': 'Not connected',
      'board_connected': false,
      'signed_in': true,
      'log': 'gateway_state=disconnected',
      'generated_at': '2026-07-21T12:00:00.000Z',
      'device_manufacturer': 'Samsung',
      'device_model': 'SM-S9110',
      'os_version': '15',
      'os_sdk': 35,
    });
  });

  test('login posts legacy form data and parses Chessnut session', () async {
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
              'avatar_url': 'https://cdn.chessnut/avatar.png',
              'bind_apple': false,
              'bind_chess': true,
              'bind_google': true,
              'bind_lichess': true,
              'chess_name': 'ChessComName',
              'email': 'player@example.com',
              'lichess_name': 'LichessName',
              'no_password': false,
              'region': 'US',
              'token': '12345678901234567890123456789012',
              'refresh_token': 'refresh-token',
              'user_id': 42,
              'username': 'Player',
            },
          }),
          200,
        );
      }),
    );

    final result = await client.login('player@example.com', 'secret');

    expect(captured.method, 'POST');
    expect(captured.url.toString(), 'https://api.chessnutech.com/api/login');
    expect(captured.bodyFields['account'], 'player@example.com');
    expect(
      captured.bodyFields['password'],
      '2bb80d537b1da3e38bd30361aa855686bde0eacd7162fef6a25'
      'fe97bf527a25b',
    );
    expect(captured.bodyFields['lang'], 'en');
    expect(result.isSuccess, isTrue);
    expect(result.data?.userId, 42);
    expect(result.data?.token, '12345678901234567890123456789012');
    expect(result.data?.refreshToken, 'refresh-token');
    expect(result.data?.bindGoogle, isTrue);
    expect(result.data?.bindLichess, isTrue);
  });

  test('language notifier controls lang form field on later requests',
      () async {
    final captured = <http.Request>[];
    final client = ChessnutApiClient(
      language: 'en',
      httpClient: MockClient((request) async {
        captured.add(request);
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': {
              'avatar_url': '',
              'bind_apple': false,
              'bind_chess': false,
              'bind_google': false,
              'bind_lichess': false,
              'chess_name': '',
              'email': 'player@example.com',
              'lichess_name': '',
              'no_password': false,
              'region': 'US',
              'token': '12345678901234567890123456789012',
              'refresh_token': 'refresh-token',
              'user_id': 42,
              'username': 'Player',
            },
          }),
          200,
        );
      }),
    );

    await client.login('player@example.com', 'secret');
    client.language.value = 'zh';
    await client.login('player@example.com', 'secret');

    expect(captured.map((request) => request.bodyFields['lang']).toList(), [
      'en',
      'zh',
    ]);
  });

  test('auth options parse phone-first China login methods', () async {
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
              'country': 'CN',
              'preferred_login_method': 'phone',
              'methods': ['phone', 'wechat', 'email_password'],
            },
          }),
          200,
        );
      }),
    );

    final result = await client.authOptions();

    expect(captured.url.path, '/api/v3/authOptions');
    expect(result.isSuccess, isTrue);
    expect(result.data?.country, 'CN');
    expect(result.data?.preferredLoginMethod, 'phone');
    expect(result.data?.methods, contains('email_password'));
  });

  test('PGN list parses alternate total count fields', () async {
    final client = ChessnutApiClient(
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': {
              'total_count': 37,
              'page_count': 4,
              'pgnList': [],
            },
          }),
          200,
        );
      }),
    );
    client.session = const ChessnutLoginSession(
      userId: 7,
      token: '12345678901234567890123456789012',
      avatarUrl: '',
      bindApple: false,
      bindChess: false,
      bindGoogle: false,
      bindLichess: false,
      chessName: '',
      email: 'player@example.com',
      lichessName: '',
      noPassword: false,
      phone: '',
      region: 'US',
      username: 'Player',
    );

    final result = await client.getPgnList(page: 1, count: 10);

    expect(result.isSuccess, isTrue);
    expect(result.data?.total, 37);
    expect(result.data?.totalPage, 4);
  });

  test('game record source counts use the aggregate endpoint', () async {
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
              'all': 12,
              'local': 7,
              'lichess': 3,
              'chess_com': 2,
            },
          }),
          200,
        );
      }),
    );
    client.session = const ChessnutLoginSession(
      userId: 7,
      token: '12345678901234567890123456789012',
      avatarUrl: '',
      bindApple: false,
      bindChess: false,
      bindGoogle: false,
      bindLichess: false,
      chessName: '',
      email: 'player@example.com',
      lichessName: '',
      noPassword: false,
      phone: '',
      region: 'US',
      username: 'Player',
    );

    final result = await client.getGameRecordSourceCounts();

    expect(captured.url.path, '/api/v3/gameRecords/sourceCounts');
    expect(captured.bodyFields['user_id'], '7');
    expect(result.isSuccess, isTrue);
    expect(result.data?.all, 12);
    expect(result.data?.local, 7);
    expect(result.data?.lichess, 3);
    expect(result.data?.chessCom, 2);
  });

  test('phone login sends code and posts verification code login', () async {
    final captured = <http.Request>[];
    final client = ChessnutApiClient(
      httpClient: MockClient((request) async {
        captured.add(request);
        if (request.url.path == '/api/v3/sendPhoneLoginCode') {
          return http.Response(
            jsonEncode({
              'ret': 1,
              'code': 200,
              'info': 'ok',
              'data': {'phone': '+8613812345678', 'expires_in': 300},
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': {
              'avatar_url': '',
              'bind_apple': false,
              'bind_chess': false,
              'bind_google': false,
              'bind_lichess': false,
              'chess_name': '',
              'email': 'phone_8613812345678@phone.chessnut.local',
              'lichess_name': '',
              'no_password': true,
              'region': 'CN',
              'token': '12345678901234567890123456789012',
              'refresh_token': 'refresh-token',
              'user_id': 99,
              'username': 'phone_5678',
            },
          }),
          200,
        );
      }),
    );

    final sendResult = await client.sendPhoneLoginCode('13812345678');
    final loginResult = await client.loginWithPhoneCode(
      phone: '13812345678',
      code: '123456',
    );

    expect(sendResult.isSuccess, isTrue);
    expect(sendResult.data?.expiresIn, 300);
    expect(captured.first.url.path, '/api/v3/sendPhoneLoginCode');
    expect(captured.first.bodyFields['phone'], '13812345678');
    expect(captured.last.url.path, '/api/v3/loginWithPhoneCode');
    expect(captured.last.bodyFields['code'], '123456');
    expect(loginResult.isSuccess, isTrue);
    expect(loginResult.data?.userId, 99);
    expect(loginResult.data?.noPassword, isTrue);
  });

  test('network lookup failures use user friendly offline copy', () async {
    final client = ChessnutApiClient(
      httpClient: MockClient((request) async {
        throw const SocketException(
          'Failed host lookup: api.chessnutech.com',
          osError: OSError('No address associated with hostname', 7),
        );
      }),
    );

    final result = await client.login('player@example.com', 'secret');

    expect(result.isSuccess, isFalse);
    expect(
      result.status.networkError,
      'No internet connection. Check Wi-Fi or mobile data, then try again.',
    );
    expect(
      result.status.errorMessage,
      'No internet connection. Check Wi-Fi or mobile data, then try again.',
    );
  });

  test('bug report posts multipart diagnostics and attachments', () async {
    late http.BaseRequest captured;
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient.streaming((request, bodyStream) async {
        captured = request;
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': {'report_id': 'bug_abc'},
          }))),
          200,
        );
      }),
    );

    final result = await client.submitBugReport(
      description: 'Bot engine moved illegally after promotion.',
      contact: 'tester@example.com',
      diagnostics: const BugReportDiagnostics(
        appVersion: '0.5.10',
        appBuildNumber: '5010',
        platform: 'android',
        locale: 'en-US',
        route: 'Play',
        boardModel: 'Chessnut Air+',
        boardConnected: true,
        signedIn: true,
        log: 'latest app log',
        generatedAt: '2026-07-21T12:00:00.000Z',
        deviceManufacturer: 'Samsung',
        deviceModel: 'SM-S9110',
        osVersion: '15',
        osSdk: 35,
      ),
      attachments: const [
        BugReportAttachment(
          filename: 'screen.png',
          bytes: [1, 2, 3],
          contentType: 'image/png',
        ),
      ],
    );

    expect(result.isSuccess, isTrue);
    expect(result.data?.reportId, 'bug_abc');
    expect(captured, isA<http.MultipartRequest>());
    final multipart = captured as http.MultipartRequest;
    expect(multipart.url.path, '/api/v3/bugReport');
    expect(multipart.fields['user_id'], '7');
    expect(multipart.fields['token'], '12345678901234567890123456789012');
    expect(multipart.fields['description'], contains('promotion'));
    expect(multipart.fields['contact'], 'tester@example.com');
    expect(multipart.fields['diagnostics'], contains('Chessnut Air+'));
    expect(multipart.fields['diagnostics'], contains('0.5.10'));
    expect(multipart.fields['diagnostics'], contains('5010'));
    expect(multipart.fields['diagnostics'], contains('SM-S9110'));
    expect(multipart.fields['diagnostics'], contains('Samsung'));
    expect(multipart.files.single.filename, 'screen.png');
  });

  test('bug report can be submitted before login', () async {
    late http.BaseRequest captured;
    final client = ChessnutApiClient(
      httpClient: MockClient.streaming((request, bodyStream) async {
        captured = request;
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': {'report_id': 'bug_guest'},
          }))),
          200,
        );
      }),
    );

    final result = await client.submitBugReport(
      description: 'Guest login screen failed without network.',
      contact: '',
      diagnostics: const BugReportDiagnostics(
        appVersion: '0.1.0',
        platform: 'android',
        locale: 'en-US',
        route: 'Auth',
        boardModel: 'Chessnut board',
        boardConnected: false,
        signedIn: false,
        log: 'offline error',
      ),
    );

    final multipart = captured as http.MultipartRequest;
    expect(result.isSuccess, isTrue);
    expect(multipart.fields.containsKey('user_id'), isFalse);
    expect(multipart.fields.containsKey('token'), isFalse);
    expect(multipart.fields['diagnostics'], contains('offline error'));
  });

  test('Grandeur review starts through v3 wallet-backed comment API', () async {
    late http.Request captured;
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': {
              'comment_id': 91,
              'train_status': 0,
              'comment_file': '',
              'points_consumed': 100,
              'already_unlocked': false,
              'member_unlimited': false,
              'pgn_id': 42,
              'share_id': 'share123',
              'lang': 'fr',
            },
          }),
          200,
        );
      }),
    );

    final result = await client.startGrandeurReview(
      pgn: '[Result "*"]\n\n1. e4 *',
      language: 'yue-HK',
      gameStep: 1,
      style: 'rapid',
    );

    expect(result.isSuccess, isTrue);
    expect(result.data?.commentId, 91);
    expect(result.data?.pointsConsumed, 100);
    expect(result.data?.language, 'fr');
    expect(captured.url.path, '/api/v3/grandeur/push');
    expect(captured.bodyFields['user_id'], '7');
    expect(captured.bodyFields['token'], '12345678901234567890123456789012');
    expect(captured.bodyFields.containsKey('pgn_id'), isFalse);
    expect(captured.bodyFields['game_step'], '1');
    expect(captured.bodyFields['lang'], 'yue-HK');
    expect(captured.bodyFields['style'], 'rapid');
  });

  test('Maia3 human review preserves per-move probabilities', () {
    final report = Maia3HumanReviewReport.fromJson({
      'version': 1,
      'source': 'maia3_microservice',
      'model': 'maia3-5m',
      'elo': 1500,
      'generated_at': '2026-06-15T00:00:00Z',
      'summary': {
        'human_match_percent': 33.3,
        'most_human_side': 'black',
        'sharpest_moments': [1],
        'notes': ['Maia3 shows likely human choices.'],
      },
      'moves': [
        {
          'ply': 1,
          'move': 'a3',
          'move_uci': 'a2a3',
          'fen': 'fen1',
          'last_move': ['a2', 'a3'],
          'played_probability': 0.0008,
          'typicality': 'rare',
          'human_label': 'Rare human choice',
          'candidates': [
            {'move': 'e2e4', 'san': 'e4', 'probability': 0.6428},
          ],
        },
        {
          'ply': 2,
          'move': 'e5',
          'move_uci': 'e7e5',
          'fen': 'fen2',
          'last_move': ['e7', 'e5'],
          'played_probability': 0.431,
          'typicality': 'common',
          'human_label': 'Common human choice',
          'candidates': [
            {'move': 'e7e5', 'san': 'e5', 'probability': 0.431},
          ],
        },
        {
          'ply': 3,
          'move': 'h3',
          'move_uci': 'h2h3',
          'fen': 'fen3',
          'last_move': ['h2', 'h3'],
          'played_probability': 0.1512,
          'typicality': 'plausible',
          'human_label': 'Plausible human choice',
          'candidates': [
            {'move': 'b2b4', 'san': 'b4', 'probability': 0.3606},
          ],
        },
      ],
    });

    expect(
      report.moves.map((move) => move.playedProbability).toList(),
      [0.0008, 0.431, 0.1512],
    );
    expect(
      report.moves.map((move) => move.candidates.single.probability).toList(),
      [0.6428, 0.431, 0.3606],
    );
  });

  test('Grandeur report parser reads commentary without embedded audio', () {
    final result = GrandeurAnalysisResult.fromJson({
      'id': 'legacy-steps-report',
      'language': 'de',
      'overall_summary': 'Backend says White converted the opening initiative.',
      'steps': [
        {
          'move': 'e4',
          'classification': 'Best',
          'commentary': 'Backend coach says e4 takes space immediately.',
        },
        {
          'ply': 2,
          'san': 'e5',
          'classification': 'Good',
          'commentary': 'Backend coach says Black mirrors the center.',
          'lang': 'fr',
        },
      ],
    });

    expect(result.analysisId, 'legacy-steps-report');
    expect(result.language, 'de');
    expect(
      result.summaryText,
      'Backend says White converted the opening initiative.',
    );
    expect(result.moves, hasLength(2));
    expect(result.moves.first.ply, 1);
    expect(result.moves.first.san, 'e4');
    expect(result.moves.first.why,
        'Backend coach says e4 takes space immediately.');
    expect(result.moves.last.ply, 2);
    expect(result.moves.last.language, 'fr');
    expect(
        result.moves.last.why, 'Backend coach says Black mirrors the center.');
  });

  test('social login endpoints post provider tokens and update session',
      () async {
    final captured = <http.Request>[];
    final client = ChessnutApiClient(
      httpClient: MockClient((request) async {
        captured.add(request);
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': {
              'avatar_url': '',
              'bind_apple': request.url.path == '/api/loginWithApple',
              'bind_chess': false,
              'bind_google': request.url.path == '/api/loginWithGoogle',
              'bind_lichess': false,
              'chess_name': '',
              'email': 'player@example.com',
              'lichess_name': '',
              'no_password': true,
              'region': 'US',
              'token': '12345678901234567890123456789012',
              'refresh_token': 'refresh-token',
              'user_id': 42,
              'username': 'Player',
            },
          }),
          200,
        );
      }),
    );

    final google = await client.loginWithGoogle('google-id-token');
    final apple = await client.loginWithApple(
      'apple-identity-token',
      authorizationCode: 'apple-auth-code',
    );

    expect(google.data?.bindGoogle, isTrue);
    expect(apple.data?.bindApple, isTrue);
    expect(client.session?.token, '12345678901234567890123456789012');
    expect(captured.map((request) => request.url.path).toList(), [
      '/api/loginWithGoogle',
      '/api/loginWithApple',
    ]);
    expect(captured[0].bodyFields['id_token'], 'google-id-token');
    expect(captured[1].bodyFields['identity_token'], 'apple-identity-token');
    expect(captured[1].bodyFields['authorization_code'], 'apple-auth-code');
  });

  test('authorized pgn upload adds user id and token and returns share url',
      () async {
    late http.Request captured;
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': {
              'pgn_id': 99,
              's_id': 'share-abc',
              'daily_task_reward': {
                'balance': 120,
                'points_added': 20,
                'claimed_today': true,
              },
            },
          }),
          200,
        );
      }),
    );

    final result = await client.uploadPgn(
      pgn: '[Event "OTB"]\n1. e4 e5 *',
      whiteName: 'White',
      blackName: 'Black',
      playTime: '1715900000',
      playMode: 'bot',
      winId: 1,
      gameStatus: 2,
      gameStep: 12,
      metadata: const PgnSaveMetadata(
        playerColor: 'white',
        speed: 'rapid',
        timeControl: '10+5',
        opponentName: 'Black',
      ),
    );

    expect(
        captured.url.toString(), 'https://api.chessnutech.com/api/uploadPgn');
    expect(captured.bodyFields['user_id'], '7');
    expect(captured.bodyFields['token'], '12345678901234567890123456789012');
    expect(captured.bodyFields['pgn'], contains('1. e4 e5'));
    expect(captured.bodyFields['play_mode'], 'bot');
    expect(captured.bodyFields['player_color'], 'white');
    expect(captured.bodyFields['speed'], 'rapid');
    expect(captured.bodyFields['time_control'], '10+5');
    expect(captured.bodyFields['opponent_name'], 'Black');
    expect(result.data?.pgnId, 99);
    expect(result.data?.shareId, 'share-abc');
    expect(result.data?.dailyTaskReward?.pointsAdded, 20);
    expect(result.data?.dailyTaskReward?.balance, 120);
    expect(client.shareUrl('share-abc').toString(),
        'https://api.chessnutech.com/v3/share/share-abc');
  });

  test('authorized requests clear session when refresh token is unavailable',
      () async {
    var didExpire = false;
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      onAuthExpired: () => didExpire = true,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'ret': 0,
            'code': 600,
            'info': 'token expired',
            'data': null,
          }),
          200,
        );
      }),
    );

    final result = await client.getPgnList();

    expect(result.isSuccess, isFalse);
    expect(result.status.apiErrorCode, 600);
    expect(result.status.errorMessage, authSessionExpiredMessage);
    expect(didExpire, isTrue);
    expect(client.session, isNull);
  });

  test('authorized requests refresh an expired access token and ask to retry',
      () async {
    var refreshCount = 0;
    ChessnutLoginSession? persistedSession;
    String? refreshedMessage;
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: 'expired-access-token-00000000000',
        refreshToken: 'refresh-token',
      ),
      onSessionRefreshed: (session) => persistedSession = session,
      onAuthTokenRefreshed: (message) => refreshedMessage = message,
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/Token/Refresh') {
          refreshCount++;
          return http.Response(
            jsonEncode({
              'ret': 1,
              'code': 200,
              'info': 'ok',
              'data': _loginSessionJson(token: 'new-access-token'),
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'ret': 0,
            'code': 600,
            'info': 'token expired',
            'data': null,
          }),
          200,
        );
      }),
    );

    final result = await client.getPgnList();

    expect(result.isSuccess, isFalse);
    expect(result.status.apiErrorCode, authTokenRefreshedRetryCode);
    expect(result.status.errorMessage, authTokenRefreshedRetryMessage);
    expect(refreshCount, 1);
    expect(client.session?.token, 'new-access-token');
    expect(client.session?.refreshToken, 'refresh-token');
    expect(persistedSession?.token, 'new-access-token');
    expect(refreshedMessage, authTokenRefreshedRetryMessage);
  });

  test('expired refresh token clears the complete login session', () async {
    var didExpire = false;
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: 'expired-access-token-00000000000',
        refreshToken: 'expired-refresh-token',
      ),
      onAuthExpired: () => didExpire = true,
      httpClient: MockClient((request) async {
        final refreshRequest = request.url.path == '/api/Token/Refresh';
        return http.Response(
          jsonEncode({
            'ret': 0,
            'code': refreshRequest ? 501 : 600,
            'info': refreshRequest ? 'login timed out' : 'token expired',
            'data': null,
          }),
          200,
        );
      }),
    );

    final result = await client.getPgnList();

    expect(result.status.apiErrorCode, 600);
    expect(result.status.errorMessage, authSessionExpiredMessage);
    expect(didExpire, isTrue);
    expect(client.session, isNull);
  });

  test('network failures never clear saved login tokens', () async {
    var didExpire = false;
    String? networkMessage;
    const originalSession = ChessnutApiSession(
      userId: 7,
      token: 'active-access-token-000000000000',
      refreshToken: 'refresh-token',
    );
    final client = ChessnutApiClient(
      session: originalSession,
      onAuthExpired: () => didExpire = true,
      onNetworkError: (message) => networkMessage = message,
      httpClient: MockClient((request) async {
        throw const SocketException('network unavailable');
      }),
    );

    final result = await client.getPgnList();

    expect(result.status.networkError, networkConnectionErrorMessage);
    expect(networkMessage, networkConnectionErrorMessage);
    expect(didExpire, isFalse);
    expect(client.session, same(originalSession));
  });

  test('network failure while refreshing an expired token keeps login tokens',
      () async {
    var didExpire = false;
    var requestCount = 0;
    const originalSession = ChessnutApiSession(
      userId: 7,
      token: 'expired-access-token-00000000000',
      refreshToken: 'refresh-token',
    );
    final client = ChessnutApiClient(
      session: originalSession,
      onAuthExpired: () => didExpire = true,
      httpClient: MockClient((request) async {
        requestCount++;
        if (request.url.path == '/api/Token/Refresh') {
          throw const SocketException('network unavailable');
        }
        return http.Response(
          jsonEncode({
            'ret': 0,
            'code': 600,
            'info': 'token expired',
            'data': null,
          }),
          200,
        );
      }),
    );

    final result = await client.getPgnList();

    expect(requestCount, 2);
    expect(result.status.networkError, networkConnectionErrorMessage);
    expect(didExpire, isFalse);
    expect(client.session, same(originalSession));
  });

  test('v3 game record search and lichess import endpoints are wired',
      () async {
    final captured = <http.Request>[];
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        captured.add(request);
        final data = switch (request.url.path) {
          '/api/v3/gameRecords/search' => {
              'pgnList': [
                {
                  'id': 10,
                  'white_name': 'Alice',
                  'black_name': 'Bob',
                  'play_mode': 'lichess-blitz',
                  'play_time': '1779840000',
                  'game_status': 2,
                  'game_step': 42,
                  'win_id': 1,
                  'pgn': '/static/local_pgn/7/a.pgn',
                  's_id': 'share10',
                },
              ],
              'total_page': 3,
              'total': 41,
            },
          '/api/v3/lichess/import/start' => {
              'job_id': 'li_abc',
              'player_id': 'alice',
              'status': 'queued',
              'max_games': 500,
              'inserted': 0,
              'skipped': 0,
              'failed': 0,
              'total': 0,
            },
          '/api/v3/lichess/import/status' => {
              'job_id': 'li_abc',
              'player_id': 'alice',
              'status': 'completed',
              'max_games': 500,
              'inserted': 480,
              'skipped': 20,
              'failed': 0,
              'processed': 500,
              'total': 500,
              'progress_percent': 100,
              'user_message': '480 new games imported.',
              'completed_at': '2026-06-04T12:00:00Z',
            },
          '/api/v3/lichess/import/cancel' => {
              'job_id': 'li_abc',
              'player_id': 'alice',
              'status': 'canceled',
              'max_games': 500,
              'inserted': 100,
              'skipped': 20,
              'failed': 0,
              'processed': 120,
              'total': 500,
              'progress_percent': 24,
              'user_message': 'Lichess import was canceled.',
            },
          '/api/v3/modelBuild/gameRecords/previewStart' => {
              'job_id': 'mbgr_preview',
              'status': 'queued',
              'requested_count': 200,
              'matched_count': 0,
              'processed_count': 0,
              'usable_count': 0,
              'skipped_count': 0,
              'failed_count': 0,
              'progress_percent': 0,
              'submit_training': false,
              'training_id': 0,
              'user_message': 'Model Build preparation queued.',
            },
          '/api/v3/modelBuild/gameRecords/status' => {
              'job_id': 'mbgr_preview',
              'status': 'completed',
              'requested_count': 200,
              'matched_count': 72,
              'processed_count': 72,
              'usable_count': 64,
              'skipped_count': 6,
              'failed_count': 2,
              'progress_percent': 100,
              'submit_training': false,
              'training_id': 0,
              'status_detail': '64 usable games are ready.',
              'user_message': '64 games are ready for Model Build.',
            },
          '/api/v3/modelBuild/gameRecords/pushStart' => {
              'job_id': 'mbgr_push',
              'status': 'queued',
              'title': 'Alice model',
              'remark': 'Filtered from server records',
              'requested_count': 200,
              'matched_count': 0,
              'processed_count': 0,
              'usable_count': 0,
              'skipped_count': 0,
              'failed_count': 0,
              'progress_percent': 0,
              'submit_training': true,
              'training_id': 0,
              'user_message': 'Model Build preparation queued.',
            },
          '/api/v3/modelBuild/gameRecords/cancel' => {
              'job_id': 'mbgr_push',
              'status': 'canceled',
              'requested_count': 200,
              'matched_count': 72,
              'processed_count': 20,
              'usable_count': 18,
              'skipped_count': 2,
              'failed_count': 0,
              'progress_percent': 30,
              'submit_training': true,
              'training_id': 0,
              'user_message': 'Model Build preparation was canceled.',
            },
          _ => throw StateError('unexpected path ${request.url.path}'),
        };
        return http.Response(
          jsonEncode({'ret': 1, 'code': 200, 'info': 'ok', 'data': data}),
          200,
        );
      }),
    );

    final search = await client.searchGameRecords(
      const GameRecordSearchRequest(
        page: 2,
        count: 50,
        query: 'alice',
        mode: 'lichess',
        result: 'decisive',
        minMoves: 20,
        sort: 'oldest',
      ),
    );
    final started = await client.startLichessHistoryImport(
      playerId: 'alice',
      maxGames: 500,
      since: '2026-01-01',
      speed: 'blitz',
      rated: 'true',
      color: 'white',
    );
    final status = await client.lichessHistoryImportStatus('li_abc');
    final canceledImport = await client.cancelLichessHistoryImport('li_abc');
    final modelBuildPreview = await client.startModelBuildGameRecordsPreview(
      request: const GameRecordSearchRequest(
        count: 100,
        mode: 'lichess',
        speed: 'blitz',
        color: 'white',
        minMoves: 20,
      ),
      limit: 200,
    );
    final modelBuildStatus =
        await client.modelBuildGameRecordsStatus('mbgr_preview');
    final modelBuildPush = await client.startModelBuildGameRecordsPush(
      request: const GameRecordSearchRequest(
        count: 100,
        mode: 'lichess',
        speed: 'blitz',
      ),
      title: 'Alice model',
      remark: 'Filtered from server records',
      limit: 200,
    );
    final modelBuildCancel =
        await client.cancelModelBuildGameRecordsJob('mbgr_push');
    expect(search.data?.records.single.whiteName, 'Alice');
    expect(search.data?.total, 41);
    expect(started.data?.status, 'queued');
    expect(status.data?.isDone, isTrue);
    expect(status.data?.inserted, 480);
    expect(status.data?.progressPercent, 100);
    expect(status.data?.userMessage, '480 new games imported.');
    expect(canceledImport.data?.status, 'canceled');
    expect(modelBuildPreview.data?.jobId, 'mbgr_preview');
    expect(modelBuildStatus.data?.usableCount, 64);
    expect(modelBuildStatus.data?.userMessage,
        '64 games are ready for Model Build.');
    expect(modelBuildPush.data?.submitTraining, isTrue);
    expect(modelBuildCancel.data?.status, 'canceled');

    final searchRequest = captured[0];
    expect(searchRequest.url.path, '/api/v3/gameRecords/search');
    expect(searchRequest.bodyFields['page'], '2');
    expect(searchRequest.bodyFields['count'], '50');
    expect(searchRequest.bodyFields['query'], 'alice');
    expect(searchRequest.bodyFields['mode'], 'lichess');
    expect(searchRequest.bodyFields['result'], 'decisive');
    expect(searchRequest.bodyFields['min_moves'], '20');
    expect(searchRequest.bodyFields['sort'], 'oldest');

    final importRequest = captured[1];
    expect(importRequest.url.path, '/api/v3/lichess/import/start');
    expect(importRequest.bodyFields['player_id'], 'alice');
    expect(importRequest.bodyFields['max_games'], '500');
    expect(importRequest.bodyFields['since'], '2026-01-01');
    expect(importRequest.bodyFields['speed'], 'blitz');
    expect(importRequest.bodyFields['rated'], 'true');
    expect(importRequest.bodyFields['color'], 'white');

    expect(captured[2].url.path, '/api/v3/lichess/import/status');
    expect(captured[2].bodyFields['job_id'], 'li_abc');

    expect(captured[3].url.path, '/api/v3/lichess/import/cancel');
    expect(captured[3].bodyFields['job_id'], 'li_abc');

    final modelBuildPreviewRequest = captured[4];
    expect(modelBuildPreviewRequest.url.path,
        '/api/v3/modelBuild/gameRecords/previewStart');
    expect(modelBuildPreviewRequest.bodyFields['mode'], 'lichess');
    expect(modelBuildPreviewRequest.bodyFields['speed'], 'blitz');
    expect(modelBuildPreviewRequest.bodyFields['color'], 'white');
    expect(modelBuildPreviewRequest.bodyFields['min_moves'], '20');
    expect(modelBuildPreviewRequest.bodyFields['limit'], '200');

    expect(captured[5].url.path, '/api/v3/modelBuild/gameRecords/status');
    expect(captured[5].bodyFields['job_id'], 'mbgr_preview');

    final modelBuildPushRequest = captured[6];
    expect(modelBuildPushRequest.url.path,
        '/api/v3/modelBuild/gameRecords/pushStart');
    expect(modelBuildPushRequest.bodyFields['title'], 'Alice model');
    expect(modelBuildPushRequest.bodyFields['remark'],
        'Filtered from server records');
    expect(modelBuildPushRequest.bodyFields['limit'], '200');

    expect(captured[7].url.path, '/api/v3/modelBuild/gameRecords/cancel');
    expect(captured[7].bodyFields['job_id'], 'mbgr_push');
  });

  test('inbox endpoints parse unread count and mark messages read', () async {
    final captured = <http.Request>[];
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        captured.add(request);
        if (request.url.path == '/api/v3/inbox/list') {
          return http.Response(
            jsonEncode({
              'ret': 1,
              'code': 200,
              'info': 'ok',
              'data': {
                'unread_count': 2,
                'items': [
                  {
                    'id': 31,
                    'title': 'New Engine Lab report',
                    'body': 'Your model build is ready to review.',
                    'message_type': 'announcement',
                    'action_label': 'Open Engine Lab',
                    'action_route': 'Engine',
                    'published_at': '2026-05-23T02:30:00Z',
                    'read': false,
                    'read_at': '',
                  }
                ],
              },
            }),
            200,
          );
        }
        if (request.url.path == '/api/v3/inbox/unreadCount') {
          return http.Response(
            jsonEncode({
              'ret': 1,
              'code': 200,
              'info': 'ok',
              'data': {'unread_count': 2},
            }),
            200,
          );
        }
        if (request.url.path == '/api/v3/inbox/markRead') {
          return http.Response(
            jsonEncode({
              'ret': 1,
              'code': 200,
              'info': 'ok',
              'data': {
                'message_id': 31,
                'read': true,
                'unread_count': 1,
              },
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    final inbox = await client.inboxList();
    final unread = await client.inboxUnreadCount();
    final markRead = await client.markInboxMessageRead(31);

    expect(inbox.isSuccess, isTrue);
    expect(inbox.data?.unreadCount, 2);
    expect(inbox.data?.items.single.title, 'New Engine Lab report');
    expect(inbox.data?.items.single.read, isFalse);
    expect(inbox.data?.items.single.actionRoute, 'Engine');
    expect(unread.isSuccess, isTrue);
    expect(unread.data, 2);
    expect(markRead.isSuccess, isTrue);
    expect(markRead.data?.unreadCount, 1);
    expect(captured[0].bodyFields['user_id'], '7');
    expect(captured[0].bodyFields['token'], '12345678901234567890123456789012');
    expect(captured[1].url.path, '/api/v3/inbox/unreadCount');
    expect(captured[2].bodyFields['message_id'], '31');
  });

  test('puzzle endpoints parse lichess puzzle data', () async {
    late Uri capturedUri;
    final client = ChessnutApiClient(
      httpClient: MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            'id': 12,
            'fen': '8/8/8/8/8/8/4K3/4k3 w - - 0 1',
            'move': 'e2e1',
            'lichess_id': 'abcdefgh',
            'tags': 'endgame mate',
            'rating': '1428',
            'rating_min': 1400,
            'rating_max': '1600',
          }),
          200,
        );
      }),
    );

    final puzzle = await client.puzzleTagRandom(3);

    expect(capturedUri.toString(), 'http://puzzle.chessnutech.com/3/random');
    expect(puzzle?.id, 12);
    expect(puzzle?.lichessId, 'abcdefgh');
    expect(puzzle?.tags, 'endgame mate');
    expect(puzzle?.rating, 1428);
    expect(puzzle?.ratingMin, 1400);
    expect(puzzle?.ratingMax, 1600);
  });

  test('lichess board api builds native stream and move endpoints', () {
    const api = LichessBoardApi(token: 'lichess-token');

    expect(
      api.gameStreamUri('game123').toString(),
      'https://lichess.org/api/board/game/stream/game123',
    );
    expect(
      api.moveUri(gameId: 'game123', uci: 'e2e4').toString(),
      'https://lichess.org/api/board/game/game123/move/e2e4',
    );
    expect(api.authHeaders, {'Authorization': 'Bearer lichess-token'});
  });

  test('known pgn mutation endpoints use legacy field names', () async {
    final captured = <http.Request>[];
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        captured.add(request);
        return http.Response(
          jsonEncode({'ret': 1, 'code': 200, 'info': 'ok', 'data': {}}),
          200,
        );
      }),
    );

    await client.updatePgn(
      pgnId: 99,
      pgn: '1. d4 d5 *',
      whiteName: 'A',
      blackName: 'B',
      playTime: '1782899519',
      winId: 2,
      gameStatus: 3,
      gameStep: 20,
    );
    await client.deletePgn(pgnId: 99);
    await client.setCollectd(pgnId: 99);
    await client.deleteCollectd(pgnId: 99);

    expect(
      captured.map((request) => request.url.path).toList(),
      [
        '/api/updatePgn',
        '/api/delPgn',
        '/api/setCollectd',
        '/api/delCollectd',
      ],
    );
    expect(captured.first.bodyFields['pgn_id'], '99');
    expect(captured.first.bodyFields['white_name'], 'A');
    expect(captured.first.bodyFields['play_time'], '1782899519');
    expect(captured.first.bodyFields['game_step'], '20');
    expect(captured.first.bodyFields['player_color'], '');
    expect(captured.first.bodyFields['speed'], '');
    expect(captured.first.bodyFields['time_control'], '');
    expect(captured.first.bodyFields['opponent_name'], '');
    expect(captured[1].bodyFields['pgn_id'], '99');
  });

  test('pgn update parses server-granted daily task reward', () async {
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': {
              'daily_task_reward': {
                'balance': 220,
                'points_added': 20,
                'claimed_today': true,
              },
            },
          }),
          200,
        );
      }),
    );

    final result = await client.updatePgn(
      pgnId: 99,
      pgn: '1. d4 d5 1-0',
      whiteName: 'A',
      blackName: 'B',
      winId: 1,
      gameStatus: 2,
      gameStep: 2,
    );

    expect(result.isSuccess, isTrue);
    expect(result.data?.dailyTaskReward?.pointsAdded, 20);
    expect(result.data?.dailyTaskReward?.balance, 220);
  });

  test('pgn update accepts legacy empty response data', () async {
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'ret': 1, 'code': 200, 'info': 'ok', 'data': null}),
          200,
        );
      }),
    );

    final result = await client.updatePgn(
      pgnId: 99,
      pgn: '1. d4 d5 *',
      whiteName: 'A',
      blackName: 'B',
    );

    expect(result.isSuccess, isTrue);
    expect(result.data?.dailyTaskReward, isNull);
  });

  test('known lichess binding endpoints are available from legacy backend',
      () async {
    final captured = <http.Request>[];
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        captured.add(request);
        final path = request.url.path;
        final data = switch (path) {
          '/api/getLichessToken' => {
              'token': 'lichess-token',
              'lichess_name': 'LichessName',
            },
          '/api/bindLichess' => 'https://lichess.org/oauth',
          _ => {},
        };
        return http.Response(
          jsonEncode({'ret': 1, 'code': 200, 'info': 'ok', 'data': data}),
          200,
        );
      }),
    );

    final token = await client.getLichessToken();
    final bindUrl = await client.bindLichess();
    await client.freeUserBind('lichess');

    expect(token.data?.token, 'lichess-token');
    expect(token.data?.lichessName, 'LichessName');
    expect(bindUrl.data, 'https://lichess.org/oauth');
    expect(captured.map((request) => request.url.path).toList(), [
      '/api/getLichessToken',
      '/api/bindLichess',
      '/api/freeUserBind',
    ]);
    expect(captured[1].bodyFields.containsKey('reauthorize'), isFalse);
    expect(captured.last.bodyFields['bind_type'], 'lichess');
  });

  test('waitForLichessToken retries while callback is still saving', () async {
    var tokenChecks = 0;
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/getLichessToken') {
          tokenChecks += 1;
          if (tokenChecks < 3) {
            return http.Response(
              jsonEncode({
                'ret': 0,
                'code': 501,
                'info':
                    'Get OAuth code failed, please connect your lichess account',
                'data': null,
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'ret': 1,
              'code': 200,
              'info': 'ok',
              'data': {
                'token': 'lichess-token',
                'lichess_name': 'LichessName',
              },
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );

    final token = await client.waitForLichessToken(
      maxAttempts: 3,
      retryDelay: Duration.zero,
    );

    expect(tokenChecks, 3);
    expect(token.isSuccess, isTrue);
    expect(token.data?.token, 'lichess-token');
    expect(token.data?.lichessName, 'LichessName');
  });

  test('social bind and logout endpoints use legacy auth contracts', () async {
    final captured = <http.Request>[];
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        captured.add(request);
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': request.url.path == '/api/logout'
                ? null
                : {
                    'avatar_url': '',
                    'bind_apple': request.url.path == '/api/bindApple',
                    'bind_chess': false,
                    'bind_google': request.url.path == '/api/bindGoogle',
                    'bind_lichess': false,
                    'chess_name': '',
                    'email': 'player@example.com',
                    'lichess_name': '',
                    'no_password': true,
                    'region': 'US',
                    'user_id': 7,
                    'username': 'Player',
                  },
          }),
          200,
        );
      }),
    );

    await client.bindGoogle('google-id-token');
    await client.bindApple('apple-identity-token');
    final logout = await client.logout();

    expect(logout.isSuccess, isTrue);
    expect(client.session, isNull);
    expect(captured.map((request) => request.url.path).toList(), [
      '/api/bindGoogle',
      '/api/bindApple',
      '/api/logout',
    ]);
    for (final request in captured) {
      expect(request.bodyFields['user_id'], '7');
      expect(request.bodyFields['token'], '12345678901234567890123456789012');
    }
    expect(captured[0].bodyFields['id_token'], 'google-id-token');
    expect(captured[1].bodyFields['identity_token'], 'apple-identity-token');
  });

  test('static text and puzzle helpers reuse legacy hosts', () async {
    final captured = <Uri>[];
    final client = ChessnutApiClient(
      httpClient: MockClient((request) async {
        captured.add(request.url);
        final body = request.url.path == '/static/js/chess-helper.js'
            ? 'window.fen = function() {};'
            : jsonEncode({
                'id': 13,
                'fen': '8/8/8/8/8/8/4K3/4k3 w - - 0 1',
                'move': 'e2e1',
                'lichess_id': 'ijklmnop',
                'tags': 'fork',
              });
        return http.Response(body, 200);
      }),
    );

    final js = await client.chesscomJs();
    final randomPuzzle = await client.puzzleRandom();
    final puzzle = await client.puzzle(13);

    expect(js, contains('window.fen'));
    expect(randomPuzzle?.id, 13);
    expect(puzzle?.lichessId, 'ijklmnop');
    expect(captured.map((uri) => uri.toString()).toList(), [
      'https://api.chessnutech.com/static/js/chess-helper.js',
      'http://puzzle.chessnutech.com/random',
      'http://puzzle.chessnutech.com/get/13',
    ]);
  });

  test('Chessnut-owned service hosts can be configured for local testing',
      () async {
    final captured = <Uri>[];
    final client = ChessnutApiClient(
      baseUri: Uri.parse('http://127.0.0.1:8888'),
      puzzleBaseUri: Uri.parse('http://127.0.0.1:8890/puzzle'),
      moveUpdateUri: Uri.parse('http://127.0.0.1:8888/static/update.json'),
      httpClient: MockClient((request) async {
        captured.add(request.url);
        if (request.url.path.endsWith('update.json')) {
          return http.Response('{"version":"local"}', 200);
        }
        if (request.url.path.endsWith('chess-helper.js')) {
          return http.Response('window.__bridge = true;', 200);
        }
        return http.Response(
          jsonEncode({
            'id': 13,
            'fen': '8/8/8/8/8/8/4K3/4k3 w - - 0 1',
            'move': 'e2e1',
            'lichess_id': 'localpuz',
            'tags': 'local',
          }),
          200,
        );
      }),
    );

    await client.chesscomJs();
    await client.puzzleRandom();
    await client.puzzle(13);
    await client.moveVersion();

    expect(captured.map((uri) => uri.toString()).toList(), [
      'http://127.0.0.1:8888/static/js/chess-helper.js',
      'http://127.0.0.1:8890/puzzle/random',
      'http://127.0.0.1:8890/puzzle/get/13',
      'http://127.0.0.1:8888/static/update.json',
    ]);
  });

  test('loads and downloads a Move firmware release', () async {
    final captured = <Uri>[];
    final firmwareUri = Uri.parse('https://download.chessnut.test/move.tar.gz');
    final client = ChessnutApiClient(
      moveUpdateUri: Uri.parse('https://move.chessnut.test/update.json'),
      httpClient: MockClient((request) async {
        captured.add(request.url);
        if (request.url == firmwareUri) {
          return http.Response.bytes([1, 2, 3, 4], HttpStatus.ok);
        }
        return http.Response(
          jsonEncode({
            'version': 'ChessMove_1.0.34',
            'download': firmwareUri.toString(),
          }),
          HttpStatus.ok,
        );
      }),
    );

    final release = await client.moveFirmwareRelease();
    final firmware = await client.downloadMoveFirmware(release!.downloadUri);

    expect(release.version, 'ChessMove_1.0.34');
    expect(release.downloadUri, firmwareUri);
    expect(firmware, [1, 2, 3, 4]);
    expect(captured, [client.moveUpdateUri, firmwareUri]);
  });

  test('remaining legacy account and training endpoints keep old contracts',
      () async {
    final captured = <http.Request>[];
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        captured.add(request);
        final path = request.url.path;
        final data = switch (path) {
          '/api/Token/Refresh' => {
              'avatar_url': '',
              'bind_apple': false,
              'bind_chess': false,
              'bind_google': true,
              'bind_lichess': false,
              'chess_name': '',
              'email': 'player@example.com',
              'lichess_name': '',
              'no_password': false,
              'region': 'US',
              'token': 'new-token',
              'user_id': 7,
              'username': 'Player',
            },
          '/api/version' => {
              'change_log': 'Better boards',
              'download_url': 'https://download.chessnut.com/app',
              'platform': 2,
              'version': '3.0.0',
            },
          '/api/getRegisterImage' || '/api/getDeleteUserImage' => {
              'base64': 'image-base64',
              'captchaId': 'captcha-1',
            },
          '/api/train/list' ||
          '/api/train/official_shared_list' ||
          '/api/train/shared_list' =>
            [
              {
                'id': 11,
                'raw_file': 'rapid.pgn',
                'train_status': 2,
                'title': 'Rapid LC0',
                'remark': 'Training finished',
                'likes': 9,
                'model_path': 'https://cdn/model.pb.gz',
                'analyze_data': '{"TestCorrect":0.62}',
                'shared_name': 'Rapid',
                'shared': true,
                'analyze_pgn': ['1. e4 e5 *'],
              }
            ],
          '/api/train/subStatus' => {
              'expire_time': '2026-12-31',
              'expire_count': 99,
              'sub_status': 1,
            },
          '/api/getElo' => {'elo': 1520},
          '/api/get_openai_key' => 'openai-key',
          _ => {},
        };
        return http.Response(
          jsonEncode({'ret': 1, 'code': 200, 'info': 'ok', 'data': data}),
          200,
        );
      }),
    );

    final refreshed = await client.refreshToken(7, 'refresh-token');
    final version = await client.version(2);
    await client.updateInfo(username: 'New Player');
    final registerImage = await client.getRegisterImage();
    final deleteImage = await client.getDeleteUserImage();
    await client.deleteUser(code: '1234', captchaId: 'captcha-1');
    await client.sendResetPasswordEmail('player@example.com');
    await client.resetPassword(
      email: 'player@example.com',
      password: 'new-secret',
      code: 'reset-code',
    );
    await client.registerWithCaptcha(
      username: 'Player',
      password: 'secret',
      email: 'player@example.com',
      code: 'recaptcha-token',
      captchaId: 'recaptcha',
    );
    await client.registerWithTurnstile(
      username: 'Player V3',
      password: 'secret',
      email: 'player-v3@example.com',
      code: 'turnstile-token',
      avatarUrl: 'assets/avatars/avatar-03.png',
    );
    final trainList = await client.trainList();
    final official = await client.officialSharedList();
    final shared = await client.sharedList();
    final subStatus = await client.subStatus();
    await client.trainDel(11);
    await client.changePassword(
      oldPassword: 'old-secret',
      newPassword: 'new-secret',
    );
    final elo = await client.getElo();
    await client.updateElo(1600);
    final openaiKey = await client.getOpenaiKey();

    expect(refreshed.data?.token, 'new-token');
    expect(version.data?.version, '3.0.0');
    expect(registerImage.data?.captchaId, 'captcha-1');
    expect(deleteImage.data?.base64, 'image-base64');
    expect(trainList.data?.models.single.title, 'Rapid LC0');
    expect(official.data?.models.single.analyzePgn.single, '1. e4 e5 *');
    expect(shared.data?.models.single.shared, isTrue);
    expect(subStatus.data?.subStatus, 1);
    expect(elo.data?.elo, 1520);
    expect(openaiKey.data, 'openai-key');
    expect(captured.map((request) => request.url.path).toList(), [
      '/api/Token/Refresh',
      '/api/version',
      '/api/updateInfo',
      '/api/getRegisterImage',
      '/api/getDeleteUserImage',
      '/api/deleteUser',
      '/api/sendResetPasswordEmail',
      '/api/resetPassword',
      '/api/registerWithCaptcha',
      '/api/v3/registerWithTurnstile',
      '/api/train/list',
      '/api/train/official_shared_list',
      '/api/train/shared_list',
      '/api/train/subStatus',
      '/api/train/del',
      '/api/changePassword',
      '/api/getElo',
      '/api/updateElo',
      '/api/get_openai_key',
    ]);
    expect(captured[0].bodyFields['refresh_token'], 'refresh-token');
    expect(captured[2].bodyFields['username'], 'New Player');
    expect(captured[5].bodyFields['code'], '1234');
    expect(
      captured[7].bodyFields['password'],
      'fc97bb52861fcf328d0a7abe201f9632b8703e436656348f6d1b398'
      'f42e92c39',
    );
    expect(
      captured[8].bodyFields['password'],
      '2bb80d537b1da3e38bd30361aa855686bde0eacd7162fef6a25'
      'fe97bf527a25b',
    );
    expect(captured[8].bodyFields['captchaId'], 'recaptcha');
    expect(captured[9].bodyFields['code'], 'turnstile-token');
    expect(
        captured[9].bodyFields['avatar_url'], 'assets/avatars/avatar-03.png');
    expect(captured[9].bodyFields.containsKey('captchaId'), isFalse);
    expect(captured[14].bodyFields['train_id'], '11');
    expect(
      captured[15].bodyFields['old_password'],
      '5d865deae06fbd34fe9ce848f3e5fc4368f2f612b18aef47f29f21'
      '64563a0140',
    );
    expect(
      captured[15].bodyFields['password'],
      'fc97bb52861fcf328d0a7abe201f9632b8703e436656348f6d1b398'
      'f42e92c39',
    );
    expect(captured[17].bodyFields['elo'], '1600');
  });

  test('settleCareerElo sends the result and parses account Elo', () async {
    late http.Request captured;
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 42,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': {
              'elo': 1475,
              'previous_elo': 1425,
              'delta': 50,
            },
          }),
          200,
        );
      }),
    );

    final result = await client.settleCareerElo('victory');

    expect(captured.url.path, '/api/updateElo');
    expect(captured.bodyFields['career_result'], 'victory');
    expect(captured.bodyFields.containsKey('elo'), isFalse);
    expect(result.data?.previousElo, 1425);
    expect(result.data?.elo, 1475);
    expect(result.data?.delta, 50);
  });

  test('openai key parser accepts realtime client secret objects', () async {
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(userId: 7, token: 'token'),
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': {
              'client_secret': {'value': 'ek-realtime-secret'},
            },
          }),
          200,
        );
      }),
    );

    final result = await client.getOpenaiKey();

    expect(result.isSuccess, isTrue);
    expect(result.data, 'ek-realtime-secret');
  });

  test('version check sends current app version and parses update policy',
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
              'version': '0.1.5',
              'platform': 12,
              'download_url': 'https://download.chessnut.com/android',
              'change_log': 'New update flow',
              'update_available': true,
              'force_update': true,
              'update_method': 'store',
              'current_version': '0.1.4',
            },
          }),
          200,
        );
      }),
    );

    final result = await client.version(
      12,
      currentVersion: '0.1.4',
      buildNumber: '6',
      platformName: 'android',
    );

    expect(captured.url.path, '/api/version');
    expect(captured.bodyFields['platform'], '12');
    expect(captured.bodyFields['current_version'], '0.1.4');
    expect(captured.bodyFields['build_number'], '6');
    expect(captured.bodyFields['platform_name'], 'android');
    expect(result.data?.updateAvailable, isTrue);
    expect(result.data?.forceUpdate, isTrue);
    expect(result.data?.updateMethod, 'store');
    expect(result.data?.currentVersion, '0.1.4');
  });

  test('v3 profile update preserves auth when profile response omits tokens',
      () async {
    late http.Request captured;
    final client = ChessnutApiClient(
      session: const ChessnutLoginSession(
        userId: 7,
        token: '12345678901234567890123456789012',
        refreshToken: 'refresh-token',
        avatarUrl: 'assets/avatars/avatar-01.png',
        bindApple: false,
        bindChess: false,
        bindGoogle: false,
        bindLichess: false,
        chessName: '',
        email: 'player@example.com',
        lichessName: '',
        noPassword: false,
        phone: '',
        region: 'US',
        username: 'Old Player',
      ),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': {
              'avatar_url': 'assets/avatars/avatar-12.png',
              'bind_apple': false,
              'bind_chess': false,
              'bind_google': false,
              'bind_lichess': false,
              'chess_name': '',
              'email': 'player@example.com',
              'lichess_name': '',
              'no_password': false,
              'region': 'US',
              'user_id': 7,
              'username': 'New Player',
            },
          }),
          200,
        );
      }),
    );

    final result = await client.updateProfile(
      username: 'New Player',
      avatarUrl: 'assets/avatars/avatar-12.png',
    );

    expect(result.isSuccess, isTrue);
    expect(captured.url.path, '/api/v3/updateProfile');
    expect(captured.bodyFields['user_id'], '7');
    expect(captured.bodyFields['token'], '12345678901234567890123456789012');
    expect(captured.bodyFields['username'], 'New Player');
    expect(captured.bodyFields['avatar_url'], 'assets/avatars/avatar-12.png');
    expect(result.data?.username, 'New Player');
    expect(result.data?.avatarUrl, 'assets/avatars/avatar-12.png');
    expect(result.data?.token, '12345678901234567890123456789012');
    expect(result.data?.refreshToken, 'refresh-token');
    expect(client.session, same(result.data));
  });

  test('v3 profile update uses submitted name when response omits profile data',
      () async {
    final client = ChessnutApiClient(
      session: const ChessnutLoginSession(
        userId: 7,
        token: '12345678901234567890123456789012',
        refreshToken: 'refresh-token',
        avatarUrl: 'assets/avatars/avatar-01.png',
        bindApple: false,
        bindChess: true,
        bindGoogle: true,
        bindLichess: false,
        chessName: 'ChessComName',
        email: 'player@example.com',
        lichessName: '',
        noPassword: false,
        phone: '',
        region: 'US',
        username: 'Old Player',
      ),
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': null,
          }),
          200,
        );
      }),
    );

    final result = await client.updateProfile(
      username: 'New Player',
      avatarUrl: 'assets/avatars/avatar-12.png',
    );

    expect(result.isSuccess, isTrue);
    expect(result.data?.username, 'New Player');
    expect(result.data?.avatarUrl, 'assets/avatars/avatar-12.png');
    expect(result.data?.token, '12345678901234567890123456789012');
    expect(result.data?.refreshToken, 'refresh-token');
    expect(result.data?.email, 'player@example.com');
    expect(result.data?.bindChess, isTrue);
    expect(result.data?.bindGoogle, isTrue);
    expect(result.data?.chessName, 'ChessComName');
    expect(client.session, same(result.data));
  });

  test('profile update falls back to legacy avatar upload when v3 is missing',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final captured = <http.BaseRequest>[];
    final client = ChessnutApiClient(
      session: const ChessnutLoginSession(
        userId: 7,
        token: '12345678901234567890123456789012',
        refreshToken: 'refresh-token',
        avatarUrl: 'assets/avatars/avatar-01.png',
        bindApple: false,
        bindChess: false,
        bindGoogle: false,
        bindLichess: false,
        chessName: '',
        email: 'player@example.com',
        lichessName: '',
        noPassword: false,
        phone: '',
        region: 'US',
        username: 'Old Player',
      ),
      httpClient: MockClient.streaming((request, bodyStream) async {
        captured.add(request);
        if (request.url.path == '/api/v3/updateProfile') {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
              'ret': 0,
              'code': 404,
              'info': 'Page not found',
              'data': null,
            }))),
            404,
          );
        }
        if (request.url.path == '/api/updateInfo') {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
              'ret': 1,
              'code': 200,
              'info': 'ok',
              'data': {
                'avatar_url': '/static/7/avatar-02.png',
                'bind_apple': false,
                'bind_chess': false,
                'bind_google': false,
                'bind_lichess': false,
                'chess_name': '',
                'email': 'player@example.com',
                'lichess_name': '',
                'no_password': false,
                'region': 'US',
                'user_id': 7,
                'username': 'Knight Rider',
              },
            }))),
            200,
          );
        }
        return http.StreamedResponse(
            Stream.value(utf8.encode('not found')), 404);
      }),
    );

    final result = await client.updateProfile(
      username: 'Knight Rider',
      avatarUrl: 'assets/avatars/avatar-02.png',
    );

    expect(result.isSuccess, isTrue);
    expect(captured.map((request) => request.url.path).toList(), [
      '/api/v3/updateProfile',
      '/api/updateInfo',
    ]);
    final legacyRequest = captured[1] as http.MultipartRequest;
    expect(legacyRequest.fields['username'], 'Knight Rider');
    expect(legacyRequest.fields['user_id'], '7');
    expect(
      legacyRequest.fields['token'],
      '12345678901234567890123456789012',
    );
    expect(legacyRequest.files.single.field, 'avatar_img');
    expect(legacyRequest.files.single.filename, 'avatar-02.png');
    expect(result.data?.username, 'Knight Rider');
    expect(result.data?.avatarUrl, '/static/7/avatar-02.png');
    expect(result.data?.token, '12345678901234567890123456789012');
    expect(result.data?.refreshToken, 'refresh-token');
  });

  test('legacy training model payloads decode backend base64 fields', () async {
    final analyzeData = jsonEncode({'TestCorrect': 0.75});
    const analyzePgn = '[Event "Sample"]\n1. e4 e5 *';
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': [
              {
                'id': 11,
                'raw_file': 'rapid.pgn',
                'train_status': 2,
                'title': 'Rapid LC0',
                'remark': 'Training finished',
                'likes': 9,
                'model_path': 'https://cdn/model.pb.gz',
                'analyze_data': base64Encode(utf8.encode(analyzeData)),
                'shared_name': 'Rapid',
                'shared': true,
                'analyze_pgn': [base64Encode(utf8.encode(analyzePgn))],
              }
            ],
          }),
          200,
        );
      }),
    );

    final result = await client.trainList();

    expect(result.data?.models.single.analyzeData, analyzeData);
    expect(result.data?.models.single.analyzePgn.single, analyzePgn);
  });

  test('missing legacy training endpoints use backend form contracts',
      () async {
    final captured = <http.Request>[];
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        captured.add(request);
        final data = switch (request.url.path) {
          '/api/train/status' => true,
          '/api/train/push' || '/api/train/get' => {
              'id': 11,
              'raw_file': 'rapid.pgn',
              'train_status': 2,
              'title': 'Rapid LC0',
              'remark': 'Training finished',
              'likes': 9,
              'model_path': 'https://cdn/model.pb.gz',
              'analyze_data':
                  base64Encode(utf8.encode(jsonEncode({'TestCorrect': 0.7}))),
              'shared_name': 'Rapid',
              'shared': true,
              'analyze_pgn': [],
            },
          '/api/train/next_move' => '{"uci":"e2e4"}',
          '/api/v3/modelBuild/status' => true,
          '/api/v3/modelBuild/push' => {
              'id': 12,
              'raw_file': 'model_build.pgn',
              'train_status': 0,
              'title': 'Model Build',
              'remark': 'Queued from Engine Lab',
              'likes': 0,
              'model_path': '',
              'analyze_data': '',
              'shared_name': '',
              'shared': false,
              'analyze_pgn': [],
            },
          '/api/v3/modelBuild/previewLichess' => {
              'usable_count': 53,
              'pgn': '[Event "Lichess import"]\n[White "storm123"]\n1. e4 e5 *',
              'source_label': 'Lichess storm123',
            },
          '/api/v3/modelBuild/pushLichess' => true,
          _ => {},
        };
        return http.Response(
          jsonEncode({'ret': 1, 'code': 200, 'info': 'ok', 'data': data}),
          200,
        );
      }),
    );

    final status = await client.trainStatus();
    final pushed = await client.trainPush(
      pgn: '[Event "Chessnut"]\n1. e4 e5 *',
      title: 'Rapid LC0',
      remark: 'Training finished',
    );
    await client.trainEdit(id: 11, title: 'Edited', remark: 'Updated');
    final train = await client.trainGet(11);
    await client.applySharedTrain(
      trainId: 11,
      title: 'Shared',
      remark: 'Public model',
      sharedName: 'Coach Set',
    );
    await client.starTrain(11);
    await client.unstarTrain(11);
    final nextMove = await client.nextMove('{"fen":"startpos","moves":[]}');
    final modelBuildStatus = await client.modelBuildStatus();
    final modelBuild = await client.modelBuildPush(
      pgn: '[Event "Chessnut"]\n1. d4 d5 *',
      title: 'Model Build',
      remark: 'Queued from Engine Lab',
    );
    final lichessPreview =
        await client.previewModelBuildFromLichess(playerId: 'storm123');
    final lichessBuild = await client.pushModelBuildFromLichess(
      playerId: 'storm123',
      title: 'Lichess Style',
      remark: 'Queued from Lichess player id',
    );

    expect(status.data, isTrue);
    expect(pushed.data?.id, 11);
    expect(train.data?.analyzeData, '{"TestCorrect":0.7}');
    expect(nextMove.data, '{"uci":"e2e4"}');
    expect(modelBuildStatus.data, isTrue);
    expect(modelBuild.data?.id, 12);
    expect(lichessPreview.data?.gameCount, 53);
    expect(lichessPreview.data?.sourceLabel, 'Lichess storm123');
    expect(lichessPreview.data?.pgn, contains('[White "storm123"]'));
    expect(lichessBuild.data, isTrue);
    expect(captured.map((request) => request.url.path).toList(), [
      '/api/train/status',
      '/api/train/push',
      '/api/train/edit',
      '/api/train/get',
      '/api/train/do_shared',
      '/api/train/star',
      '/api/train/unstar',
      '/api/train/next_move',
      '/api/v3/modelBuild/status',
      '/api/v3/modelBuild/push',
      '/api/v3/modelBuild/previewLichess',
      '/api/v3/modelBuild/pushLichess',
    ]);
    expect(captured[1].bodyFields['pgn'], contains('1. e4 e5'));
    expect(captured[2].bodyFields['id'], '11');
    expect(captured[3].bodyFields['id'], '11');
    expect(captured[4].bodyFields['train_id'], '11');
    expect(captured[4].bodyFields['shared_name'], 'Coach Set');
    expect(captured[5].bodyFields['train_id'], '11');
    expect(captured[7].bodyFields['json'], '{"fen":"startpos","moves":[]}');
    expect(captured[9].bodyFields['pgn'], contains('1. d4 d5'));
    expect(captured[10].bodyFields['player_id'], 'storm123');
    expect(captured[11].bodyFields['player_id'], 'storm123');
    expect(captured[11].bodyFields['title'], 'Lichess Style');
    expect(captured[11].bodyFields['remark'], 'Queued from Lichess player id');
  });

  test('Model Build Lichess preview parses game arrays', () {
    final preview = ModelBuildPreview.fromJson({
      'player_id': 'storm123',
      'games': [
        {
          'pgn': '[Event "Lichess Rated Rapid"]\n'
              '[White "storm123"]\n'
              '[Black "rapidOpponent"]\n\n'
              '1. e4 e5 *',
        },
        {
          'pgn': '[Event "Lichess Rated Blitz"]\n'
              '[White "blitzOpponent"]\n'
              '[Black "storm123"]\n\n'
              '1. d4 d5 *',
        },
      ],
    });

    expect(preview.gameCount, 2);
    expect(preview.sourceLabel, 'storm123');
    expect(preview.pgn, contains('[White "storm123"]'));
    expect(preview.pgn, contains('[Black "storm123"]'));
  });

  test('puzzle info parses Lichess theme metadata', () async {
    final client = ChessnutApiClient(
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'total': 4000000,
            'tags': [
              {
                'id': 3,
                'key': 'fork',
                'name': 'Fork',
                'desc': 'Attack two pieces',
                'total': 184000,
              }
            ],
          }),
          200,
        );
      }),
    );

    final info = await client.puzzleInfo();

    expect(info?.total, 4000000);
    expect(info?.tags.single.key, 'fork');
    expect(info?.tags.single.total, 184000);
  });

  test('new wallet membership and Grandeur contracts use authorized requests',
      () async {
    final captured = <http.Request>[];
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        captured.add(request);
        final data = switch (request.url.path) {
          '/api/wallet/balance' => {
              'balance': 1240,
              'claimed_today': true,
              'last_claimed_at': '2026-05-17T00:05:00+08:00',
              'member_active': false,
              'member_expire_at': '',
            },
          '/api/wallet/claimDaily' => {
              'balance': 1340,
              'points_added': 100,
              'claimed_today': true,
            },
          '/api/wallet/claimTask' => {
              'balance': 1260,
              'points_added': 20,
              'claimed_today': true,
            },
          '/api/wallet/ledger' => {
              'items': [
                {
                  'id': 'l1',
                  'title': 'Daily check-in',
                  'amount': 100,
                  'created_at': '2026-05-17T00:05:00+08:00',
                  'type': 'daily',
                }
              ],
            },
          '/api/wallet/consumePoints' => {
              'balance': 740,
              'points_consumed': 500,
              'member_unlimited': false,
            },
          '/api/wallet/debugAdjust' => {
              'balance': 840,
              'points_added': 100,
              'claimed_today': true,
            },
          '/api/membership/products' => {
              'products': [
                {
                  'id': 'premium_monthly_auto',
                  'title': 'Premium Monthly',
                  'price': '19.99',
                  'price_cents': 1999,
                  'currency': 'USD',
                  'period': 'month',
                  'renewing': true,
                  'duration_months': 1,
                  'platform_product_id': 'chessnut_premium_monthly_auto',
                  'recommended': true,
                },
                {
                  'id': 'premium_yearly_auto',
                  'title': 'Premium Yearly',
                  'price': '99.99',
                  'price_cents': 9999,
                  'currency': 'USD',
                  'period': 'year',
                  'renewing': true,
                  'duration_months': 12,
                  'platform_product_id': 'chessnut_premium_yearly_auto',
                  'recommended': true,
                },
                {
                  'id': 'premium_monthly_non_auto',
                  'title': 'Premium Monthly One-Time',
                  'price': '29.99',
                  'price_cents': 2999,
                  'currency': 'USD',
                  'period': 'month',
                  'renewing': false,
                  'duration_months': 1,
                  'platform_product_id': 'chessnut_premium_monthly_non_auto',
                  'recommended': false,
                },
              ],
            },
          '/api/membership/purchaseReceiptVerify' => {
              'active': true,
              'expire_at': '2027-05-17T00:00:00Z',
            },
          '/api/grandeur/analyzeGame' => {
              'analysis_id': 'g-1',
              'moves': [
                {
                  'ply': 1,
                  'san': 'e4',
                  'tag': 'c',
                  'purpose': 'Claim the center',
                  'why': 'It opens lines and creates central space.',
                  'better_move': '',
                  'classification': 'Best',
                },
                {
                  'ply': 2,
                  'san': 'e5',
                  'tag': 'd',
                  'commentary': 'A sound developing response.',
                },
              ],
            },
          '/api/grandeur/explainMove' => {
              'ply': 1,
              'san': 'e4',
              'purpose': 'Claim the center',
              'why': 'It opens lines and creates central space.',
              'better_move': '',
              'classification': 'Best',
            },
          '/api/grandeur/voiceProfiles' => {
              'profiles': [
                {
                  'id': 'classic',
                  'name': 'Grandeur Classic',
                  'voice': 'calm',
                  'style': 'professional',
                }
              ],
            },
          '/api/grandeur/analysisHistory' => {
              'items': [
                {
                  'analysis_id': 'g-1',
                  'title': 'Rapid game',
                  'created_at': '2026-05-17T00:00:00Z',
                }
              ],
            },
          _ => {},
        };
        return http.Response(
          jsonEncode({'ret': 1, 'code': 200, 'info': 'ok', 'data': data}),
          200,
        );
      }),
    );

    final balance = await client.walletBalance();
    final claim = await client.claimDailyPoints();
    final taskClaim = await client.claimDailyTask(
      taskKey: 'puzzle',
      points: 20,
    );
    final ledger = await client.walletLedger();
    final consume = await client.consumePoints(
      reason: WalletConsumeReason.engineModelBuild,
      referenceId: 'train-1',
    );
    final debugAdjust = await client.debugAdjustWalletPoints(amount: 100);
    final products = await client.membershipProducts();
    final verified = await client.verifyMembershipPurchase(
      platform: 'ios',
      productId: 'chessnut_premium_yearly_auto',
      receipt: 'receipt-data',
      transactionId: '100000000000001',
    );
    final grandeur = await client.analyzeGrandeurGame(
      pgn: '[Event "Chessnut"]\n1. e4 *',
      coachProfileId: 'classic',
      language: 'en',
    );
    final move = await client.explainGrandeurMove(
      analysisId: 'g-1',
      ply: 1,
    );
    final voices = await client.grandeurVoiceProfiles();
    final history = await client.grandeurAnalysisHistory();

    expect(balance.data?.balance, 1240);
    expect(balance.data?.claimedToday, isTrue);
    expect(claim.data?.pointsAdded, 100);
    expect(taskClaim.data?.pointsAdded, 20);
    expect(ledger.data?.items.single.amount, 100);
    expect(consume.data?.pointsConsumed, 500);
    expect(debugAdjust.data?.balance, 840);
    expect(
      products.data?.products.map((p) => p.price).toList(),
      ['19.99', '99.99', '29.99'],
    );
    expect(products.data?.products.first.renewing, isTrue);
    expect(products.data?.products.last.renewing, isFalse);
    expect(products.data?.products.first.recommended, isTrue);
    expect(verified.data?.active, isTrue);
    expect(grandeur.data?.analysisId, 'g-1');
    expect(grandeur.data?.moves.first.purpose, 'Claim the center');
    expect(grandeur.data?.moves.first.tag, 'c');
    expect(grandeur.data?.moves.first.classification, 'Best');
    expect(grandeur.data?.moves.last.tag, 'd');
    expect(grandeur.data?.moves.last.classification, isEmpty);
    expect(move.data?.classification, 'Best');
    expect(voices.data?.profiles.single.id, 'classic');
    expect(history.data?.items.single.analysisId, 'g-1');
    expect(captured.map((request) => request.url.path).toList(), [
      '/api/wallet/balance',
      '/api/wallet/claimDaily',
      '/api/wallet/claimTask',
      '/api/wallet/ledger',
      '/api/wallet/consumePoints',
      '/api/wallet/debugAdjust',
      '/api/membership/products',
      '/api/membership/purchaseReceiptVerify',
      '/api/grandeur/analyzeGame',
      '/api/grandeur/explainMove',
      '/api/grandeur/voiceProfiles',
      '/api/grandeur/analysisHistory',
    ]);
    expect(captured.first.bodyFields['user_id'], '7');
    expect(captured[2].bodyFields['task_key'], 'puzzle');
    expect(captured[2].bodyFields['points'], '20');
    expect(captured[4].bodyFields['reason'], 'engine_model_build');
    expect(captured[5].bodyFields['amount'], '100');
    expect(captured[7].bodyFields['platform'], 'ios');
    expect(captured[7].bodyFields['transaction_id'], '100000000000001');
    expect(captured[8].bodyFields['coach_profile_id'], 'classic');
    expect(captured[9].bodyFields['analysis_id'], 'g-1');
    expect(captured[9].bodyFields['ply'], '1');
  });

  test('wallet HTTP 404 reports missing wallet service deployment', () async {
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/wallet/balance');
        return http.Response(
          jsonEncode({
            'ret': 0,
            'code': 404,
            'info': 'Page not found',
            'data': null,
          }),
          404,
        );
      }),
    );

    final result = await client.walletBalance();

    expect(result.isSuccess, isFalse);
    expect(result.status.errorMessage, walletServiceUnavailableMessage);
  });

  test(
      'wallet API 404 page-not-found reports missing wallet service deployment',
      () async {
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: 'short-token-from-old-auth',
      ),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/wallet/balance');
        return http.Response(
          jsonEncode({
            'ret': 0,
            'code': 404,
            'info': 'Page not found',
            'data': null,
          }),
          200,
        );
      }),
    );

    final result = await client.walletBalance();

    expect(result.isSuccess, isFalse);
    expect(result.status.apiErrorCode, 404);
    expect(result.status.errorMessage, walletServiceUnavailableMessage);
  });

  test('Maia3 bot move uses v3 cloud proxy endpoint', () async {
    late http.Request captured;
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': {
              'move': 'e7e5',
              'san': 'e5',
              'probability': 0.28,
              'model': 'maia3-5m',
              'elo': 1500,
              'candidates': [
                {
                  'move': 'e7e5',
                  'san': 'e5',
                  'probability': 0.28,
                  'wdl': [350, 340, 310],
                  'centipawns': 12,
                }
              ],
            },
          }),
          200,
        );
      }),
    );

    final result = await client.maia3BotMove(
      fen: 'start fen',
      moves: const ['e2e4'],
      elo: 1500,
    );

    expect(captured.url.path, '/api/v3/maia3/botMove');
    expect(captured.bodyFields['fen'], 'start fen');
    expect(captured.bodyFields['moves'], 'e2e4');
    expect(captured.bodyFields['elo'], '1500');
    expect(result.isSuccess, isTrue);
    expect(result.data?.move, 'e7e5');
    expect(result.data?.candidates.single.wdl, [350, 340, 310]);
  });

  test('Maia3 human review status parses report payload', () async {
    late http.Request captured;
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'ret': 1,
            'code': 200,
            'info': 'ok',
            'data': {
              'job_id': 'mhr_test',
              'pgn_id': 42,
              'status': 'completed',
              'stage': 'completed',
              'reused': true,
              'model': 'maia3-5m',
              'elo': 1500,
              'multipv': 5,
              'total_ply': 2,
              'analyzed_ply': 2,
              'progress_percent': 100,
              'error_message': '',
              'report': {
                'version': 1,
                'source': 'maia3_microservice',
                'model': 'maia3-5m',
                'elo': 1500,
                'generated_at': '2026-06-11T00:00:00Z',
                'summary': {
                  'human_match_percent': 72.5,
                  'most_human_side': 'white',
                  'sharpest_moments': [2],
                  'notes': ['White stayed close to common human choices.'],
                },
                'moves': [
                  {
                    'ply': 1,
                    'move': 'e4',
                    'move_uci': 'e2e4',
                    'fen': 'fen after e4',
                    'last_move': ['e2', 'e4'],
                    'played_probability': 0.34,
                    'typicality': 'common',
                    'human_label': 'Common human choice',
                    'candidates': [
                      {'move': 'e2e4', 'san': 'e4', 'probability': 0.34}
                    ],
                  }
                ],
              },
            },
          }),
          200,
        );
      }),
    );

    final result = await client.maia3HumanReviewStatus('mhr_test');

    expect(captured.url.path, '/api/v3/analysis/maia3/status');
    expect(captured.bodyFields['job_id'], 'mhr_test');
    expect(result.isSuccess, isTrue);
    expect(result.data?.isDone, isTrue);
    expect(result.data?.report?.summary.humanMatchPercent, 72.5);
    expect(result.data?.report?.moves.single.humanLabel, 'Common human choice');
  });
}

Map<String, Object?> _loginSessionJson({required String token}) => {
      'avatar_url': '',
      'bind_apple': false,
      'bind_chess': false,
      'bind_google': false,
      'bind_lichess': false,
      'chess_name': '',
      'email': 'player@example.com',
      'lichess_name': '',
      'no_password': false,
      'phone': '',
      'region': '',
      'token': token,
      'user_id': 7,
      'username': 'Player',
    };
