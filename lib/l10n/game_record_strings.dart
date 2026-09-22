import 'app_strings.dart';
import 'localized_material.dart';
import '../models/app_models.dart';
import '../services/game_record_filter.dart';

class GameRecordStrings {
  const GameRecordStrings(this.appStrings);

  final AppStrings? appStrings;

  static GameRecordStrings of(BuildContext context) {
    return GameRecordStrings(AppStrings.maybeOf(context));
  }

  String get _localeKey => appStrings?.localeKey ?? 'en';

  bool get _isZhHans => _localeKey == 'zh-Hans';

  bool get _isZhHant => _localeKey == 'zh-Hant';

  bool get _isZh => _isZhHans || _isZhHant;

  String t(String text) {
    if (_isZhHans) return _zhHans[text] ?? appStrings?.t(text) ?? text;
    if (_isZhHant) return _zhHant[text] ?? appStrings?.t(text) ?? text;
    return appStrings?.t(text) ?? text;
  }

  String playerSummary(GameRecord record) {
    if (_isZh) {
      return '${t('White')}: ${record.displayWhiteName} / '
          '${t('Black')}: ${record.displayBlackName}';
    }
    return 'White: ${record.displayWhiteName} / '
        'Black: ${record.displayBlackName}';
  }

  String playerName(String color, String name) => '${t(color)}: $name';

  String timeSummary(GameRecord record) {
    return '${t('Time')}: ${record.timeLabel}';
  }

  String dateSummary(GameRecord record) {
    return '${t('Date')}: ${_localizedUnknown(record.dateLabel)}';
  }

  String locationSummary(GameRecord record) {
    return '${t('Location')}: ${_localizedUnknown(record.locationLabel)}';
  }

  String resultSummary(String resultLabel) {
    return '${t('Result')}: $resultLabel';
  }

  String resultLabel(GameRecord record) {
    if (record.isInProgress) return '';
    final resultToken = record.finishedResultToken;
    if (resultToken == '1-0') return _winnerLabel(record.displayWhiteName);
    if (resultToken == '0-1') return _winnerLabel(record.displayBlackName);
    if (resultToken == '1/2-1/2') return t('Draw');
    return '';
  }

  String modeLabel(GameRecord record) {
    final mode = record.playMode.trim();
    final source = mode.isNotEmpty
        ? _recordPlayModeLabel(mode)
        : record.subtitle.split('/').first.trim();
    return _localizedModeLabel(source.isEmpty ? 'Game' : source);
  }

  String resultFilterLabel(RecordResultFilter value) {
    return switch (value) {
      RecordResultFilter.all => t('All'),
      RecordResultFilter.win => t('Win'),
      RecordResultFilter.loss => t('Loss'),
      RecordResultFilter.draw => t('Draw'),
      RecordResultFilter.unfinished => t('Unfinished'),
    };
  }

  String colorFilterLabel(RecordColorFilter value) {
    return switch (value) {
      RecordColorFilter.all => t('Any color'),
      RecordColorFilter.white => t('White'),
      RecordColorFilter.black => t('Black'),
    };
  }

  String speedFilterLabel(RecordSpeedFilter value) {
    return switch (value) {
      RecordSpeedFilter.all => t('Any speed'),
      RecordSpeedFilter.casual => t('Casual'),
      RecordSpeedFilter.bullet => t('Bullet'),
      RecordSpeedFilter.blitz => t('Blitz'),
      RecordSpeedFilter.rapid => t('Rapid'),
      RecordSpeedFilter.daily => t('Daily'),
      RecordSpeedFilter.classical => t('Classical'),
    };
  }

  String _winnerLabel(String name) {
    if (_isZhHans) return '$name 获胜';
    if (_isZhHant) return '$name 獲勝';
    return '$name wins';
  }

  String _localizedUnknown(String value) {
    return value.trim().toLowerCase() == 'unknown' ? t('Unknown') : value;
  }

  String _localizedModeLabel(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return t('Game');
    final parts = normalized.split(RegExp(r'\s+'));
    return parts.map((part) {
      final word = _modeWords[part.toLowerCase()];
      return word == null ? part : t(word);
    }).join(' ');
  }

  static const _modeWords = {
    'analysis': 'Analysis',
    'bot': 'Bot',
    'bullet': 'Bullet',
    'blitz': 'Blitz',
    'classical': 'Classical',
    'game': 'Game',
    'local': 'Local',
    'otb': 'OTB',
    'rapid': 'Rapid',
  };

  static const _zhHans = {
    'All': '全部',
    'Analysis': '分析',
    'Any color': '任意方',
    'Any speed': '任意速度',
    'Black': '黑方',
    'Blitz': '闪电',
    'Bot': '电脑',
    'Bullet': '超快棋',
    'Casual': '休闲',
    'Classical': '慢棋',
    'Date': '日期',
    'Draw': '平局',
    'Game': '对局',
    'Local': '本地',
    'Location': '地点',
    'Loss': '负',
    'OTB': '实体棋盘',
    'Rapid': '快棋',
    'Result': '结果',
    'Time': '时间',
    'Unknown': '未知',
    'Unfinished': '未结束',
    'White': '白方',
    'Win': '胜',
  };

  static const _zhHant = {
    'All': '全部',
    'Analysis': '分析',
    'Any color': '不限顏色',
    'Any speed': '任意速度',
    'Black': '黑方',
    'Blitz': '閃電',
    'Bot': '電腦',
    'Bullet': '超快棋',
    'Casual': '休閒',
    'Classical': '慢棋',
    'Date': '日期',
    'Draw': '和棋',
    'Game': '對局',
    'Local': '本機',
    'Location': '地點',
    'Loss': '負',
    'OTB': '實體棋盤',
    'Rapid': '快棋',
    'Result': '結果',
    'Time': '時間',
    'Unknown': '未知',
    'Unfinished': '未結束',
    'White': '白方',
    'Win': '勝',
  };
}

String _recordPlayModeLabel(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return 'Game';
  return normalized
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) {
    if (part.length == 1) return part.toUpperCase();
    return part[0].toUpperCase() + part.substring(1);
  }).join(' ');
}
