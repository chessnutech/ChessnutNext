class GameRecordPgnCache {
  const GameRecordPgnCache({Object? cacheDirectory});

  Future<String?> read(int pgnId) async => null;

  Future<void> write(int pgnId, String pgn) async {}

  Future<void> delete(int pgnId) async {}
}
