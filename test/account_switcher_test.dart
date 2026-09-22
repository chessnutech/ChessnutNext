import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/screens/account_switcher_screen.dart';
import 'package:chessnut_flutter_export/services/account_switcher_store.dart';

void main() {
  test('account switcher is enabled on app platforms including chess clock',
      () {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.windows,
      TargetPlatform.macOS,
    ]) {
      expect(
        supportsAccountSwitcherPlatform(platform),
        isTrue,
        reason: '$platform should support account switching',
      );
    }
    expect(supportsAccountSwitcherPlatform(TargetPlatform.linux), isFalse);
    expect(supportsAccountSwitcherPlatform(TargetPlatform.fuchsia), isFalse);
  });

  test('saved account expires exactly seven days after authentication', () {
    final authenticatedAt = DateTime.utc(2026, 8, 1, 12);
    final account = SavedChessnutAccount(
      userId: 1,
      refreshToken: 'token-1',
      displayName: 'First',
      authenticatedAt: authenticatedAt,
    );

    expect(
      account.isExpired(
        authenticatedAt.add(savedAccountValidity).subtract(
              const Duration(microseconds: 1),
            ),
      ),
      isFalse,
    );
    expect(
      account.isExpired(authenticatedAt.add(savedAccountValidity)),
      isTrue,
    );
  });

  test('memory account store keeps the most recently used account first',
      () async {
    final store = MemoryAccountSwitcherStore();
    const first = SavedChessnutAccount(
      userId: 1,
      refreshToken: 'token-1',
      displayName: 'First',
    );
    const second = SavedChessnutAccount(
      userId: 2,
      refreshToken: 'token-2',
      displayName: 'Second',
    );

    await store.upsert(first);
    await store.upsert(second);
    await store.upsert(first);

    expect((await store.read()).map((account) => account.userId), [1, 2]);
    await store.remove(1);
    expect((await store.read()).map((account) => account.userId), [2]);
  });

  test('full login renews validity without creating a duplicate', () async {
    final oldAuthentication = DateTime.now().toUtc().subtract(
          const Duration(days: 8),
        );
    final store = MemoryAccountSwitcherStore(
      accounts: [
        SavedChessnutAccount(
          userId: 1,
          refreshToken: 'old-token',
          displayName: 'First',
          authenticatedAt: oldAuthentication,
        ),
      ],
    );

    await store.upsert(
      const SavedChessnutAccount(
        userId: 1,
        refreshToken: 'new-token',
        displayName: 'First',
      ),
      renewValidity: true,
    );

    final accounts = await store.read();
    expect(accounts, hasLength(1));
    expect(accounts.single.refreshToken, 'new-token');
    expect(accounts.single.authenticatedAt!.isAfter(oldAuthentication), isTrue);
    expect(accounts.single.isExpired(DateTime.now()), isFalse);
  });

  testWidgets('account switcher supports manage and add-account actions', (
    tester,
  ) async {
    final store = MemoryAccountSwitcherStore(
      accounts: const [
        SavedChessnutAccount(
          userId: 1,
          refreshToken: 'token-1',
          displayName: 'Current',
        ),
        SavedChessnutAccount(
          userId: 2,
          refreshToken: 'token-2',
          displayName: 'Second',
        ),
      ],
    );
    var addAccountTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AccountSwitcherScreen(
          onNavigate: (_) {},
          store: store,
          currentUserId: 1,
          onAddAccount: () => addAccountTapped = true,
          onSelectAccount: (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Current account'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('account-switcher-remove-2')), findsNothing);
    await tester
        .tap(find.byKey(const ValueKey('account-switcher-manage-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-switcher-remove-2')),
        findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('account-switcher-add-account')));
    await tester.pumpAndSettle();
    expect(addAccountTapped, isTrue);
  });

  testWidgets('account switcher remembers and fully shows current account', (
    tester,
  ) async {
    final store = MemoryAccountSwitcherStore(
      accounts: const [
        SavedChessnutAccount(
          userId: 2,
          refreshToken: 'token-2',
          displayName: 'Second',
        ),
      ],
    );
    const current = SavedChessnutAccount(
      userId: 1,
      refreshToken: 'token-1',
      displayName: 'hahaha',
      email: 'account-1079199604@example.com',
    );
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: AccountSwitcherScreen(
          onNavigate: (_) {},
          store: store,
          currentUserId: 1,
          currentAccount: current,
          onAddAccount: () {},
          onSelectAccount: (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect((await store.read()).map((account) => account.userId), [1, 2]);
    expect(
      find.byKey(const ValueKey('account-switcher-current-label')),
      findsOneWidget,
    );
    expect(find.text('Current account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expired account stays saved and opens login when tapped', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 19, 12);
    final store = MemoryAccountSwitcherStore(
      accounts: [
        SavedChessnutAccount(
          userId: 1,
          refreshToken: 'current-token',
          displayName: 'Current',
          authenticatedAt: now,
        ),
        SavedChessnutAccount(
          userId: 2,
          refreshToken: 'expired-token',
          displayName: 'Expired',
          authenticatedAt: now.subtract(savedAccountValidity),
        ),
      ],
    );
    var loginOpened = false;
    var switchAttempted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AccountSwitcherScreen(
          onNavigate: (_) {},
          store: store,
          currentUserId: 1,
          now: () => now,
          onAddAccount: () => loginOpened = true,
          onSelectAccount: (_) async {
            switchAttempted = true;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('account-switcher-expired-2')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('account-switcher-card-2')),
    );
    await tester.pump();

    expect(loginOpened, isTrue);
    expect(switchAttempted, isFalse);
    expect((await store.read()).map((account) => account.userId), [1, 2]);
  });

  testWidgets('account switcher lays out on clock and desktop platforms', (
    tester,
  ) async {
    try {
      for (final configuration in [
        (TargetPlatform.android, const Size(1024, 600)),
        (TargetPlatform.iOS, const Size(1194, 834)),
        (TargetPlatform.windows, const Size(1440, 900)),
        (TargetPlatform.macOS, const Size(1440, 900)),
      ]) {
        debugDefaultTargetPlatformOverride = configuration.$1;
        await tester.binding.setSurfaceSize(configuration.$2);
        await tester.pumpWidget(
          MaterialApp(
            home: AccountSwitcherScreen(
              onNavigate: (_) {},
              store: MemoryAccountSwitcherStore(
                accounts: const [
                  SavedChessnutAccount(
                    userId: 1,
                    refreshToken: 'current-token',
                    displayName: 'Current account name',
                    email: 'current@example.com',
                  ),
                  SavedChessnutAccount(
                    userId: 2,
                    refreshToken: 'second-token',
                    displayName: 'Second account name',
                    email: 'second@example.com',
                  ),
                ],
              ),
              currentUserId: 1,
              onAddAccount: () {},
              onSelectAccount: (_) async => true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${configuration.$1} should render without overflow',
        );
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
    }
  });
}
