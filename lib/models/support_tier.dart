/// The three optional monthly supporter tiers. Product IDs match the
/// subscriptions registered in App Store Connect.
enum SupportTier {
  small(
    productId: 'pww_small',
    displayName: 'Small',
    fallbackPrice: r'$1.99',
    blurb: 'A friendly nod to keep development caffeinated.',
  ),
  medium(
    productId: 'pww_medium',
    displayName: 'Medium',
    fallbackPrice: r'$3.99',
    blurb: 'Helps cover developer account fees and signing costs.',
  ),
  large(
    productId: 'pww_large',
    displayName: 'Large',
    fallbackPrice: r'$5.99',
    blurb: 'Powers late-night feature sprints and new releases.',
  );

  const SupportTier({
    required this.productId,
    required this.displayName,
    required this.fallbackPrice,
    required this.blurb,
  });

  final String productId;
  final String displayName;
  final String fallbackPrice;
  final String blurb;

  static const Set<String> allProductIds = {
    'pww_small',
    'pww_medium',
    'pww_large',
  };

  static SupportTier? fromProductId(String id) {
    for (final tier in SupportTier.values) {
      if (tier.productId == id) return tier;
    }
    return null;
  }
}
