import 'package:in_app_purchase/in_app_purchase.dart';

import '../../models/support_tier.dart';

/// Thin wrapper around [InAppPurchase] that owns all store I/O. The provider
/// layer orchestrates state transitions and persistence on top of this.
class SubscriptionService {
  SubscriptionService({InAppPurchase? iap})
      : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  /// Stream of purchase updates delivered by the platform. The provider
  /// subscribes to this and drives state from it.
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  Future<bool> isAvailable() => _iap.isAvailable();

  /// Queries StoreKit (or Play Billing) for the three Support tier products.
  Future<ProductDetailsResponse> queryProducts() =>
      _iap.queryProductDetails(SupportTier.allProductIds);

  /// Auto-renewable subscriptions use [buyNonConsumable] per the
  /// `in_app_purchase` API contract. Returns false if the platform
  /// immediately refuses the request.
  Future<bool> buy(ProductDetails product) {
    final param = PurchaseParam(productDetails: product);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Triggers a restore pass. Existing purchases are delivered back through
  /// [purchaseStream] with [PurchaseStatus.restored].
  Future<void> restore() => _iap.restorePurchases();

  /// StoreKit requires every delivered [PurchaseDetails] with
  /// `pendingCompletePurchase == true` be completed, otherwise the transaction
  /// keeps re-appearing on the queue.
  Future<void> complete(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);
}
