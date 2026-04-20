import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/subscription_state.dart';
import '../models/support_tier.dart';
import '../services/storage/storage_service.dart';
import '../services/subscription/subscription_service.dart';
import 'storage_provider.dart';

/// Provides the [SubscriptionService] singleton. Tests override this with a
/// fake to intercept store I/O.
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});

/// Provides the current Support subscription state.
final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionState>(
        SubscriptionNotifier.new);

class SubscriptionNotifier extends Notifier<SubscriptionState> {
  static const _fileName = 'subscription.json';
  static const Duration _assumedPeriod = Duration(days: 31);

  StreamSubscription<List<PurchaseDetails>>? _streamSub;

  @override
  SubscriptionState build() {
    ref.onDispose(() => _streamSub?.cancel());

    // Screenshot seed mode short-circuits all store I/O with deterministic
    // data so App Store capture runs are reproducible.
    if (kIsSubscriptionSeeded) {
      return _seedState();
    }

    if (kIsWeb) {
      return const SubscriptionState(
        loading: false,
        storeAvailable: false,
      );
    }

    // Kick off async init without blocking build().
    Future.microtask(_init);
    return const SubscriptionState(loading: true);
  }

  Future<void> _init() async {
    await _hydrateFromStorage();

    final svc = ref.read(subscriptionServiceProvider);
    final available = await svc.isAvailable();
    if (!available) {
      state = state.copyWith(loading: false, storeAvailable: false);
      return;
    }

    _streamSub = svc.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) {
        state = state.copyWith(error: e.toString());
      },
    );

    final resp = await svc.queryProducts();
    state = state.copyWith(
      loading: false,
      storeAvailable: true,
      products: resp.productDetails,
      error: resp.error?.message,
      clearError: resp.error == null,
    );

    // Re-hydrate any active subscription from the platform in case the local
    // copy was wiped (reinstall, new device restore).
    try {
      await svc.restore();
    } catch (e) {
      debugPrint('SubscriptionNotifier._init restore: $e');
    }
  }

  /// Kick off a purchase flow for [tier]. Returns immediately; resolution is
  /// delivered through the purchase stream.
  Future<void> purchase(SupportTier tier) async {
    final product = state.productFor(tier);
    if (product == null) {
      state = state.copyWith(error: 'Product not loaded: ${tier.productId}');
      return;
    }
    state = state.copyWith(
      pendingPurchase: true,
      purchasingTier: tier,
      clearError: true,
    );
    try {
      final svc = ref.read(subscriptionServiceProvider);
      final accepted = await svc.buy(product);
      if (!accepted) {
        state = state.copyWith(
          pendingPurchase: false,
          clearPurchasingTier: true,
          error: 'Purchase request was declined by the store.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        pendingPurchase: false,
        clearPurchasingTier: true,
        error: e.toString(),
      );
    }
  }

  /// Ask the platform to replay existing purchases through the stream.
  Future<void> restore() async {
    state = state.copyWith(pendingPurchase: true, clearError: true);
    try {
      final svc = ref.read(subscriptionServiceProvider);
      await svc.restore();
    } catch (e) {
      state = state.copyWith(
        pendingPurchase: false,
        clearPurchasingTier: true,
        error: e.toString(),
      );
    }
  }

  /// Retry from a failed [_init] (e.g. after transient "store unavailable").
  Future<void> retry() async {
    state = const SubscriptionState(loading: true);
    await _streamSub?.cancel();
    _streamSub = null;
    await _init();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    final svc = ref.read(subscriptionServiceProvider);
    for (final purchase in purchases) {
      final tier = SupportTier.fromProductId(purchase.productID);
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = state.copyWith(pendingPurchase: true, purchasingTier: tier);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (tier != null) {
            final expiry = DateTime.now().add(_assumedPeriod);
            state = state.copyWith(
              pendingPurchase: false,
              clearPurchasingTier: true,
              activeTier: tier,
              expiryDate: expiry,
              clearError: true,
            );
            await _persist();
          } else {
            state = state.copyWith(
              pendingPurchase: false,
              clearPurchasingTier: true,
            );
          }
          break;
        case PurchaseStatus.error:
          state = state.copyWith(
            pendingPurchase: false,
            clearPurchasingTier: true,
            error: purchase.error?.message ?? 'Purchase failed.',
          );
          break;
        case PurchaseStatus.canceled:
          state = state.copyWith(
            pendingPurchase: false,
            clearPurchasingTier: true,
            clearError: true,
          );
          break;
      }
      if (purchase.pendingCompletePurchase) {
        try {
          await svc.complete(purchase);
        } catch (e) {
          debugPrint('SubscriptionNotifier.complete: $e');
        }
      }
    }
  }

  Future<void> _hydrateFromStorage() async {
    try {
      final storage = _storage();
      if (storage == null) return;
      final raw = await storage.readFile(_fileName);
      if (raw.trim().isEmpty) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final tierId = json['activeTier'] as String?;
      final expiryMs = (json['expiryEpochMs'] as num?)?.toInt();
      final tier = tierId != null ? SupportTier.fromProductId(tierId) : null;
      final expiry = expiryMs != null
          ? DateTime.fromMillisecondsSinceEpoch(expiryMs)
          : null;
      if (tier != null && (expiry == null || expiry.isAfter(DateTime.now()))) {
        state = state.copyWith(activeTier: tier, expiryDate: expiry);
      }
    } catch (e) {
      debugPrint('SubscriptionNotifier._hydrateFromStorage: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final storage = _storage();
      if (storage == null) return;
      final tier = state.activeTier;
      if (tier == null) {
        await storage.writeFile(_fileName, '{}');
        return;
      }
      final json = <String, dynamic>{
        'activeTier': tier.productId,
        if (state.expiryDate != null)
          'expiryEpochMs': state.expiryDate!.millisecondsSinceEpoch,
      };
      await storage.writeFile(_fileName, jsonEncode(json));
    } catch (e) {
      debugPrint('SubscriptionNotifier._persist: $e');
    }
  }

  StorageService? _storage() {
    try {
      return ref.read(storageServiceProvider);
    } catch (_) {
      return null;
    }
  }

  SubscriptionState _seedState() {
    final seeded = [
      for (final tier in SupportTier.values)
        ProductDetails(
          id: tier.productId,
          title: tier.displayName,
          description: tier.blurb,
          price: tier.fallbackPrice,
          rawPrice: double.parse(
              tier.fallbackPrice.replaceAll(RegExp(r'[^0-9.]'), '')),
          currencyCode: 'USD',
        ),
    ];
    final activate = kSubscriptionSeedMode == 'active';
    return SubscriptionState(
      loading: false,
      storeAvailable: true,
      products: seeded,
      activeTier: activate ? SupportTier.medium : null,
      expiryDate: activate ? DateTime.now().add(_assumedPeriod) : null,
    );
  }
}
