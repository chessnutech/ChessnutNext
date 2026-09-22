import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/services/daily_claim_service.dart';

void main() {
  test('allows first daily claim', () {
    final service = DailyClaimService(
      store: MemoryDailyClaimStore(),
      now: () => DateTime(2026, 5, 16, 13),
    );

    expect(service.status().canClaim, isTrue);
    final result = service.claim();
    expect(result.claimed, isTrue);
    expect(service.status().canClaim, isFalse);
  });

  test('blocks repeated claim inside 24 hours even after noon refresh boundary',
      () {
    final store = MemoryDailyClaimStore()
      ..lastClaimedAt = DateTime(2026, 5, 15, 23);
    final service = DailyClaimService(
      store: store,
      now: () => DateTime(2026, 5, 16, 13),
    );

    expect(service.status().canClaim, isFalse);
    expect(service.status().label, 'Claimed');
    expect(service.claim().claimed, isFalse);
  });

  test('allows claim after next noon refresh and at least 24 hours', () {
    final store = MemoryDailyClaimStore()
      ..lastClaimedAt = DateTime(2026, 5, 15, 11, 30);
    final service = DailyClaimService(
      store: store,
      now: () => DateTime(2026, 5, 16, 12, 1),
    );

    expect(service.status().canClaim, isTrue);
  });

  test('blocks claim before local noon on the next calendar day', () {
    final store = MemoryDailyClaimStore()
      ..lastClaimedAt = DateTime(2026, 5, 15, 13);
    final service = DailyClaimService(
      store: store,
      now: () => DateTime(2026, 5, 16, 11, 59),
    );

    expect(service.status().canClaim, isFalse);
  });
}

class MemoryDailyClaimStore implements DailyClaimStore {
  @override
  DateTime? lastClaimedAt;
}
