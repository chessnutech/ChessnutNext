import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'chessnut_api_client.dart';

class MembershipPurchaseOutcome {
  const MembershipPurchaseOutcome({
    required this.success,
    required this.message,
    this.verification,
  });

  final bool success;
  final String message;
  final MembershipVerificationResult? verification;
}

abstract class MembershipPurchaseService {
  Future<MembershipPurchaseOutcome> purchase(
    MembershipProduct product,
    ChessnutApiClient apiClient,
  );

  Future<MembershipPurchaseOutcome> restore(ChessnutApiClient apiClient);
}

class MembershipPurchaseMessages {
  const MembershipPurchaseMessages._();

  static const signInBeforeUpgrade = 'Sign in before upgrading membership.';
  static const signInBeforeRestore = 'Sign in before restoring purchases.';
  static const unsupportedPlatform =
      'In-app purchase is available on iOS and Android.';
  static const restoreUnsupportedPlatform =
      'Restore purchase is available on iOS and Android.';
  static const storeUnavailable =
      'Store purchase is unavailable on this device. Install the official test or store version, sign in to the store, then try again.';
  static const productUnavailable =
      'This Premium plan is not available in the store yet. Try another plan or come back later.';
  static const purchaseStartFailed =
      'The store could not start this purchase. Check your store account and payment setup, then try again.';
  static const purchaseCanceled =
      'Purchase canceled. Your membership was not changed.';
  static const purchaseNotCompleted =
      'Purchase was not completed. You can try again when ready.';
  static const purchasePending =
      'Purchase is still pending. Check your store account later.';
  static const restoreNotFound =
      'No active membership purchase was found for this store account.';
  static const premiumActive = 'Premium is active.';
  static const verificationFailed =
      'Purchase verification failed. Check your network and try Restore purchase.';

  static String purchaseFailed(String? storeMessage) {
    final message = storeMessage?.trim();
    if (message == null || message.isEmpty) {
      return 'Purchase failed. Check your store account and try again.';
    }
    return 'Purchase failed. Check your store account and try again.';
  }

  static String restoreFailed(Object error) =>
      'Restore failed. Check your store account and try again.';
}

abstract class MembershipStoreGateway {
  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<bool> isAvailable();

  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);

  Future<bool> buy({
    required ProductDetails details,
    required String platform,
  });

  Future<void> completePurchase(PurchaseDetails purchase);

  Future<void> restorePurchases();
}

class InAppPurchaseMembershipStoreGateway implements MembershipStoreGateway {
  InAppPurchaseMembershipStoreGateway([InAppPurchase? inAppPurchase])
      : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  final InAppPurchase _inAppPurchase;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _inAppPurchase.purchaseStream;

  @override
  Future<bool> isAvailable() => _inAppPurchase.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) {
    return _inAppPurchase.queryProductDetails(identifiers);
  }

  @override
  Future<bool> buy({
    required ProductDetails details,
    required String platform,
  }) {
    return _inAppPurchase.buyNonConsumable(
      purchaseParam: _purchaseParamForPlatform(details, platform),
    );
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) {
    return _inAppPurchase.completePurchase(purchase);
  }

  @override
  Future<void> restorePurchases() => _inAppPurchase.restorePurchases();

  PurchaseParam _purchaseParamForPlatform(
    ProductDetails details,
    String platform,
  ) {
    if (platform == 'android' && details is GooglePlayProductDetails) {
      return GooglePlayPurchaseParam(
        productDetails: details,
        offerToken: details.offerToken,
      );
    }
    return PurchaseParam(productDetails: details);
  }
}

class StoreMembershipPurchaseService implements MembershipPurchaseService {
  StoreMembershipPurchaseService({
    InAppPurchase? inAppPurchase,
    MembershipStoreGateway? storeGateway,
    Duration purchaseResultTimeout = const Duration(seconds: 30),
    String? platformOverride,
  })  : _storeGateway =
            storeGateway ?? InAppPurchaseMembershipStoreGateway(inAppPurchase),
        _purchaseResultTimeout = purchaseResultTimeout,
        _platformOverride = platformOverride;

  final MembershipStoreGateway _storeGateway;
  final Duration _purchaseResultTimeout;
  final String? _platformOverride;

  @override
  Future<MembershipPurchaseOutcome> purchase(
    MembershipProduct product,
    ChessnutApiClient apiClient,
  ) async {
    if (apiClient.session == null) {
      return const MembershipPurchaseOutcome(
        success: false,
        message: MembershipPurchaseMessages.signInBeforeUpgrade,
      );
    }
    final platform = _purchasePlatform(_platformOverride);
    if (platform == 'unknown') {
      return const MembershipPurchaseOutcome(
        success: false,
        message: MembershipPurchaseMessages.unsupportedPlatform,
      );
    }

    final available = await _storeGateway.isAvailable();
    if (!available) {
      return const MembershipPurchaseOutcome(
        success: false,
        message: MembershipPurchaseMessages.storeUnavailable,
      );
    }

    final details = await _productDetails(product.platformProductId);
    if (details == null) {
      return const MembershipPurchaseOutcome(
        success: false,
        message: MembershipPurchaseMessages.productUnavailable,
      );
    }

    final completer = Completer<MembershipPurchaseOutcome>();
    late final StreamSubscription<List<PurchaseDetails>> subscription;
    subscription = _storeGateway.purchaseStream.listen(
      (purchases) async {
        for (final purchase in purchases) {
          if (purchase.productID != product.platformProductId) continue;
          if (purchase.status == PurchaseStatus.pending) continue;
          if (purchase.status == PurchaseStatus.error) {
            if (!completer.isCompleted) {
              completer.complete(MembershipPurchaseOutcome(
                success: false,
                message: MembershipPurchaseMessages.purchaseFailed(
                  purchase.error?.message,
                ),
              ));
            }
            continue;
          }
          if (purchase.status == PurchaseStatus.canceled) {
            if (!completer.isCompleted) {
              completer.complete(const MembershipPurchaseOutcome(
                success: false,
                message: MembershipPurchaseMessages.purchaseCanceled,
              ));
            }
            continue;
          }
          if (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored) {
            final verified =
                await _verifyPurchase(product, purchase, apiClient);
            if (purchase.pendingCompletePurchase) {
              await _storeGateway.completePurchase(purchase);
            }
            if (!completer.isCompleted) completer.complete(verified);
          }
        }
      },
      onError: (Object error) {
        if (!completer.isCompleted) {
          completer.complete(MembershipPurchaseOutcome(
            success: false,
            message: MembershipPurchaseMessages.purchaseFailed(
              error.toString(),
            ),
          ));
        }
      },
    );

    final started = await _storeGateway.buy(
      details: details,
      platform: platform,
    );
    if (!started) {
      await subscription.cancel();
      return const MembershipPurchaseOutcome(
        success: false,
        message: MembershipPurchaseMessages.purchaseStartFailed,
      );
    }

    final outcome = await completer.future.timeout(
      _purchaseResultTimeout,
      onTimeout: () => const MembershipPurchaseOutcome(
        success: false,
        message: MembershipPurchaseMessages.purchaseNotCompleted,
      ),
    );
    await subscription.cancel();
    return outcome;
  }

  @override
  Future<MembershipPurchaseOutcome> restore(ChessnutApiClient apiClient) async {
    if (apiClient.session == null) {
      return const MembershipPurchaseOutcome(
        success: false,
        message: MembershipPurchaseMessages.signInBeforeRestore,
      );
    }
    if (_purchasePlatform(_platformOverride) == 'unknown') {
      return const MembershipPurchaseOutcome(
        success: false,
        message: MembershipPurchaseMessages.restoreUnsupportedPlatform,
      );
    }

    final completer = Completer<MembershipPurchaseOutcome>();
    late final StreamSubscription<List<PurchaseDetails>> subscription;
    subscription = _storeGateway.purchaseStream.listen(
      (purchases) async {
        for (final purchase in purchases) {
          if (purchase.status != PurchaseStatus.restored &&
              purchase.status != PurchaseStatus.purchased) {
            continue;
          }
          final product = _productFromPlatformId(purchase.productID);
          if (product == null) continue;
          final verified = await _verifyPurchase(product, purchase, apiClient);
          if (purchase.pendingCompletePurchase) {
            await _storeGateway.completePurchase(purchase);
          }
          if (!completer.isCompleted) completer.complete(verified);
        }
      },
      onError: (Object error) {
        if (!completer.isCompleted) {
          completer.complete(MembershipPurchaseOutcome(
            success: false,
            message: MembershipPurchaseMessages.restoreFailed(error),
          ));
        }
      },
    );

    await _storeGateway.restorePurchases();
    final outcome = await completer.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () => const MembershipPurchaseOutcome(
        success: false,
        message: MembershipPurchaseMessages.restoreNotFound,
      ),
    );
    await subscription.cancel();
    return outcome;
  }

  Future<ProductDetails?> _productDetails(String productId) async {
    final response = await _storeGateway.queryProductDetails({productId});
    if (response.error != null || response.productDetails.isEmpty) return null;
    return response.productDetails.first;
  }

  Future<MembershipPurchaseOutcome> _verifyPurchase(
    MembershipProduct product,
    PurchaseDetails purchase,
    ChessnutApiClient apiClient,
  ) async {
    final platform = _purchasePlatform(_platformOverride);
    final result = await apiClient.verifyMembershipPurchase(
      platform: platform,
      productId: product.platformProductId,
      receipt: purchase.verificationData.serverVerificationData,
      transactionId: platform == 'ios' ? purchase.purchaseID ?? '' : '',
      purchaseToken: platform == 'android'
          ? purchase.verificationData.serverVerificationData
          : '',
    );
    if (!result.isSuccess || result.data == null) {
      return MembershipPurchaseOutcome(
        success: false,
        message: result.status.errorMessage ??
            MembershipPurchaseMessages.verificationFailed,
      );
    }
    return MembershipPurchaseOutcome(
      success: true,
      message: MembershipPurchaseMessages.premiumActive,
      verification: result.data,
    );
  }
}

String membershipPurchaseDiagnosticMessage({
  required String stage,
  required String platform,
  required String productId,
  bool? storeAvailable,
  Iterable<String> notFoundIds = const <String>[],
  String? errorMessage,
}) {
  final parts = [
    'Membership IAP',
    'stage=$stage',
    'platform=$platform',
    'productId=$productId',
    if (storeAvailable != null) 'storeAvailable=$storeAvailable',
    if (notFoundIds.isNotEmpty) 'notFoundIds=${notFoundIds.join(',')}',
    if (errorMessage != null && errorMessage.trim().isNotEmpty)
      'error=${_redactMembershipDiagnostic(errorMessage.trim())}',
  ];
  return parts.join(' ');
}

String _redactMembershipDiagnostic(String value) {
  return value.replaceAll(
    RegExp(
      r'\b(?:purchase[_-]?token|receipt|transaction[_-]?receipt|serverVerificationData)\b\s*[:=]\s*\S+',
      caseSensitive: false,
    ),
    '[redacted]',
  );
}

String _purchasePlatform([String? platformOverride]) {
  final override = platformOverride?.trim().toLowerCase();
  if (override == 'ios' || override == 'android' || override == 'unknown') {
    return override!;
  }
  if (!kIsWeb && Platform.isIOS) return 'ios';
  if (!kIsWeb && Platform.isAndroid) return 'android';
  return 'unknown';
}

MembershipProduct? _productFromPlatformId(String platformProductId) {
  for (final product in fallbackMembershipProducts) {
    if (product.platformProductId == platformProductId) return product;
  }
  return null;
}

const fallbackMembershipProducts = [
  MembershipProduct(
    id: 'premium_yearly_auto',
    title: 'Premium Yearly',
    price: '99.99',
    priceCents: 9999,
    currency: 'USD',
    period: 'year',
    renewing: true,
    durationMonths: 12,
    platformProductId: 'chessnut_premium_yearly_auto',
    recommended: true,
  ),
  MembershipProduct(
    id: 'premium_yearly_non_auto',
    title: 'Premium Yearly One-Time',
    price: '169.99',
    priceCents: 16999,
    currency: 'USD',
    period: 'year',
    renewing: false,
    durationMonths: 12,
    platformProductId: 'chessnut_premium_yearly_non_auto',
    recommended: false,
  ),
  MembershipProduct(
    id: 'premium_monthly_auto',
    title: 'Premium Monthly',
    price: '19.99',
    priceCents: 1999,
    currency: 'USD',
    period: 'month',
    renewing: true,
    durationMonths: 1,
    platformProductId: 'chessnut_premium_monthly_auto',
    recommended: true,
  ),
  MembershipProduct(
    id: 'premium_monthly_non_auto',
    title: 'Premium Monthly One-Time',
    price: '29.99',
    priceCents: 2999,
    currency: 'USD',
    period: 'month',
    renewing: false,
    durationMonths: 1,
    platformProductId: 'chessnut_premium_monthly_non_auto',
    recommended: false,
  ),
];
