import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:ancient_anguish_client/models/subscription_state.dart';
import 'package:ancient_anguish_client/models/support_tier.dart';
import 'package:ancient_anguish_client/providers/storage_provider.dart';
import 'package:ancient_anguish_client/providers/subscription_provider.dart';
import 'package:ancient_anguish_client/services/storage/storage_service.dart';
import 'package:ancient_anguish_client/services/subscription/subscription_service.dart';

class _InMemoryStorage implements StorageService {
  final Map<String, String> files = {};

  @override
  Future<String> readFile(String name) async => files[name] ?? '';

  @override
  Future<List<String>> readFileLines(String name) async =>
      (files[name] ?? '').split('\n');

  @override
  Future<void> writeFile(String name, String contents) async {
    files[name] = contents;
  }

  @override
  Future<void> appendToFile(String name, String text) async {
    files[name] = (files[name] ?? '') + text;
  }

  @override
  Future<bool> fileExists(String name) async =>
      (files[name] ?? '').isNotEmpty;

  @override
  Future<int> fileLength(String name) async =>
      (files[name] ?? '').length;

  @override
  Future<void> ensureFile(String name, [String defaultContents = '']) async {
    files.putIfAbsent(name, () => defaultContents);
  }

  @override
  Future<void> ensureDirectories() async {}
}

/// Controllable fake that drives state transitions without touching StoreKit.
class _FakeSubscriptionService implements SubscriptionService {
  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();

  bool available = true;
  List<ProductDetails> products = [];
  String? queryError;
  bool buyResult = true;
  int buyCalls = 0;
  int restoreCalls = 0;
  int completeCalls = 0;
  PurchaseDetails? lastPurchaseParam;

  void emit(List<PurchaseDetails> purchases) {
    _controller.add(purchases);
  }

  void dispose() => _controller.close();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProducts() async {
    return ProductDetailsResponse(
      productDetails: products,
      notFoundIDs: const [],
      error: queryError == null
          ? null
          : IAPError(
              source: 'test',
              code: 'test_error',
              message: queryError!,
            ),
    );
  }

  @override
  Future<bool> buy(ProductDetails product) async {
    buyCalls++;
    lastPurchaseParam = _fakeDetails(
      product.id,
      PurchaseStatus.pending,
    );
    return buyResult;
  }

  @override
  Future<void> restore() async {
    restoreCalls++;
  }

  @override
  Future<void> complete(PurchaseDetails purchase) async {
    completeCalls++;
  }
}

ProductDetails _fakeProduct(SupportTier tier, double price) {
  return ProductDetails(
    id: tier.productId,
    title: tier.displayName,
    description: tier.blurb,
    price: '\$${price.toStringAsFixed(2)}',
    rawPrice: price,
    currencyCode: 'USD',
  );
}

PurchaseDetails _fakeDetails(String productId, PurchaseStatus status,
    {String? errorMessage}) {
  return PurchaseDetails(
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: '',
      source: 'test',
    ),
    transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
    status: status,
  )
    ..error = errorMessage == null
        ? null
        : IAPError(
            source: 'test',
            code: 'test_error',
            message: errorMessage,
          )
    ..pendingCompletePurchase = status == PurchaseStatus.purchased ||
        status == PurchaseStatus.restored ||
        status == PurchaseStatus.error;
}

/// Waits for state to satisfy [predicate], polling microtasks. Fails the
/// test if the predicate never becomes true within [timeout].
Future<void> waitFor(
  ProviderContainer container,
  bool Function(SubscriptionState) predicate, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (predicate(container.read(subscriptionProvider))) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Predicate never satisfied. State: '
      '${container.read(subscriptionProvider)}');
}

void main() {
  late ProviderContainer container;
  late _FakeSubscriptionService fakeService;
  late _InMemoryStorage storage;

  setUp(() {
    fakeService = _FakeSubscriptionService()
      ..products = [
        _fakeProduct(SupportTier.small, 1.99),
        _fakeProduct(SupportTier.medium, 3.99),
        _fakeProduct(SupportTier.large, 5.99),
      ];
    storage = _InMemoryStorage();
    container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        subscriptionServiceProvider.overrideWithValue(fakeService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    fakeService.dispose();
  });

  group('SubscriptionNotifier - init', () {
    test('loads products and becomes ready when store is available', () async {
      container.read(subscriptionProvider);
      await waitFor(container, (s) => !s.loading);

      final state = container.read(subscriptionProvider);
      expect(state.storeAvailable, isTrue);
      expect(state.products.length, 3);
      expect(state.products.map((p) => p.id).toSet(),
          SupportTier.allProductIds);
      expect(fakeService.restoreCalls, 1);
    });

    test('flags storeAvailable=false when plugin reports unavailable',
        () async {
      fakeService.available = false;
      container.read(subscriptionProvider);
      await waitFor(container, (s) => !s.loading);

      final state = container.read(subscriptionProvider);
      expect(state.storeAvailable, isFalse);
      expect(state.products, isEmpty);
    });
  });

  group('SubscriptionNotifier - purchase stream', () {
    test('marks a tier active on purchased event and persists to storage',
        () async {
      container.read(subscriptionProvider);
      await waitFor(container, (s) => !s.loading);

      fakeService.emit([
        _fakeDetails('pww_medium', PurchaseStatus.purchased),
      ]);
      await waitFor(container,
          (s) => s.activeTier == SupportTier.medium && !s.pendingPurchase);

      final state = container.read(subscriptionProvider);
      expect(state.isActive, isTrue);
      expect(state.expiryDate, isNotNull);
      expect(state.error, isNull);
      expect(fakeService.completeCalls, 1);
      expect(storage.files['subscription.json'], contains('pww_medium'));
    });

    test('restored event rehydrates the tier', () async {
      container.read(subscriptionProvider);
      await waitFor(container, (s) => !s.loading);

      fakeService.emit([
        _fakeDetails('pww_large', PurchaseStatus.restored),
      ]);
      await waitFor(container, (s) => s.activeTier == SupportTier.large);

      expect(fakeService.completeCalls, 1);
    });

    test('canceled event clears pending without setting error', () async {
      container.read(subscriptionProvider);
      await waitFor(container, (s) => !s.loading);

      await container
          .read(subscriptionProvider.notifier)
          .purchase(SupportTier.small);
      expect(container.read(subscriptionProvider).pendingPurchase, isTrue);

      fakeService.emit([
        _fakeDetails('pww_small', PurchaseStatus.canceled),
      ]);
      await waitFor(container, (s) => !s.pendingPurchase);

      final state = container.read(subscriptionProvider);
      expect(state.error, isNull);
      expect(state.activeTier, isNull);
    });

    test('error event surfaces message and clears pending', () async {
      container.read(subscriptionProvider);
      await waitFor(container, (s) => !s.loading);

      fakeService.emit([
        _fakeDetails('pww_small', PurchaseStatus.error,
            errorMessage: 'Something blew up'),
      ]);
      await waitFor(container, (s) => s.error != null);

      final state = container.read(subscriptionProvider);
      expect(state.error, contains('Something blew up'));
      expect(state.pendingPurchase, isFalse);
      expect(state.activeTier, isNull);
      expect(fakeService.completeCalls, 1);
    });
  });

  group('SubscriptionNotifier - purchase', () {
    test('calls buy on service and sets pending flag', () async {
      container.read(subscriptionProvider);
      await waitFor(container, (s) => !s.loading);

      await container
          .read(subscriptionProvider.notifier)
          .purchase(SupportTier.medium);

      expect(fakeService.buyCalls, 1);
      expect(fakeService.lastPurchaseParam?.productID, 'pww_medium');

      final state = container.read(subscriptionProvider);
      expect(state.pendingPurchase, isTrue);
      expect(state.purchasingTier, SupportTier.medium);
    });

    test('surfaces error when the store rejects the purchase request',
        () async {
      fakeService.buyResult = false;
      container.read(subscriptionProvider);
      await waitFor(container, (s) => !s.loading);

      await container
          .read(subscriptionProvider.notifier)
          .purchase(SupportTier.small);

      final state = container.read(subscriptionProvider);
      expect(state.pendingPurchase, isFalse);
      expect(state.error, isNotNull);
    });
  });

  group('SubscriptionNotifier - restore', () {
    test('delegates to the service', () async {
      container.read(subscriptionProvider);
      await waitFor(container, (s) => !s.loading);
      final initialCalls = fakeService.restoreCalls;

      await container.read(subscriptionProvider.notifier).restore();

      expect(fakeService.restoreCalls, initialCalls + 1);
    });
  });

  group('SubscriptionNotifier - hydration', () {
    test('restores active tier from storage when present and not expired',
        () async {
      storage.files['subscription.json'] =
          '{"activeTier":"pww_large","expiryEpochMs":'
          '${DateTime.now().add(const Duration(days: 5)).millisecondsSinceEpoch}'
          '}';

      container.read(subscriptionProvider);
      await waitFor(container, (s) => !s.loading);

      expect(
        container.read(subscriptionProvider).activeTier,
        SupportTier.large,
      );
    });

    test('ignores expired stored tier', () async {
      storage.files['subscription.json'] =
          '{"activeTier":"pww_small","expiryEpochMs":'
          '${DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch}'
          '}';

      container.read(subscriptionProvider);
      await waitFor(container, (s) => !s.loading);

      expect(container.read(subscriptionProvider).activeTier, isNull);
    });
  });
}
