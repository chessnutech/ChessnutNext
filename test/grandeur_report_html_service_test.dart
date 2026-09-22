import 'package:chessnut_flutter_export/services/grandeur_report_html_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a complete Grandeur HTML report and escapes user content', () {
    final html = buildGrandeurReportHtml(
      GrandeurHtmlReportData(
        title: 'Grandeur <Report>',
        whiteName: 'White & Player',
        blackName: 'Black "Player"',
        language: 'ja-JP',
        summary: 'Use <files> safely.',
        coachName: 'Deep analyst',
        coachRole: 'Calm, careful, detailed',
        coachAvatarDataUri: 'data:image/png;base64,YXZhdGFy',
        accentColor: '#8B6DFF',
        pieceImageDataUris: const {
          'wP.svg': 'data:image/svg+xml;base64,d2hpdGUtcGF3bg==',
          'bP.svg': 'data:image/svg+xml;base64,YmxhY2stcGF3bg==',
        },
        whiteAccuracy: 91.25,
        blackAccuracy: 83.75,
        hasWhiteAccuracy: true,
        hasBlackAccuracy: true,
        whiteCounts: const {'Best': 4, '不准确': 1},
        blackCounts: const {'Best': 2},
        moves: const [
          GrandeurHtmlMove(
            ply: 1,
            san: 'e4',
            fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
            tag: 'Best',
            commentary: 'Controls & develops.',
            betterMove: 'Nf3',
          ),
        ],
        generatedAt: DateTime.utc(2026, 8, 11, 12),
      ),
    );

    expect(html, contains('<!doctype html>'));
    expect(html, contains('Grandeur &lt;Report&gt;'));
    expect(html, contains('White &amp; Player'));
    expect(html, contains('Black &quot;Player&quot;'));
    expect(html, contains('Use &lt;files&gt; safely.'));
    expect(html, contains('91.25%'));
    expect(html, contains('83.75%'));
    expect(html, contains('1. e4'));
    expect(html, contains('Controls &amp; develops.'));
    expect(html, contains('class="coach-avatar"'));
    expect(html, contains('class="board"'));
    expect(RegExp('class="square ').allMatches(html), hasLength(64));
    expect(html, contains('--board-light: #f0d9b6'));
    expect(html, contains('--board-dark: #b58863'));
    expect(html, contains('class="piece-image"'));
    expect(html, contains('data:image/svg+xml;base64,d2hpdGUtcGF3bg=='));
    expect(html, isNot(contains('+0.20')));
    expect(html, isNot(contains('+0.35')));
    expect(html, contains('--accent: #8b6dff'));
    expect(html, contains('--quality: #a3e635'));
    expect(html, contains('--quality: #eac84a'));
    expect(html, isNot(contains('&#9817;')));
    expect(html, isNot(contains('Use <files> safely.')));
  });
}
