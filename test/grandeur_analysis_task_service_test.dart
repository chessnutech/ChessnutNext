import 'dart:convert';

import 'package:chessnut_flutter_export/services/app_preferences_store.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/services/grandeur_analysis_task_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Grandeur task polls backend, downloads report, and writes cache',
      () async {
    const pgn = '[White "Grandeur White"]\n'
        '[Black "Grandeur Black"]\n'
        '[Result "1-0"]\n\n'
        '1. e4 e5 1-0';
    final requests = <http.Request>[];
    var getCalls = 0;
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(userId: 7, token: 'token'),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST' &&
            request.url.path == '/api/v3/grandeur/get') {
          getCalls++;
          return _grandeurJobResponse(
            trainStatus: getCalls == 1 ? 0 : 2,
            commentFile: getCalls == 1
                ? ''
                : 'https://api.chessnutech.com/comment/ready.json',
          );
        }
        if (request.method == 'GET' &&
            request.url.toString() ==
                'https://api.chessnutech.com/comment/ready.json') {
          return http.Response(
            jsonEncode({
              'analysis_id': 'g-ready',
              'language': 'de',
              'summary': 'Backend Grandeur summary is ready.',
              'moves': [
                {
                  'ply': 1,
                  'san': 'e4',
                  'why': 'The backend explains the center.',
                  'classification': 'Best',
                },
              ],
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );
    final store = AppPreferencesAnalysisReportCacheStore(
      MemoryAppPreferencesStore(),
    );
    var cacheChanged = 0;
    final coordinator = GrandeurAnalysisTaskCoordinator();

    final first = coordinator.startOrAttach(
      cacheKey: 'pgnhash:grandeur-background',
      pgn: pgn,
      apiClient: client,
      initialJob: const GrandeurReviewJob(
        commentId: 91,
        trainStatus: 0,
        commentFile: '',
        pointsConsumed: 100,
        alreadyUnlocked: false,
        memberUnlimited: false,
        pgnId: 777,
        shareId: 'share-777',
      ),
      styleId: 'friendly',
      cacheStore: store,
      onReportCacheChanged: () => cacheChanged++,
      pollInterval: Duration.zero,
    );
    final second = coordinator.startOrAttach(
      cacheKey: 'pgnhash:grandeur-background',
      pgn: pgn,
      apiClient: client,
      initialJob: const GrandeurReviewJob(
        commentId: 91,
        trainStatus: 0,
        commentFile: '',
        pointsConsumed: 0,
        alreadyUnlocked: true,
        memberUnlimited: false,
        pgnId: 777,
        shareId: 'share-777',
      ),
      styleId: 'friendly',
      cacheStore: store,
      onReportCacheChanged: () => cacheChanged++,
      pollInterval: Duration.zero,
    );

    expect(identical(first, second), isTrue);

    final snapshot = await second.done;

    expect(snapshot.state, GrandeurAnalysisTaskState.completed);
    expect(snapshot.progress, 1);
    expect(snapshot.report?.language, 'fr');
    expect(
      snapshot.report?.summary,
      ['Backend Grandeur summary is ready.'],
    );
    expect(cacheChanged, 1);
    expect(
      (await store.read('pgnhash:grandeur-background'))
          ?.grandeurReport
          ?.moves
          .single
          .why,
      'The backend explains the center.',
    );
    expect(
      (await store.read('pgnhash:grandeur-background'))?.grandeurStyleId,
      'friendly',
    );
    expect(
      requests.where((request) => request.url.path == '/api/v3/grandeur/get'),
      hasLength(2),
    );
  });

  test('Grandeur task resolves backend relative report paths', () async {
    const pgn = '[White "Grandeur White"]\n'
        '[Black "Grandeur Black"]\n'
        '[Result "1-0"]\n\n'
        '1. e4 e5 1-0';
    final requests = <http.Request>[];
    final client = ChessnutApiClient(
      baseUri: Uri.parse('http://127.0.0.1:8888/'),
      session: const ChessnutApiSession(userId: 7, token: 'token'),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST' &&
            request.url.path == '/api/v3/grandeur/get') {
          return _grandeurJobResponse(
            trainStatus: 2,
            commentFile: '/static/grandeur_reports/7/ready.json',
          );
        }
        if (request.method == 'GET' &&
            request.url.toString() ==
                'http://127.0.0.1:8888/static/grandeur_reports/7/ready.json') {
          return http.Response(
            jsonEncode({
              'analysis_id': 'g-relative',
              'summary': 'Relative backend report is ready.',
              'moves': [
                {
                  'ply': 1,
                  'san': 'e4',
                  'why': 'The backend report came from a local static path.',
                  'classification': 'Good',
                },
              ],
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      }),
    );
    final coordinator = GrandeurAnalysisTaskCoordinator();

    final task = coordinator.startOrAttach(
      cacheKey: 'pgnhash:grandeur-relative',
      pgn: pgn,
      apiClient: client,
      initialJob: const GrandeurReviewJob(
        commentId: 92,
        trainStatus: 0,
        commentFile: '',
        pointsConsumed: 100,
        alreadyUnlocked: false,
        memberUnlimited: false,
        pgnId: 778,
        shareId: 'share-778',
      ),
      styleId: 'deep',
      cacheStore: null,
      onReportCacheChanged: null,
      pollInterval: Duration.zero,
    );

    final snapshot = await task.done;

    expect(snapshot.state, GrandeurAnalysisTaskState.completed);
    expect(snapshot.report?.analysisId, 'g-relative');
    expect(
      requests.map((request) => request.url.toString()),
      contains('http://127.0.0.1:8888/static/grandeur_reports/7/ready.json'),
    );
  });
}

http.Response _grandeurJobResponse({
  required int trainStatus,
  required String commentFile,
}) {
  return http.Response(
    jsonEncode({
      'ret': 1,
      'code': 200,
      'info': 'ok',
      'data': {
        'comment_id': 91,
        'train_status': trainStatus,
        'comment_file': commentFile,
        'points_consumed': 0,
        'already_unlocked': true,
        'member_unlimited': false,
        'pgn_id': 777,
        'share_id': 'share-777',
        'lang': 'fr',
      },
    }),
    200,
  );
}
