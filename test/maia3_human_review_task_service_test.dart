import 'dart:convert';

import 'package:chessnut_flutter_export/services/app_preferences_store.dart';
import 'package:chessnut_flutter_export/services/analysis_report_cache_service.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/services/maia3_human_review_task_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Maia3 cache namespace changes when report schema changes', () {
    expect(maia3HumanReviewCacheKey('pgnhash:test'),
        isNot(equals('pgnhash:test')));
    expect(
      maia3HumanReviewCacheKey('pgnhash:test'),
      equals(maia3HumanReviewCacheKey('pgnhash:test')),
    );
  });

  test('Maia3 cache namespace separates reports by Elo and model', () {
    final base = maia3HumanReviewCacheKey('pgnhash:test');

    expect(
      maia3HumanReviewSettingsCacheKey(base, elo: 1500),
      isNot(equals(maia3HumanReviewSettingsCacheKey(base, elo: 1800))),
    );
    expect(
      maia3HumanReviewSettingsCacheKey(base, elo: 1500),
      isNot(equals(maia3HumanReviewSettingsCacheKey(
        base,
        elo: 1500,
        model: 'maia3-79m',
      ))),
    );
    expect(
      maia3HumanReviewSettingsCacheKey(base, elo: 1500),
      equals(maia3HumanReviewSettingsCacheKey(base, elo: 1500)),
    );
  });

  test('Maia3 review retries backend with force after a failed reused job',
      () async {
    final requests = <http.Request>[];
    var startCalls = 0;
    final client = ChessnutApiClient(
      session: const ChessnutApiSession(
        userId: 7,
        token: '12345678901234567890123456789012',
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST' &&
            request.url.path == '/api/v3/analysis/maia3/start') {
          startCalls++;
          if (startCalls == 1) {
            return _jobResponse(
              status: 'failed',
              stage: 'failed',
              errorMessage: 'Maia3 is temporarily unavailable.',
            );
          }
          return _jobResponse(
            status: 'completed',
            stage: 'completed',
            report: _reportPayload(),
          );
        }
        return http.Response('not found', 404);
      }),
    );

    final task = Maia3HumanReviewTask(
      cacheKey: 'pgnhash:maia3-retry',
      pgn: '[White "A"]\n[Black "B"]\n[Result "*"]\n\n1. e4 *',
      pgnId: 42,
      apiClient: client,
      cacheStore:
          AppPreferencesAnalysisReportCacheStore(MemoryAppPreferencesStore()),
      onReportCacheChanged: null,
      pollInterval: Duration.zero,
    );

    final snapshot = await task.done;

    expect(snapshot.state, Maia3HumanReviewTaskState.completed);
    expect(snapshot.report?.moves.single.move, 'e4');
    expect(
      requests
          .where(
              (request) => request.url.path == '/api/v3/analysis/maia3/start')
          .map((request) => request.bodyFields['force'] ?? ''),
      ['', '1'],
    );
  });

  test('Maia3 review surfaces unexpected client errors to users', () async {
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
            'data': 'unexpected',
          }),
          200,
        );
      }),
    );

    final task = Maia3HumanReviewTask(
      cacheKey: 'pgnhash:maia3-client-error',
      pgn: '[White "A"]\n[Black "B"]\n[Result "*"]\n\n1. e4 *',
      pgnId: 42,
      apiClient: client,
      cacheStore: null,
      onReportCacheChanged: null,
      pollInterval: Duration.zero,
    );

    final snapshot = await task.done;

    expect(snapshot.state, Maia3HumanReviewTaskState.failed);
    expect(snapshot.status, contains('Maia3 Human Review could not start'));
    expect(snapshot.status, isNot(contains('unavailable')));
  });
}

http.Response _jobResponse({
  required String status,
  required String stage,
  String errorMessage = '',
  Map<String, dynamic>? report,
}) {
  return http.Response(
    jsonEncode({
      'ret': 1,
      'code': 200,
      'info': 'ok',
      'data': {
        'job_id': 'mhr_retry',
        'pgn_id': 42,
        'status': status,
        'stage': stage,
        'reused': true,
        'model': 'maia3-5m',
        'elo': 1500,
        'multipv': 5,
        'total_ply': 1,
        'analyzed_ply': status == 'completed' ? 1 : 0,
        'progress_percent': status == 'completed' ? 100 : 0,
        'error_message': errorMessage,
        if (report != null) 'report': report,
      },
    }),
    200,
  );
}

Map<String, dynamic> _reportPayload() {
  return {
    'version': 1,
    'source': 'maia3_microservice',
    'model': 'maia3-5m',
    'elo': 1500,
    'generated_at': '2026-06-14T00:00:00Z',
    'summary': {
      'human_match_percent': 68.5,
      'most_human_side': 'white',
      'sharpest_moments': [1],
      'notes': ['White chose a common human opening move.'],
    },
    'moves': [
      {
        'ply': 1,
        'move': 'e4',
        'move_uci': 'e2e4',
        'fen': 'fen after e4',
        'last_move': ['e2', 'e4'],
        'played_probability': 0.42,
        'typicality': 'common',
        'human_label': 'Common human choice',
        'candidates': [
          {'move': 'e2e4', 'san': 'e4', 'probability': 0.42},
        ],
      },
    ],
  };
}
