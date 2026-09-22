import 'dart:async';
import 'package:chessnut_flutter_export/services/membership_purchase_service.dart';
import 'package:chessnut_flutter_export/services/chessnut_api_client.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('store purchase failure copy tells user what to fix next', () {
    expect(
      MembershipPurchaseMessages.storeUnavailable,
      'Store purchase is unavailable on this device. Install the official test or store version, sign in to the store, then try again.',
    );
    expect(
      MembershipPurchaseMessages.productUnavailable,
      'This Premium plan is not available in the store yet. Try another plan or come back later.',
    );
    expect(
      MembershipPurchaseMessages.purchaseStartFailed,
      'The store could not start this purchase. Check your store account and payment setup, then try again.',
    );
  });

  test('store diagnostics avoid receipt data and show setup clues', () {
    final message = membershipPurchaseDiagnosticMessage(
      stage: 'queryProductDetails',
      platform: 'android',
      productId: 'chessnut_premium_yearly_auto',
      storeAvailable: true,
      notFoundIds: const ['chessnut_premium_yearly_auto'],
      errorMessage:
          'ITEM_UNAVAILABLE purchaseToken=abc123 receipt: secret-data',
    );

    expect(message, contains('stage=queryProductDetails'));
    expect(message, contains('platform=android'));
    expect(message, contains('productId=chessnut_premium_yearly_auto'));
    expect(message, contains('storeAvailable=true'));
    expect(message, contains('notFoundIds=chessnut_premium_yearly_auto'));
    expect(message, contains('error=ITEM_UNAVAILABLE'));
    expect(message, contains('[redacted]'));
    expect(message, isNot(contains('purchaseToken')));
    expect(message, isNot(contains('receipt')));
    expect(message, isNot(contains('abc123')));
    expect(message, isNot(contains('secret-data')));
  });

  test('store purchase releases UI when the store sheet closes silently',
      () async {
    final storeGateway = _SilentPurchaseStoreGateway();
    addTearDown(storeGateway.dispose);

    final service = StoreMembershipPurchaseService(
      storeGateway: storeGateway,
      purchaseResultTimeout: const Duration(milliseconds: 25),
      platformOverride: 'android',
    );
    final outcome = await service.purchase(
      fallbackMembershipProducts.first,
      ChessnutApiClient(
        session: const ChessnutApiSession(
          userId: 7,
          token: '12345678901234567890123456789012',
        ),
      ),
    );

    expect(outcome.success, isFalse);
    expect(outcome.message, MembershipPurchaseMessages.purchaseNotCompleted);
    expect(storeGateway.buyStarted, isTrue);
  });
}

class _SilentPurchaseStoreGateway implements MembershipStoreGateway {
  final _controller = StreamController<List<PurchaseDetails>>.broadcast();
  bool buyStarted = false;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    return ProductDetailsResponse(
      productDetails: [
        ProductDetails(
          id: identifiers.first,
          title: 'Premium',
          description: 'Premium test plan',
          price: r'$19.99',
          rawPrice: 19.99,
          currencyCode: 'USD',
          currencySymbol: r'$',
        ),
      ],
      notFoundIDs: const [],
    );
  }

  @override
  Future<bool> buy({
    required ProductDetails details,
    required String platform,
  }) async {
    buyStarted = true;
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> restorePurchases() async {}

  void dispose() {
    _controller.close();
  }
}
