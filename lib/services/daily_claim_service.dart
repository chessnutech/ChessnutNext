abstract class DailyClaimStore {
  DateTime? get lastClaimedAt;
  set lastClaimedAt(DateTime? value);
}

class InMemoryDailyClaimStore implements DailyClaimStore {
  @override
  DateTime? lastClaimedAt;
}

class DailyClaimStatus {
  const DailyClaimStatus({
    required this.canClaim,
    required this.label,
    required this.nextAvailableAt,
  });

  final bool canClaim;
  final String label;
  final DateTime nextAvailableAt;
}

class DailyClaimResult {
  const DailyClaimResult({
    required this.claimed,
    required this.status,
  });

  final bool claimed;
  final DailyClaimStatus status;
}

class DailyClaimService {
  DailyClaimService({
    required this.store,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final DailyClaimStore store;
  final DateTime Function() now;

  DailyClaimStatus status() {
    final current = now();
    final last = store.lastClaimedAt;
    if (last == null) {
      return DailyClaimStatus(
        canClaim: true,
        label: 'Claim',
        nextAvailableAt: current,
      );
    }

    final next = _nextAvailableAt(last);
    final canClaim = !current.isBefore(next);
    return DailyClaimStatus(
      canClaim: canClaim,
      label: canClaim ? 'Claim' : 'Claimed',
      nextAvailableAt: next,
    );
  }

  DailyClaimResult claim() {
    final currentStatus = status();
    if (!currentStatus.canClaim) {
      return DailyClaimResult(claimed: false, status: currentStatus);
    }

    store.lastClaimedAt = now();
    return DailyClaimResult(claimed: true, status: status());
  }

  DateTime _nextAvailableAt(DateTime last) {
    final afterTwentyFourHours = last.add(const Duration(hours: 24));
    final nextNoon = DateTime(last.year, last.month, last.day, 12);
    final refreshBoundary = last.isBefore(nextNoon)
        ? nextNoon
        : nextNoon.add(const Duration(days: 1));
    return afterTwentyFourHours.isAfter(refreshBoundary)
        ? afterTwentyFourHours
        : refreshBoundary;
  }
}
