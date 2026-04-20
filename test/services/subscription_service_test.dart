import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/support_tier.dart';

void main() {
  group('SupportTier', () {
    test('exposes the three expected product IDs', () {
      expect(
        SupportTier.allProductIds,
        equals({'pww_small', 'pww_medium', 'pww_large'}),
      );
    });

    test('fromProductId maps known ids back to the right tier', () {
      expect(SupportTier.fromProductId('pww_small'), SupportTier.small);
      expect(SupportTier.fromProductId('pww_medium'), SupportTier.medium);
      expect(SupportTier.fromProductId('pww_large'), SupportTier.large);
    });

    test('fromProductId returns null for unknown ids', () {
      expect(SupportTier.fromProductId('pww_xl'), isNull);
      expect(SupportTier.fromProductId(''), isNull);
    });

    test('each tier has non-empty display name, fallback price, and blurb',
        () {
      for (final tier in SupportTier.values) {
        expect(tier.displayName, isNotEmpty);
        expect(tier.fallbackPrice, isNotEmpty);
        expect(tier.fallbackPrice, startsWith(r'$'));
        expect(tier.blurb, isNotEmpty);
      }
    });

    test('fallback prices follow the expected tier pricing', () {
      expect(SupportTier.small.fallbackPrice, r'$1.99');
      expect(SupportTier.medium.fallbackPrice, r'$3.99');
      expect(SupportTier.large.fallbackPrice, r'$5.99');
    });
  });
}
