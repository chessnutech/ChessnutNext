import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('voice move sound assets include all squares and terminal cues', () {
    final directory =
        Directory('${Directory.current.path}/assets/sounds/voice');
    expect(directory.existsSync(), isTrue);

    for (final file in 'abcdefgh'.split('')) {
      for (var rank = 1; rank <= 8; rank += 1) {
        expect(
          File('${directory.path}/$file$rank.mp3').existsSync(),
          isTrue,
          reason: '$file$rank.mp3 should be packaged for move speech',
        );
      }
    }

    for (final name in [
      'check',
      'checkmate',
      'oo',
      'ooo',
      'piecemoved',
      'stalemate',
    ]) {
      expect(
        File('${directory.path}/$name.mp3').existsSync(),
        isTrue,
        reason: '$name.mp3 should be packaged for move speech',
      );
    }
  });
}
