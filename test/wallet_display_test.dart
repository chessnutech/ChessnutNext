import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/l10n/app_strings.dart';
import 'package:chessnut_flutter_export/services/wallet_display.dart';

void main() {
  test('backend daily task ledger titles are localized', () {
    const strings = AppStrings(
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    );

    final analysis = localizedWalletLedgerTitle(
      strings,
      'Daily task: run one analysis',
    );
    final game = localizedWalletLedgerTitle(
      strings,
      'Daily task: finish one game',
    );
    final share = localizedWalletLedgerTitle(
      strings,
      'Daily task: share one game',
    );

    final career = localizedWalletLedgerTitle(
      strings,
      'Daily task: complete one career challenge',
    );

    expect(analysis, isNot(contains('Daily task')));
    expect(analysis, isNot(contains('run one analysis')));
    expect(game, isNot(contains('finish one game')));
    expect(share, isNot(contains('share one game')));
    expect(career, isNot(contains('complete one career challenge')));
    expect(career, isNot(contains('Daily task')));
    expect(analysis, contains('每日任务'));
    expect(game, contains('每日任务'));
    expect(share, contains('每日任务'));
  });
}
