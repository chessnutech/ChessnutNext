import 'dart:convert';
import 'dart:io';

import 'package:chessnut_flutter_export/services/session_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('secure session store writes, reads, and clears the session', () async {
    const store = SecureChessnutSessionStore();

    await store.write(
      const StoredChessnutSession(
        userId: 42,
        refreshToken: 'secure-refresh-token',
      ),
    );

    final restored = await store.read();
    expect(restored?.userId, 42);
    expect(restored?.refreshToken, 'secure-refresh-token');

    await store.clear();
    expect(await store.read(), isNull);
  });

  test('secure session store migrates and deletes the legacy JSON file',
      () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'chessnut_session_store_test_',
    );
    addTearDown(() => tempDirectory.delete(recursive: true));
    final legacyFile = File('${tempDirectory.path}/chessnut_session.json');
    await legacyFile.writeAsString(
      jsonEncode({
        'user_id': 77,
        'refresh_token': 'legacy-refresh-token',
      }),
    );
    final store = SecureChessnutSessionStore(
      legacySessionFileProvider: () async => legacyFile,
    );

    final migrated = await store.read();

    expect(migrated?.userId, 77);
    expect(migrated?.refreshToken, 'legacy-refresh-token');
    expect(await legacyFile.exists(), isFalse);
    expect((await store.read())?.refreshToken, 'legacy-refresh-token');
  });
}
