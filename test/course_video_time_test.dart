import 'package:chessnut_flutter_export/screens/course_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('course video time formats current and total durations', () {
    expect(formatCourseVideoTime(Duration.zero), '0:00');
    expect(
        formatCourseVideoTime(const Duration(minutes: 8, seconds: 30)), '8:30');
    expect(
      formatCourseVideoTime(
        const Duration(hours: 1, minutes: 2, seconds: 3),
      ),
      '1:02:03',
    );
  });
}
