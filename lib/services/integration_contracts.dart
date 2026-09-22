enum IntegrationTaskStatus { pending, inProgress, blocked, done }

class IntegrationTaskContract {
  const IntegrationTaskContract({
    required this.id,
    required this.title,
    required this.status,
    this.legacySources = const [],
    this.legacyEndpoints = const [],
    this.externalEndpoints = const [],
    this.newBackendContracts = const [],
    this.notes = const [],
  });

  final int id;
  final String title;
  final IntegrationTaskStatus status;
  final List<String> legacySources;
  final List<String> legacyEndpoints;
  final List<String> externalEndpoints;
  final List<String> newBackendContracts;
  final List<String> notes;
}

class ChessnutIntegrationCatalog {
  const ChessnutIntegrationCatalog(this.tasks);

  factory ChessnutIntegrationCatalog.current() {
    return const ChessnutIntegrationCatalog([
      IntegrationTaskContract(
        id: 7,
        title: 'Bot game real engine and move loop',
        status: IntegrationTaskStatus.inProgress,
        legacySources: [
          'flutter_chessnut/lib/page/bot_match.dart',
          'flutter_chessnut/lib/page/play_with_bot.dart',
          'flutter_chessnut/lib/core/chess_game.dart',
          'flutter_chessnut/lib/core/setting/game_provider.dart',
        ],
        legacyEndpoints: [
          'api/uploadPgn',
          'api/updatePgn',
        ],
        notes: [
          'Original app uses uci_engine with Stockfish, Maia via LC0, LC0, and Fairy.',
          'New frontend uses dartchess/chessground and falls back gracefully until binaries are packaged.',
        ],
      ),
      IntegrationTaskContract(
        id: 8,
        title: 'Backend account, record, wallet, Grandeur and training APIs',
        status: IntegrationTaskStatus.inProgress,
        legacySources: [
          'flutter_chessnut/lib/core/chessnut_api.dart',
          'flutter_chessnut/lib/page/game_record.dart',
          'flutter_chessnut/lib/page/model_manager_page.dart',
          'flutter_chessnut/lib/core/chessnut_provider/user_info.dart',
        ],
        legacyEndpoints: [
          'api/login',
          'api/Token/Refresh',
          'api/registerWithCaptcha',
          'api/sendResetPasswordEmail',
          'api/resetPassword',
          'api/changePassword',
          'api/updateInfo',
          'api/getPgnList',
          'api/uploadPgn',
          'api/updatePgn',
          'api/delPgn',
          'api/setCollectd',
          'api/delCollectd',
          'api/train/list',
          'api/train/official_shared_list',
          'api/train/shared_list',
          'api/train/subStatus',
          'api/train/del',
        ],
        newBackendContracts: [
          'wallet.balance',
          'wallet.claimDaily',
          'wallet.ledger',
          'wallet.consumePoints',
          'membership.products',
          'membership.purchaseReceiptVerify',
          'grandeur.analyzeGame',
          'grandeur.explainMove',
          'grandeur.voiceProfiles',
          'grandeur.analysisHistory',
        ],
        notes: [
          'Wallet and Grandeur are new features and do not exist in the original project.',
          'Legacy subscription endpoints are for engine training/VIP and may need to be reconciled with new membership.',
        ],
      ),
      IntegrationTaskContract(
        id: 10,
        title: 'Lichess native Board API',
        status: IntegrationTaskStatus.inProgress,
        legacySources: [
          'flutter_chessnut/lib/page/online_lichess_page.dart',
          'flutter_chessnut/lib/page/bind_lichess_page.dart',
          'flutter_chessnut/lib/core/chessnut_api.dart',
        ],
        legacyEndpoints: [
          'api/getLichessToken',
          'api/bindLichess',
          'api/freeUserBind',
        ],
        externalEndpoints: [
          'POST https://lichess.org/api/board/seek',
          'GET https://lichess.org/api/stream/event',
          'GET https://lichess.org/api/board/game/stream/{gameId}',
          'POST https://lichess.org/api/board/game/{gameId}/move/{move}',
          'POST https://lichess.org/api/board/game/{gameId}/resign',
          'POST https://lichess.org/api/board/game/{gameId}/draw/{accept}',
          'POST https://lichess.org/api/board/game/{gameId}/takeback/{accept}',
        ],
        notes: [
          'OAuth uses PKCE, long-lived access tokens, and no refresh token according to current Lichess docs.',
          'Board API requires board:play scope.',
        ],
      ),
      IntegrationTaskContract(
        id: 11,
        title: 'Chess.com WebView and JS injection',
        status: IntegrationTaskStatus.inProgress,
        legacySources: [
          'flutter_chessnut/lib/page/online_chesscom_page.dart',
          'flutter_chessnut/lib/page/webview_page.dart',
          'flutter_chessnut/lib/page/webview_win_page.dart',
        ],
        legacyEndpoints: [
          'static/js/chess-helper.js',
          'api/bindChessCom',
        ],
        notes: [
          'Chess.com stays WebView-only. Users operate on chess.com; Chessnut injects JS for FEN polling and UCI moves.',
          'Production validation must track chess.com DOM changes.',
        ],
      ),
    ]);
  }

  final List<IntegrationTaskContract> tasks;

  IntegrationTaskContract task(int id) {
    return tasks.firstWhere((task) => task.id == id);
  }
}
