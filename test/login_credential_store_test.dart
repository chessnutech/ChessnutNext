import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/services/login_credential_store.dart';

void main() {
  test('memory credential store writes, reads, and clears credentials', () async {
    final store = MemoryLoginCredentialStore();
    const credentials = StoredLoginCredentials(
      account: 'player@example.com',
      password: 'secret',
    );

    expect(await store.read(), isNull);
    await store.write(credentials);
    expect(await store.read(), same(credentials));
    await store.clear();
    expect(await store.read(), isNull);
  });

  test('invalid credentials are not considered remembered', () {
    expect(
      const StoredLoginCredentials(account: '', password: 'secret').isValid,
      isFalse,
    );
    expect(
      const StoredLoginCredentials(account: 'player', password: '').isValid,
      isFalse,
    );
  });
}
