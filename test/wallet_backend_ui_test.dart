import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chessnut_flutter_export/l10n/app_language.dart';
import 'package:chessnut_flutter_export/l10n/app_strings.dart';
import 'package:chessnut_flutter_export/models/app_models.dart';
import 'package:chessnut_flutter_export/screens/account_screen.dart';
import 'package:chessnut_flutter_export/screens/daily_tasks_screen.dart';
import 'package:chessnut_flutter_export/screens/home_screen.dart';
import 'package:chessnut_flutter_export/screens/points_screen.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:chessnut_flutter_export/services/daily_claim_service.dart';
import 'package:chessnut_flutter_export/theme/chessnut_theme.dart';

const _session = ChessnutLoginSession(
  userId: 7,
  token: '12345678901234567890123456789012',
  refreshToken: 'refresh-token',
  avatarUrl: '',
  bindApple: false,
  bindChess: false,
  bindGoogle: false,
  bindLichess: false,
  chessName: '',
  email: 'player@example.com',
  lichessName: '',
  noPassword: false,
  phone: '',
  region: 'US',
  username: 'Chessnut Player',
);

Widget _testShell(Widget child) {
  return MaterialApp(
    theme: ChessnutTheme.light(),
    supportedLocales: AppLanguagePreference.supportedLocales,
    localizationsDelegates: AppStrings.localizationsDelegates,
    home: Scaffold(body: child),
  );
}

Widget _localizedTestShell(Widget child, Locale locale) {
  return MaterialApp(
    locale: locale,
    theme: ChessnutTheme.light(),
    supportedLocales: AppLanguagePreference.supportedLocales,
    localizationsDelegates: AppStrings.localizationsDelegates,
    home: Scaffold(body: child),
  );
}

http.Response _ok(Object? data) {
  return http.Response(
    jsonEncode({'ret': 1, 'code': 200, 'info': 'ok', 'data': data}),
    200,
  );
}

ChessnutApiClient _walletClient({
  required List<http.Request> requests,
  int balance = 1376,
  int dailyClaimPoints = 100,
  int? remoteDailyPointsAdded,
  bool claimedToday = false,
  bool claimDailyReturnsClaimedToday = true,
  bool memberActive = false,
  String memberExpireAt = '',
  List<String> claimedTaskKeys = const <String>[],
  List<Map<String, Object?>> ledger = const <Map<String, Object?>>[],
  Uri? baseUri,
}) {
  var currentBalance = balance;
  var currentClaimedToday = claimedToday;
  var currentClaimedTaskKeys = claimedTaskKeys;
  return ChessnutApiClient(
    session: _session,
    baseUri: baseUri,
    httpClient: MockClient((request) async {
      requests.add(request);
      if (request.method == 'POST' &&
          request.url.path == '/api/wallet/balance') {
        return _ok({
          'balance': currentBalance,
          'claimed_today': currentClaimedToday,
          'daily_claim_points': dailyClaimPoints,
          'last_claimed_at': '',
          'member_active': memberActive,
          'member_expire_at': memberExpireAt,
          'claimed_tasks': currentClaimedTaskKeys,
        });
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/wallet/ledger') {
        return _ok({'items': ledger});
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/membership/products') {
        return _ok({
          'products': [
            {
              'id': 'premium_yearly_auto',
              'title': 'Premium Yearly',
              'price': '29.99',
              'price_cents': 2999,
              'currency': 'USD',
              'period': 'year',
              'renewing': true,
              'duration_months': 12,
              'platform_product_id': 'premium_yearly_auto',
              'recommended': true,
            },
          ],
        });
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/wallet/debugAdjust') {
        final amount = int.parse(request.bodyFields['amount'] ?? '0');
        currentBalance = math.max(0, currentBalance + amount);
        return _ok({
          'balance': currentBalance,
          'points_added': amount,
          'claimed_today': currentClaimedToday,
        });
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/wallet/claimDaily') {
        final points = int.tryParse(request.bodyFields['points'] ?? '') ??
            dailyClaimPoints;
        final pointsAdded = remoteDailyPointsAdded ?? points;
        currentBalance += pointsAdded;
        currentClaimedToday = true;
        return _ok({
          'balance': currentBalance,
          'points_added': pointsAdded,
          'claimed_today': claimDailyReturnsClaimedToday,
        });
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/wallet/claimTask') {
        final taskKey = request.bodyFields['task_key'] ?? '';
        final points = int.tryParse(request.bodyFields['points'] ?? '') ?? 20;
        currentClaimedTaskKeys = {...currentClaimedTaskKeys, taskKey}.toList();
        currentBalance += points;
        return _ok({
          'balance': currentBalance,
          'points_added': points,
          'claimed_today': currentClaimedToday,
        });
      }
      return http.Response('not found', 404);
    }),
  );
}

void main() {
  test('daily task visible claim count ignores retired task keys', () {
    expect(
      dailyTaskVisibleClaimCount({'puzzle', 'share', 'career'}),
      2,
    );
  });

  test('daily task rewards use configured check-in and workflow points', () {
    expect(dailyCheckInRewardPoints, 100);
    expect(
      dailyTaskSpecs.where((task) => task.key != 'check-in').map(
            (task) => task.points,
          ),
      everyElement(20),
    );
  });

  testWidgets('home loads wallet balance without showing header points',
      (tester) async {
    final requests = <http.Request>[];
    final apiClient = _walletClient(requests: requests, balance: 5000);

    await tester.pumpWidget(
      _testShell(
        HomeScreen(
          onNavigate: (_) {},
          boardConnected: false,
          boardModel: ChessnutBoardModel.unknown,
          dailyClaimService: DailyClaimService(
            store: InMemoryDailyClaimStore(),
          ),
          apiClient: apiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-points-pill')), findsNothing);
    expect(
        find.byKey(const ValueKey('home-points-guest-locked')), findsNothing);
    expect(find.text('5000'), findsNothing);
    expect(find.text('5,000'), findsNothing);
    expect(
      requests.where((request) => request.url.path == '/api/wallet/balance'),
      hasLength(1),
    );
  });

  testWidgets('home hides compact header balance for five-digit wallets',
      (tester) async {
    final requests = <http.Request>[];
    final apiClient = _walletClient(requests: requests, balance: 12500);

    await tester.pumpWidget(
      _testShell(
        HomeScreen(
          onNavigate: (_) {},
          boardConnected: false,
          boardModel: ChessnutBoardModel.unknown,
          dailyClaimService: DailyClaimService(
            store: InMemoryDailyClaimStore(),
          ),
          apiClient: apiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-points-pill')), findsNothing);
    expect(find.text('1.3W'), findsNothing);
    expect(find.text('12,500'), findsNothing);
    expect(find.text('12500'), findsNothing);
  });

  testWidgets('home header no longer pins a points pill to the right edge',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <http.Request>[];
    final apiClient = _walletClient(requests: requests, balance: 1376);

    await tester.pumpWidget(
      _testShell(
        HomeScreen(
          onNavigate: (_) {},
          boardConnected: false,
          boardModel: ChessnutBoardModel.unknown,
          dailyClaimService: DailyClaimService(
            store: InMemoryDailyClaimStore(),
          ),
          apiClient: apiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byKey(const ValueKey('home-points-pill')), findsNothing);
  });

  testWidgets('home daily tasks card reflects wallet task progress',
      (tester) async {
    final requests = <http.Request>[];
    final apiClient = _walletClient(
      requests: requests,
      claimedToday: true,
      claimedTaskKeys: const ['puzzle', 'share-report'],
    );

    await tester.pumpWidget(
      _testShell(
        HomeScreen(
          onNavigate: (_) {},
          boardConnected: false,
          boardModel: ChessnutBoardModel.unknown,
          dailyClaimService: DailyClaimService(
            store: InMemoryDailyClaimStore(),
          ),
          apiClient: apiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3/6 done'), findsOneWidget);
    expect(find.text('0/5 done'), findsNothing);
    expect(
      requests.where((request) => request.url.path == '/api/wallet/balance'),
      hasLength(1),
    );
  });

  testWidgets('account wallet card uses backend balance', (tester) async {
    final requests = <http.Request>[];
    final apiClient = _walletClient(
      requests: requests,
      balance: 1376,
      ledger: const [
        {
          'id': '1',
          'title': 'Daily check-in',
          'amount': 100,
          'created_at': '2026-05-20T08:00:00Z',
          'type': 'daily',
        },
      ],
    );

    await tester.pumpWidget(
      _testShell(
        AccountScreen(
          onNavigate: (_) {},
          apiClient: apiClient,
          session: _session,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1,376'), findsOneWidget);
    expect(find.text('1,240'), findsNothing);
    expect(find.text('Online'), findsNothing);
    expect(
      requests.where((request) => request.url.path == '/api/wallet/balance'),
      hasLength(1),
    );
  });

  testWidgets('account hero shows active membership without renewal entry',
      (tester) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <http.Request>[];
    final apiClient = _walletClient(
      requests: requests,
      balance: 1376,
      memberActive: true,
      memberExpireAt: '2027-08-24T10:30:00Z',
    );

    await tester.pumpWidget(
      _testShell(
        AccountScreen(
          onNavigate: (_) {},
          apiClient: apiClient,
          session: _session,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('account-vip-badge')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('account-vip-badge')),
        matching: find.byIcon(Icons.bolt_rounded),
      ),
      findsNothing,
    );
    expect(find.text('Valid until 2027/08/24'), findsWidgets);
    expect(find.text('Renew membership'), findsNothing);
    expect(find.text('Upgrade membership'), findsNothing);

    final memberStatus = tester.widget<InkWell>(
      find.byKey(const ValueKey('account-member-status')),
    );
    expect(memberStatus.onTap, isNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('account-member-status')),
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsNothing,
    );
    expect(find.text('Chessnut Premium'), findsNothing);
  });

  testWidgets('account membership expiry stays below long usernames',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <http.Request>[];
    final apiClient = _walletClient(
      requests: requests,
      balance: 1376,
      memberActive: true,
      memberExpireAt: '2027-08-24',
    );

    await tester.pumpWidget(
      _testShell(
        AccountScreen(
          onNavigate: (_) {},
          apiClient: apiClient,
          session: _session.copyWith(
            username: 'Chessnut Player With A Very Very Long Display Name',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final vipRect =
        tester.getRect(find.byKey(const ValueKey('account-vip-badge')));
    final memberRect =
        tester.getRect(find.byKey(const ValueKey('account-member-status')));

    expect(find.byKey(const ValueKey('account-vip-badge')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-member-status')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('account-member-status')),
        matching: find.text('Valid until 2027/08/24'),
      ),
      findsOneWidget,
    );
    expect(memberRect.top, greaterThan(vipRect.bottom));
    expect(memberRect.right, lessThanOrEqualTo(390));
  });

  testWidgets('points screen empty ledger stays empty instead of fake entries',
      (tester) async {
    final requests = <http.Request>[];
    final apiClient = _walletClient(requests: requests, balance: 1376);

    await tester.pumpWidget(
      _testShell(
        PointsScreen(
          onNavigate: (_) {},
          apiClient: apiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1,376'), findsOneWidget);
    expect(find.text('No point activity yet.'), findsOneWidget);
    expect(find.text('Online game'), findsNothing);
    expect(find.text('Puzzle solved'), findsNothing);
    expect(find.text('Engine Model Build'), findsNothing);
  });

  testWidgets('points screen hides local wallet tester by default',
      (tester) async {
    final requests = <http.Request>[];
    final apiClient = _walletClient(
      requests: requests,
      balance: 1376,
      baseUri: Uri.parse('http://127.0.0.1:8888'),
    );

    await tester.pumpWidget(
      _testShell(
        PointsScreen(
          onNavigate: (_) {},
          apiClient: apiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local QA wallet tools'), findsNothing);
    expect(find.byKey(const ValueKey('wallet-debug-add-100')), findsNothing);
  });

  testWidgets('points screen local wallet tester requires explicit dev flag',
      (tester) async {
    final requests = <http.Request>[];
    final apiClient = _walletClient(
      requests: requests,
      balance: 1376,
      baseUri: Uri.parse('http://127.0.0.1:8888'),
    );

    await tester.pumpWidget(
      _testShell(
        PointsScreen(
          onNavigate: (_) {},
          apiClient: apiClient,
          walletDebugToolsEnabled: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local QA wallet tools'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wallet-debug-add-100')));
    await tester.pumpAndSettle();

    final adjustRequests = requests
        .where((request) => request.url.path == '/api/wallet/debugAdjust')
        .toList();
    expect(adjustRequests, hasLength(1));
    expect(adjustRequests.single.bodyFields['amount'], '100');
    expect(adjustRequests.single.bodyFields['reason'], 'debug_adjust');
    expect(find.text('1,476'), findsOneWidget);
  });

  testWidgets('points screen hides local wallet tester on production API',
      (tester) async {
    final requests = <http.Request>[];
    final apiClient = _walletClient(
      requests: requests,
      baseUri: Uri.parse('https://api.chessnutech.com'),
    );

    await tester.pumpWidget(
      _testShell(
        PointsScreen(
          onNavigate: (_) {},
          apiClient: apiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local QA wallet tools'), findsNothing);
  });

  testWidgets('account wallet empty ledger has localized empty copy',
      (tester) async {
    final requests = <http.Request>[];
    final apiClient = _walletClient(requests: requests, balance: 0);

    await tester.pumpWidget(
      _localizedTestShell(
        PointsScreen(
          onNavigate: (_) {},
          apiClient: apiClient,
        ),
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无积分记录。'), findsOneWidget);
    expect(find.text('???????'), findsNothing);
  });

  testWidgets('signed-in daily claim 404 does not mark local claim complete',
      (tester) async {
    final requests = <http.Request>[];
    final apiClient = ChessnutApiClient(
      session: _session,
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('not found', 404);
      }),
    );
    final claimService = DailyClaimService(store: InMemoryDailyClaimStore());

    await tester.pumpWidget(
      _testShell(
        DailyTasksScreen(
          onNavigate: (_) {},
          dailyClaimService: claimService,
          apiClient: apiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('daily-task-check-in')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      requests.where((request) => request.url.path == '/api/wallet/claimDaily'),
      hasLength(1),
    );
    expect(claimService.status().canClaim, isTrue);
    expect(find.text('Claim'), findsWidgets);
    expect(find.text('Claimed'), findsNothing);
  });

  testWidgets('signed-in daily tasks use wallet balance claim state and reward',
      (tester) async {
    final requests = <http.Request>[];
    final apiClient = _walletClient(
      requests: requests,
      dailyClaimPoints: 120,
      claimedToday: true,
    );

    await tester.pumpWidget(
      _testShell(
        DailyTasksScreen(
          onNavigate: (_) {},
          dailyClaimService:
              DailyClaimService(store: InMemoryDailyClaimStore()),
          apiClient: apiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      requests.where((request) => request.url.path == '/api/wallet/balance'),
      hasLength(1),
    );
    expect(find.text('+120'), findsNothing);
    expect(find.text('+5'), findsNothing);
    expect(find.text('+10'), findsNothing);
    expect(find.text('+20'), findsWidgets);
    expect(find.text('+50'), findsNothing);
    expect(find.text('+100'), findsWidgets);
    expect(find.text('Claimed'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('daily-task-check-in')),
        matching: find.text('Claim'),
      ),
      findsNothing,
    );
  });

  testWidgets(
      'signed-in daily check-in locks and refreshes header points immediately',
      (tester) async {
    final requests = <http.Request>[];
    final snapshots = <DailyTaskStateSnapshot>[];
    final apiClient = _walletClient(
      requests: requests,
      dailyClaimPoints: 100,
      claimedToday: false,
      claimDailyReturnsClaimedToday: false,
    );

    await tester.pumpWidget(
      _testShell(
        DailyTasksScreen(
          onNavigate: (_) {},
          dailyClaimService:
              DailyClaimService(store: InMemoryDailyClaimStore()),
          apiClient: apiClient,
          onDailyTaskStateChanged: snapshots.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0 / 6'), findsOneWidget);
    expect(find.text('1,376 pts'), findsOneWidget);
    expect(find.text('0/6 done'), findsNothing);
    expect(find.text('Claim'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('daily-task-check-in')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      requests.where((request) => request.url.path == '/api/wallet/claimDaily'),
      hasLength(1),
    );
    expect(
      requests
          .singleWhere(
            (request) => request.url.path == '/api/wallet/claimDaily',
          )
          .bodyFields['points'],
      '100',
    );
    expect(find.text('1 / 6'), findsOneWidget);
    expect(find.text('1/6 done'), findsNothing);
    expect(find.text('1,476 pts'), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet-credit-burst')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('wallet-credit-burst')),
        matching: find.text('+100'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('daily-task-check-in')),
        matching: find.text('Claimed'),
      ),
      findsWidgets,
    );
    expect(find.text('Daily check-in +100 points'), findsOneWidget);
    expect(snapshots.last.claimedToday, isTrue);
    expect(snapshots.last.walletBalance, 1476);
    expect(snapshots.last.claimedTaskKeys, isEmpty);
    await tester.pumpAndSettle();
  });

  testWidgets('daily check-in normalizes backend over-grant reward',
      (tester) async {
    final requests = <http.Request>[];
    final snapshots = <DailyTaskStateSnapshot>[];
    final apiClient = _walletClient(
      requests: requests,
      dailyClaimPoints: 100,
      remoteDailyPointsAdded: 120,
      claimedToday: false,
    );

    await tester.pumpWidget(
      _testShell(
        DailyTasksScreen(
          onNavigate: (_) {},
          dailyClaimService:
              DailyClaimService(store: InMemoryDailyClaimStore()),
          apiClient: apiClient,
          onDailyTaskStateChanged: snapshots.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('daily-task-check-in')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      requests
          .singleWhere(
            (request) => request.url.path == '/api/wallet/claimDaily',
          )
          .bodyFields['points'],
      '100',
    );
    expect(find.text('1,476 pts'), findsOneWidget);
    expect(find.text('1,496 pts'), findsNothing);
    expect(find.text('Daily check-in +100 points'), findsOneWidget);
    expect(find.text('Daily check-in +120 points'), findsNothing);
    expect(snapshots.last.walletBalance, 1476);

    final refreshed = await apiClient.walletBalance();
    expect(refreshed.data?.balance, 1476);
    await tester.pumpAndSettle();
  });

  testWidgets('signed-in non-check-in daily task navigates without claiming',
      (tester) async {
    final requests = <http.Request>[];
    final apiClient = _walletClient(requests: requests);
    final navigations = <String>[];

    await tester.pumpWidget(
      _testShell(
        DailyTasksScreen(
          onNavigate: navigations.add,
          dailyClaimService:
              DailyClaimService(store: InMemoryDailyClaimStore()),
          apiClient: apiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final puzzleTask = find.byKey(const ValueKey('daily-task-puzzle'));
    await tester.ensureVisible(puzzleTask);
    await tester.pumpAndSettle();
    await tester.tap(puzzleTask);
    await tester.pumpAndSettle();

    final taskRequests = requests
        .where((request) => request.url.path == '/api/wallet/claimTask')
        .toList();
    expect(taskRequests, isEmpty);
    expect(navigations, contains('Training'));
    expect(
      find.descendant(of: puzzleTask, matching: find.text('Go')),
      findsOneWidget,
    );
  });

  testWidgets('career challenge and share report route to separate workflows',
      (tester) async {
    final requests = <http.Request>[];
    final apiClient = _walletClient(requests: requests);
    final navigations = <String>[];

    await tester.pumpWidget(
      _testShell(
        DailyTasksScreen(
          onNavigate: navigations.add,
          dailyClaimService:
              DailyClaimService(store: InMemoryDailyClaimStore()),
          apiClient: apiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Complete one Career challenge'), findsOneWidget);
    expect(find.text('Share one game'), findsNothing);
    expect(find.text('Share one report'), findsOneWidget);

    final careerTask = find.byKey(const ValueKey('daily-task-career'));
    await tester.ensureVisible(careerTask);
    await tester.pumpAndSettle();
    await tester.tap(careerTask);
    await tester.pumpAndSettle();

    final reportShareTask =
        find.byKey(const ValueKey('daily-task-share-report'));
    await tester.ensureVisible(reportShareTask);
    await tester.pumpAndSettle();
    await tester.tap(reportShareTask);
    await tester.pumpAndSettle();

    final taskRequests = requests
        .where((request) => request.url.path == '/api/wallet/claimTask')
        .toList();
    expect(taskRequests, isEmpty);
    expect(navigations, containsAllInOrder(['Career', 'Analysis']));
  });
}
