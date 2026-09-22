import 'dart:io';

import 'package:path_provider/path_provider.dart';

class GameRecordPgnCache {
  const GameRecordPgnCache({Directory? cacheDirectory})
      : _cacheDirectory = cacheDirectory;

  final Directory? _cacheDirectory;

  Future<String?> read(int pgnId) async {
    if (pgnId <= 0) return null;
    try {
      final file = await _file(pgnId);
      if (!await file.exists()) return null;
      final value = await file.readAsString();
      if (value.trim().isNotEmpty) return value;
      await file.delete();
    } catch (_) {}
    return null;
  }

  Future<void> write(int pgnId, String pgn) async {
    if (pgnId <= 0 || pgn.trim().isEmpty) return;
    try {
      final file = await _file(pgnId);
      await file.parent.create(recursive: true);
      await file.writeAsString(pgn, flush: true);
    } catch (_) {}
  }

  Future<void> delete(int pgnId) async {
    if (pgnId <= 0) return;
    try {
      final file = await _file(pgnId);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<File> _file(int pgnId) async {
    final support = _cacheDirectory ?? await getApplicationSupportDirectory();
    return File(
      '${support.path}${Platform.pathSeparator}game_record_pgn_cache'
      '${Platform.pathSeparator}$pgnId.pgn',
    );
  }
}
