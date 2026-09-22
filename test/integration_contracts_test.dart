import 'package:chessnut_flutter_export/services/integration_contracts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('integration task catalog separates migrated APIs from new features',
      () {
    final catalog = ChessnutIntegrationCatalog.current();

    expect(catalog.task(8).status, IntegrationTaskStatus.inProgress);
    expect(catalog.task(8).legacyEndpoints, contains('api/login'));
    expect(catalog.task(8).legacyEndpoints, contains('api/getPgnList'));
    expect(catalog.task(8).newBackendContracts, contains('wallet.balance'));
    expect(
        catalog.task(8).newBackendContracts, contains('grandeur.analyzeGame'));

    expect(catalog.task(7).legacySources,
        contains('flutter_chessnut/lib/page/play_with_bot.dart'));
    expect(catalog.task(10).externalEndpoints,
        contains('POST https://lichess.org/api/board/seek'));
    expect(catalog.task(11).legacyEndpoints,
        contains('static/js/chess-helper.js'));
  });
}
