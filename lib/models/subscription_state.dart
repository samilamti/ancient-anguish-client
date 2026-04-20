import 'package:equatable/equatable.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'support_tier.dart';

/// Compile-time flag that forces deterministic seed data for screenshots.
/// Values:
///   - empty (default) → normal store I/O
///   - 'hero'          → three products loaded, no tier active
///   - 'active'        → three products loaded, Medium tier active
const String kSubscriptionSeedMode =
    String.fromEnvironment('AA_SUB_SEED', defaultValue: '');

bool get kIsSubscriptionSeeded => kSubscriptionSeedMode.isNotEmpty;

/// Immutable snapshot of the Support subscription state.
class SubscriptionState extends Equatable {
  final bool storeAvailable;
  final bool loading;
  final bool pendingPurchase;
  final SupportTier? purchasingTier;
  final List<ProductDetails> products;
  final SupportTier? activeTier;
  final DateTime? expiryDate;
  final String? error;

  const SubscriptionState({
    this.storeAvailable = true,
    this.loading = true,
    this.pendingPurchase = false,
    this.purchasingTier,
    this.products = const [],
    this.activeTier,
    this.expiryDate,
    this.error,
  });

  /// True when we believe a tier is active. If [expiryDate] is set we honour
  /// it; otherwise we trust the persisted tier (plugin does not always
  /// surface expiry — see notifier comments).
  bool get isActive {
    if (activeTier == null) return false;
    if (expiryDate == null) return true;
    return expiryDate!.isAfter(DateTime.now());
  }

  ProductDetails? productFor(SupportTier tier) {
    for (final p in products) {
      if (p.id == tier.productId) return p;
    }
    return null;
  }

  SubscriptionState copyWith({
    bool? storeAvailable,
    bool? loading,
    bool? pendingPurchase,
    List<ProductDetails>? products,
    String? error,
    bool clearError = false,
    SupportTier? activeTier,
    bool clearActiveTier = false,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    SupportTier? purchasingTier,
    bool clearPurchasingTier = false,
  }) {
    return SubscriptionState(
      storeAvailable: storeAvailable ?? this.storeAvailable,
      loading: loading ?? this.loading,
      pendingPurchase: pendingPurchase ?? this.pendingPurchase,
      purchasingTier:
          clearPurchasingTier ? null : (purchasingTier ?? this.purchasingTier),
      products: products ?? this.products,
      activeTier: clearActiveTier ? null : (activeTier ?? this.activeTier),
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
        storeAvailable,
        loading,
        pendingPurchase,
        purchasingTier,
        products,
        activeTier,
        expiryDate,
        error,
      ];
}
