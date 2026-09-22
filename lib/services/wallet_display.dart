import '../l10n/app_strings.dart';

String formatWalletPoints(int points) {
  final sign = points < 0 ? '-' : '';
  final digits = points.abs().toString();
  final buffer = StringBuffer(sign);
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String formatWalletDelta(int amount) {
  if (amount > 0) {
    return '+${formatWalletPoints(amount)}';
  }
  return formatWalletPoints(amount);
}

String localizedWalletLedgerTitle(AppStrings strings, String title) {
  final readableTitle = readableWalletLedgerTitle(title.trim());
  final dailyTaskTitle = _dailyTaskLedgerTitle(readableTitle);
  if (dailyTaskTitle == null) return strings.t(readableTitle);
  return '${strings.t('Daily Tasks')}: ${strings.t(dailyTaskTitle)}';
}

String? _dailyTaskLedgerTitle(String title) {
  var normalized = title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  for (final prefix in const [
    'daily task:',
    'daily tasks:',
    'daily task -',
    'daily tasks -',
  ]) {
    if (normalized.startsWith(prefix)) {
      normalized = normalized.substring(prefix.length).trim();
      break;
    }
  }

  return switch (normalized) {
    'check in' || 'check-in' || 'daily check-in' => 'Daily check-in',
    'finish one game' ||
    'finish one bot or online game' =>
      'Finish one bot or online game',
    'play one puzzle' || 'solve one puzzle' => 'Play one puzzle',
    'share one game' => 'Share one game',
    'complete one career challenge' ||
    'complete one career mode challenge' ||
    'finish one career challenge' =>
      'Complete one Career challenge',
    'share one report' || 'share one analysis report' => 'Share one report',
    'run one analysis' || 'run one game analysis' => 'Run one game analysis',
    _ => null,
  };
}

String readableWalletLedgerTitle(String title) {
  return title
      .replaceAll('Engine Model Build', 'Personal engine training')
      .replaceAll('Model Build', 'personal engine training');
}
