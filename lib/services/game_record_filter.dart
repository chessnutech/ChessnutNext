enum RecordModeFilter { all, local, bot, otb, lichess, chesscom }

enum RecordResultFilter { all, win, loss, draw, unfinished }

enum RecordColorFilter { all, white, black }

enum RecordSpeedFilter { all, casual, bullet, blitz, rapid, daily, classical }

enum RecordReportFilter { all, unanalyzed, standard, grandeur }

enum RecordSortMode { newest, oldest }

class GameRecordFilter {
  const GameRecordFilter({
    this.mode = RecordModeFilter.all,
    this.result = RecordResultFilter.all,
    this.color = RecordColorFilter.all,
    this.speed = RecordSpeedFilter.all,
    this.report = RecordReportFilter.all,
    this.query = '',
    this.minMoves = 0,
    this.onlyAnalyzed = false,
    this.sort = RecordSortMode.newest,
  });

  final RecordModeFilter mode;
  final RecordResultFilter result;
  final RecordColorFilter color;
  final RecordSpeedFilter speed;
  final RecordReportFilter report;
  final String query;
  final int minMoves;
  final bool onlyAnalyzed;
  final RecordSortMode sort;

  GameRecordFilter copyWith({
    RecordModeFilter? mode,
    RecordResultFilter? result,
    RecordColorFilter? color,
    RecordSpeedFilter? speed,
    RecordReportFilter? report,
    String? query,
    int? minMoves,
    bool? onlyAnalyzed,
    RecordSortMode? sort,
  }) {
    return GameRecordFilter(
      mode: mode ?? this.mode,
      result: result ?? this.result,
      color: color ?? this.color,
      speed: speed ?? this.speed,
      report: report ?? this.report,
      query: query ?? this.query,
      minMoves: minMoves ?? this.minMoves,
      onlyAnalyzed: onlyAnalyzed ?? this.onlyAnalyzed,
      sort: sort ?? this.sort,
    );
  }
}
