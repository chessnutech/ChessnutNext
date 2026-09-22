import 'package:chessnut_flutter_export/services/app_preferences_store.dart';
import 'package:chessnut_flutter_export/services/course_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CourseProgressEntry reports the strongest known progress signal', () {
    final entry = CourseProgressEntry(
      courseId: '03',
      courseTitle: '03 - Attack and Captures',
      positionMs: 30 * 1000,
      totalMs: 120 * 1000,
      completedCheckpoints: 2,
      totalCheckpoints: 4,
      updatedAt: DateTime.utc(2026, 5, 30),
    );

    expect(entry.percent, 0.5);
    expect(entry.isStarted, isTrue);
    expect(entry.isComplete, isFalse);
    expect(entry.resumeLabel, '0:30');
  });

  test('completed course progress is normalized to 100 percent', () {
    final entry = CourseProgressEntry(
      courseId: '00',
      courseTitle: '00 - Introduction',
      positionMs: 99 * 1000,
      totalMs: 100 * 1000,
      updatedAt: DateTime.utc(2026, 7, 14),
    );

    expect(entry.isComplete, isTrue);
    expect(entry.percent, 1.0);
  });

  test('AppPreferencesCourseProgressStore persists and returns latest course',
      () async {
    final preferencesStore = MemoryAppPreferencesStore();
    final progressStore = AppPreferencesCourseProgressStore(preferencesStore);
    final earlier = CourseProgressEntry(
      courseId: '00',
      courseTitle: '00 - Introduction',
      positionMs: 15 * 1000,
      totalMs: 60 * 1000,
      updatedAt: DateTime.utc(2026, 5, 29),
    );
    final latest = CourseProgressEntry(
      courseId: '03',
      courseTitle: '03 - Attack and Captures',
      positionMs: 45 * 1000,
      totalMs: 90 * 1000,
      completedCheckpoints: 1,
      totalCheckpoints: 2,
      completedCheckpointIndexes: {0},
      updatedAt: DateTime.utc(2026, 5, 30),
    );

    await progressStore.write(earlier);
    await progressStore.write(latest);

    expect(await progressStore.read('00'), earlier);
    expect(await progressStore.read('03'), latest);
    expect((await progressStore.readAll()).keys, containsAll(['00', '03']));
    expect(await progressStore.latest(), latest);
  });

  test('CourseProgressEntry persists completed checkpoint indexes', () {
    final entry = CourseProgressEntry(
      courseId: '04',
      courseTitle: '04 - The Pawn',
      completedCheckpoints: 2,
      totalCheckpoints: 4,
      completedCheckpointIndexes: {0, 3},
      updatedAt: DateTime.utc(2026, 7, 20),
    );

    expect(CourseProgressEntry.fromJson(entry.toJson()), entry);
  });
}
