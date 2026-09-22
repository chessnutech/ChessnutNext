import 'package:chessnut_flutter_export/services/review_prompt_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not request a review before enough positive games', () async {
    final store = MemoryReviewPromptStore();
    final requester = FakeReviewRequester();
    final service = ReviewPromptService(
      store: store,
      requester: requester,
      appVersion: '1.0.0',
      now: () => DateTime.utc(2026, 5, 20),
    );

    await service.recordOutcome(
      const ReviewPromptOutcome(
        mode: ReviewPromptGameMode.bot,
        result: ReviewPromptGameResult.victory,
      ),
    );

    expect(requester.requestCount, 0);
    expect(store.state.completedGames, 1);
    expect(store.state.positiveMoments, 1);
  });

  test('requests once after enough bot or lichess victories', () async {
    final store = MemoryReviewPromptStore();
    final requester = FakeReviewRequester();
    final service = ReviewPromptService(
      store: store,
      requester: requester,
      appVersion: '1.0.0',
      now: () => DateTime.utc(2026, 5, 20),
      minimumCompletedGames: 3,
    );

    for (var i = 0; i < 3; i++) {
      await service.recordOutcome(
        const ReviewPromptOutcome(
          mode: ReviewPromptGameMode.bot,
          result: ReviewPromptGameResult.victory,
        ),
      );
    }

    expect(requester.requestCount, 1);
    expect(store.state.promptCount, 1);
    expect(store.state.lastPromptedVersion, '1.0.0');
    expect(store.state.lastPromptedAt, DateTime.utc(2026, 5, 20));
  });

  test('does not request again in the same app version', () async {
    final store = MemoryReviewPromptStore(
      ReviewPromptState(
        completedGames: 9,
        positiveMoments: 4,
        promptCount: 1,
        lastPromptedAt: DateTime.utc(2026, 1, 1),
        lastPromptedVersion: '1.0.0',
      ),
    );
    final requester = FakeReviewRequester();
    final service = ReviewPromptService(
      store: store,
      requester: requester,
      appVersion: '1.0.0',
      now: () => DateTime.utc(2026, 5, 20),
    );

    await service.recordOutcome(
      const ReviewPromptOutcome(
        mode: ReviewPromptGameMode.lichess,
        result: ReviewPromptGameResult.victory,
      ),
    );

    expect(requester.requestCount, 0);
    expect(store.state.promptCount, 1);
  });

  test('counts unsupported platform attempts so users are not nagged', () async {
    final store = MemoryReviewPromptStore(
      const ReviewPromptState(completedGames: 2, positiveMoments: 2),
    );
    final requester = FakeReviewRequester(isAvailable: false);
    final service = ReviewPromptService(
      store: store,
      requester: requester,
      appVersion: '1.0.0',
      now: () => DateTime.utc(2026, 5, 20),
      minimumCompletedGames: 3,
    );

    await service.recordOutcome(
      const ReviewPromptOutcome(
        mode: ReviewPromptGameMode.lichess,
        result: ReviewPromptGameResult.victory,
      ),
    );

    expect(requester.requestCount, 0);
    expect(store.state.promptCount, 1);
    expect(store.state.lastPromptedVersion, '1.0.0');
  });

  test('ignores losses, draws, otb, and manual game review timing', () async {
    final store = MemoryReviewPromptStore(
      const ReviewPromptState(completedGames: 10, positiveMoments: 10),
    );
    final requester = FakeReviewRequester();
    final service = ReviewPromptService(
      store: store,
      requester: requester,
      appVersion: '1.0.0',
      now: () => DateTime.utc(2026, 5, 20),
    );

    await service.recordOutcome(
      const ReviewPromptOutcome(
        mode: ReviewPromptGameMode.otb,
        result: ReviewPromptGameResult.victory,
      ),
    );
    await service.recordOutcome(
      const ReviewPromptOutcome(
        mode: ReviewPromptGameMode.bot,
        result: ReviewPromptGameResult.defeat,
      ),
    );
    await service.recordOutcome(
      const ReviewPromptOutcome(
        mode: ReviewPromptGameMode.lichess,
        result: ReviewPromptGameResult.draw,
      ),
    );

    expect(requester.requestCount, 0);
  });
}
