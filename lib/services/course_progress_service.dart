import 'app_preferences_store.dart';

class CourseProgressEntry {
  const CourseProgressEntry({
    required this.courseId,
    required this.courseTitle,
    this.positionMs = 0,
    this.totalMs = 0,
    this.completedCheckpoints = 0,
    this.totalCheckpoints = 0,
    this.completedCheckpointIndexes = const <int>{},
    required this.updatedAt,
  });

  final String courseId;
  final String courseTitle;
  final int positionMs;
  final int totalMs;
  final int completedCheckpoints;
  final int totalCheckpoints;
  final Set<int> completedCheckpointIndexes;
  final DateTime updatedAt;

  bool get isStarted => positionMs > 0 || completedCheckpoints > 0;

  bool get isComplete => _rawPercent >= 0.98;

  double get percent {
    final rawPercent = _rawPercent;
    return rawPercent >= 0.98 ? 1.0 : rawPercent;
  }

  double get _rawPercent {
    final checkpointPercent = totalCheckpoints <= 0
        ? 0.0
        : completedCheckpoints.clamp(0, totalCheckpoints) / totalCheckpoints;
    final timePercent =
        totalMs <= 0 ? 0.0 : positionMs.clamp(0, totalMs) / totalMs;
    return checkpointPercent > timePercent ? checkpointPercent : timePercent;
  }

  String get resumeLabel => _formatDuration(Duration(milliseconds: positionMs));

  CourseProgressEntry copyWith({
    String? courseId,
    String? courseTitle,
    int? positionMs,
    int? totalMs,
    int? completedCheckpoints,
    int? totalCheckpoints,
    Set<int>? completedCheckpointIndexes,
    DateTime? updatedAt,
  }) {
    return CourseProgressEntry(
      courseId: courseId ?? this.courseId,
      courseTitle: courseTitle ?? this.courseTitle,
      positionMs: positionMs ?? this.positionMs,
      totalMs: totalMs ?? this.totalMs,
      completedCheckpoints: completedCheckpoints ?? this.completedCheckpoints,
      totalCheckpoints: totalCheckpoints ?? this.totalCheckpoints,
      completedCheckpointIndexes:
          completedCheckpointIndexes ?? this.completedCheckpointIndexes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
      'course_title': courseTitle,
      'position_ms': positionMs,
      'total_ms': totalMs,
      'completed_checkpoints': completedCheckpoints,
      'total_checkpoints': totalCheckpoints,
      'completed_checkpoint_indexes': completedCheckpointIndexes.toList()
        ..sort(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CourseProgressEntry.fromJson(Map<String, dynamic> json) {
    return CourseProgressEntry(
      courseId: json['course_id']?.toString() ?? '',
      courseTitle: json['course_title']?.toString() ?? '',
      positionMs: _readInt(json['position_ms']),
      totalMs: _readInt(json['total_ms']),
      completedCheckpoints: _readInt(json['completed_checkpoints']),
      totalCheckpoints: _readInt(json['total_checkpoints']),
      completedCheckpointIndexes: _readIntSet(
        json['completed_checkpoint_indexes'],
      ),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CourseProgressEntry &&
        other.courseId == courseId &&
        other.courseTitle == courseTitle &&
        other.positionMs == positionMs &&
        other.totalMs == totalMs &&
        other.completedCheckpoints == completedCheckpoints &&
        other.totalCheckpoints == totalCheckpoints &&
        other.completedCheckpointIndexes.length ==
            completedCheckpointIndexes.length &&
        other.completedCheckpointIndexes
            .containsAll(completedCheckpointIndexes) &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        courseId,
        courseTitle,
        positionMs,
        totalMs,
        completedCheckpoints,
        totalCheckpoints,
        Object.hashAllUnordered(completedCheckpointIndexes),
        updatedAt,
      );
}

abstract interface class CourseProgressStore {
  Future<Map<String, CourseProgressEntry>> readAll();

  Future<CourseProgressEntry?> read(String courseId);

  Future<CourseProgressEntry?> latest();

  Future<void> write(CourseProgressEntry entry);
}

class NullCourseProgressStore implements CourseProgressStore {
  const NullCourseProgressStore();

  @override
  Future<Map<String, CourseProgressEntry>> readAll() async => const {};

  @override
  Future<CourseProgressEntry?> read(String courseId) async => null;

  @override
  Future<CourseProgressEntry?> latest() async => null;

  @override
  Future<void> write(CourseProgressEntry entry) async {}
}

class AppPreferencesCourseProgressStore implements CourseProgressStore {
  AppPreferencesCourseProgressStore(this.store);

  final AppPreferencesStore store;
  Future<void> _writeQueue = Future.value();

  @override
  Future<Map<String, CourseProgressEntry>> readAll() async {
    return (await store.read()).courseProgress;
  }

  @override
  Future<CourseProgressEntry?> read(String courseId) async {
    return (await readAll())[courseId];
  }

  @override
  Future<CourseProgressEntry?> latest() async {
    final entries = (await readAll()).values.toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries.isEmpty ? null : entries.first;
  }

  @override
  Future<void> write(CourseProgressEntry entry) async {
    final write = _writeQueue.then((_) async {
      final preferences = await store.read();
      final progress =
          Map<String, CourseProgressEntry>.from(preferences.courseProgress);
      progress[entry.courseId] = entry;
      await store.write(preferences.copyWith(courseProgress: progress));
    });
    _writeQueue = write.catchError((Object _) {});
    await write;
  }
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Set<int> _readIntSet(Object? value) {
  if (value is! Iterable) return const <int>{};
  return value.map((item) => _readInt(item)).where((item) => item >= 0).toSet();
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
