import 'dart:async';

import 'package:http/http.dart' as http;

enum NetworkLatencyTone { stable, warning, danger }

class NetworkLatencySnapshot {
  const NetworkLatencySnapshot({
    required this.platform,
    required this.milliseconds,
  });

  final String platform;
  final int? milliseconds;

  NetworkLatencyTone get tone {
    final value = milliseconds;
    if (value == null || value >= 400) return NetworkLatencyTone.danger;
    if (value >= 200) return NetworkLatencyTone.warning;
    return NetworkLatencyTone.stable;
  }
}

abstract interface class NetworkLatencyProbe {
  Future<NetworkLatencySnapshot> ping(NetworkLatencyTarget target);
}

enum NetworkLatencyTarget {
  lichess('Lichess', 'https://lichess.org'),
  chesscom('Chess.com', 'https://www.chess.com');

  const NetworkLatencyTarget(this.label, this.url);

  final String label;
  final String url;
}

class HttpNetworkLatencyProbe implements NetworkLatencyProbe {
  const HttpNetworkLatencyProbe({required this.httpClient});

  final http.Client httpClient;

  @override
  Future<NetworkLatencySnapshot> ping(NetworkLatencyTarget target) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await httpClient
          .head(Uri.parse(target.url))
          .timeout(const Duration(seconds: 4));
      stopwatch.stop();
      if (response.statusCode >= 500) {
        return NetworkLatencySnapshot(
          platform: target.label,
          milliseconds: null,
        );
      }
      return NetworkLatencySnapshot(
        platform: target.label,
        milliseconds: stopwatch.elapsedMilliseconds,
      );
    } catch (_) {
      stopwatch.stop();
      return NetworkLatencySnapshot(
        platform: target.label,
        milliseconds: null,
      );
    }
  }
}
