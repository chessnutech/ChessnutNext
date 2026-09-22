import 'package:in_app_review/in_app_review.dart';

enum ReviewPromptGameMode { bot, lichess, otb, chesscom, clock }

enum ReviewPromptGameResult { victory, defeat, draw }

class ReviewPromptOutcome {
  const ReviewPromptOutcome({
    required this.mode,
    required this.result,
  });

  final ReviewPromptGameMode mode;
  final ReviewPromptGameResult result;
}

class ReviewPromptState {
  const ReviewPromptState({
    this.completedGames = 0,
    this.positiveMoments = 0,
    this.promptCount = 0,
    this.lastPromptedAt,
    this.lastPromptedVersion = '',
  });

  final int completedGames;
  final int positiveMoments;
  final int promptCount;
  final DateTime? lastPromptedAt;
  final String lastPromptedVersion;

  ReviewPromptState copyWith({
    int? completedGames,
    int? positiveMoments,
    int? promptCount,
    DateTime? lastPromptedAt,
    bool clearLastPromptedAt = false,
    String? lastPromptedVersion,
  }) {
    return ReviewPromptState(
      completedGames: completedGames ?? this.completedGames,
      positiveMoments: positiveMoments ?? this.positiveMoments,
      promptCount: promptCount ?? this.promptCount,
      lastPromptedAt:
          clearLastPromptedAt ? null : (lastPromptedAt ?? this.lastPromptedAt),
      lastPromptedVersion: lastPromptedVersion ?? this.lastPromptedVersion,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'completed_games': completedGames,
      'positive_moments': positiveMoments,
      'prompt_count': promptCount,
      'last_prompted_at': lastPromptedAt?.toIso8601String(),
      'last_prompted_version': lastPromptedVersion,
    };
  }

  factory ReviewPromptState.fromJson(Map<String, dynamic> json) {
    return ReviewPromptState(
      completedGames: _intFromJson(json['completed_games']),
      positiveMoments: _intFromJson(json['positive_moments']),
      promptCount: _intFromJson(json['prompt_count']),
      lastPromptedAt: _dateFromJson(json['last_prompted_at']),
      lastPromptedVersion: json['last_prompted_version']?.toString() ?? '',
    );
  }
}

abstract class ReviewPromptStore {
  Future<ReviewPromptState> read();

  Future<void> write(ReviewPromptState state);
}

class MemoryReviewPromptStore implements ReviewPromptStore {
  MemoryReviewPromptStore([ReviewPromptState? state])
      : state = state ?? const ReviewPromptState();

  ReviewPromptState state;

  @override
  Future<ReviewPromptState> read() async => state;

  @override
  Future<void> write(ReviewPromptState state) async {
    this.state = state;
  }
}

abstract class ReviewRequester {
  Future<bool> isAvailable();

  Future<void> requestReview();
}

class InAppReviewRequester implements ReviewRequester {
  InAppReviewRequester({InAppReview? inAppReview})
      : _inAppReview = inAppReview ?? InAppReview.instance;

  final InAppReview _inAppReview;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _inAppReview.isAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> requestReview() async {
    try {
      await _inAppReview.requestReview();
    } catch (_) {
      // Native review APIs may silently refuse or fail based on store quotas.
    }
  }
}

class FakeReviewRequester implements ReviewRequester {
  FakeReviewRequester({bool isAvailable = true})
      : _isAvailable = isAvailable;

  final bool _isAvailable;
  int requestCount = 0;

  @override
  Future<bool> isAvailable() async => _isAvailable;

  @override
  Future<void> requestReview() async {
    requestCount += 1;
  }
}

class NoopReviewRequester implements ReviewRequester {
  const NoopReviewRequester();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<void> requestReview() async {}
}

class ReviewPromptService {
  ReviewPromptService({
    required this.store,
    required this.requester,
    required this.appVersion,
    DateTime Function()? now,
    this.minimumCompletedGames = 3,
    this.cooldown = const Duration(days: 90),
    this.maximumPrompts = 3,
  }) : now = now ?? DateTime.now;

  final ReviewPromptStore store;
  final ReviewRequester requester;
  final String appVersion;
  final DateTime Function() now;
  final int minimumCompletedGames;
  final Duration cooldown;
  final int maximumPrompts;

  Future<void> recordOutcome(ReviewPromptOutcome outcome) async {
    var state = await store.read();
    final positive = _isPositiveReviewMoment(outcome);
    state = state.copyWith(
      completedGames: state.completedGames + 1,
      positiveMoments: state.positiveMoments + (positive ? 1 : 0),
    );

    if (!positive || !_eligible(state)) {
      await store.write(state);
      return;
    }

    final attemptTime = now();
    state = state.copyWith(
      promptCount: state.promptCount + 1,
      lastPromptedAt: attemptTime,
      lastPromptedVersion: appVersion,
    );
    await store.write(state);

    if (await requester.isAvailable()) {
      await requester.requestReview();
    }
  }

  bool _eligible(ReviewPromptState state) {
    if (state.completedGames < minimumCompletedGames) return false;
    if (state.positiveMoments < minimumCompletedGames) return false;
    if (state.promptCount >= maximumPrompts) return false;
    if (state.lastPromptedVersion == appVersion) return false;
    final last = state.lastPromptedAt;
    if (last != null && now().difference(last) < cooldown) return false;
    return true;
  }

  bool _isPositiveReviewMoment(ReviewPromptOutcome outcome) {
    if (outcome.result != ReviewPromptGameResult.victory) return false;
    return outcome.mode == ReviewPromptGameMode.bot ||
        outcome.mode == ReviewPromptGameMode.lichess;
  }
}

int _intFromJson(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _dateFromJson(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text);
}
