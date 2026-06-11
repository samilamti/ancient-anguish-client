import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/subscription_state.dart';
import '../../models/support_tier.dart';
import '../../providers/subscription_provider.dart';
import '../widgets/common/escape_dismiss.dart';

/// Whether this build sells through Apple (App Store / Mac App Store)
/// rather than Google Play. Drives store-specific URLs and legal copy.
bool get _isAppleStore =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// Optional supporter-tier subscription screen.
///
/// Tiers are purely cosmetic — no content gating — so the UI is
/// straightforward: three cards, a restore button, a manage-subscription
/// deep link, and the store-mandated auto-renewal disclosure.
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  static String get _manageUrl => _isAppleStore
      ? 'https://apps.apple.com/account/subscriptions'
      : 'https://play.google.com/store/account/subscriptions';
  static String get _termsUrl => _isAppleStore
      ? 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'
      : 'https://play.google.com/about/play-terms/';
  static const String _privacyUrl =
      'https://ancient-anguish.duckdns.org/privacy.html';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionProvider);
    final notifier = ref.read(subscriptionProvider.notifier);

    return EscapeDismiss(
      child: Scaffold(
        appBar: AppBar(title: const Text('Support')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: _buildBody(context, state, notifier),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBody(
    BuildContext context,
    SubscriptionState state,
    SubscriptionNotifier notifier,
  ) {
    if (state.loading) {
      return [
        const _IntroCard(),
        const SizedBox(height: 24),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Contacting ${_isAppleStore ? 'App Store' : 'Google Play'}…',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ];
    }

    if (!state.storeAvailable) {
      return [
        const _IntroCard(),
        const SizedBox(height: 24),
        _StoreUnavailable(onRetry: notifier.retry),
      ];
    }

    return [
      const _IntroCard(),
      const SizedBox(height: 12),
      _LegalLinksRow(
        termsUrl: _termsUrl,
        privacyUrl: _privacyUrl,
      ),
      const SizedBox(height: 16),
      for (final tier in SupportTier.values) ...[
        _TierCard(
          tier: tier,
          state: state,
          onSubscribe: () => notifier.purchase(tier),
          termsUrl: _termsUrl,
          privacyUrl: _privacyUrl,
        ),
        const SizedBox(height: 12),
      ],
      if (state.error != null) ...[
        const SizedBox(height: 8),
        _ErrorBanner(message: state.error!),
      ],
      const SizedBox(height: 8),
      Center(
        child: TextButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Restore Purchases'),
          onPressed: state.pendingPurchase ? null : notifier.restore,
        ),
      ),
      Center(
        child: TextButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: const Text('Manage Subscription'),
          onPressed: () => launchUrl(
            Uri.parse(_manageUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ),
      const SizedBox(height: 24),
      _LegalFooter(
        termsUrl: _termsUrl,
        privacyUrl: _privacyUrl,
      ),
    ];
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.favorite,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Support the Client',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'This client is made by a solo developer. If you enjoy it, '
              'these optional tiers help keep it updated. Nothing is gated '
              'behind them — supporters just get a quiet thank-you.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tier,
    required this.state,
    required this.onSubscribe,
    required this.termsUrl,
    required this.privacyUrl,
  });

  final SupportTier tier;
  final SubscriptionState state;
  final VoidCallback onSubscribe;
  final String termsUrl;
  final String privacyUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = state.productFor(tier);
    final isActive = state.activeTier == tier && state.isActive;
    final isPurchasingThis =
        state.pendingPurchase && state.purchasingTier == tier;
    final anyPending = state.pendingPurchase;

    final shape = isActive
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: theme.colorScheme.primary, width: 2),
          )
        : null;

    return Card(
      shape: shape,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tier.displayName,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Text(
                  product?.price ?? tier.fallbackPrice,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'per month',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(140),
              ),
            ),
            const SizedBox(height: 12),
            Text(tier.blurb, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            _TierLegalLine(termsUrl: termsUrl, privacyUrl: privacyUrl),
            const SizedBox(height: 8),
            Row(
              children: [
                if (isActive)
                  Chip(
                    avatar: Icon(
                      Icons.check_circle,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    label: const Text('Active'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: anyPending || isActive ? null : onSubscribe,
                  child: isPurchasingThis
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isActive ? 'Active' : 'Subscribe'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TierLegalLine extends StatelessWidget {
  const _TierLegalLine({required this.termsUrl, required this.privacyUrl});

  final String termsUrl;
  final String privacyUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withAlpha(160),
    );
    final linkStyle = baseStyle?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Subscribing accepts the ', style: baseStyle),
        InkWell(
          onTap: () => launchUrl(
            Uri.parse(termsUrl),
            mode: LaunchMode.externalApplication,
          ),
          child: Text('Terms of Use', style: linkStyle),
        ),
        Text(' · ', style: baseStyle),
        InkWell(
          onTap: () => launchUrl(
            Uri.parse(privacyUrl),
            mode: LaunchMode.externalApplication,
          ),
          child: Text('Privacy Policy', style: linkStyle),
        ),
        Text('.', style: baseStyle),
      ],
    );
  }
}

class _StoreUnavailable extends StatelessWidget {
  const _StoreUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off,
              size: 40,
              color: theme.colorScheme.onSurface.withAlpha(140),
            ),
            const SizedBox(height: 12),
            Text(
              'Store unavailable',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalLinksRow extends StatelessWidget {
  const _LegalLinksRow({required this.termsUrl, required this.privacyUrl});

  final String termsUrl;
  final String privacyUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withAlpha(200),
    );
    final linkStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );
    final dotStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withAlpha(140),
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: theme.colorScheme.primary.withAlpha(80),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Before you subscribe: ', style: labelStyle),
                  InkWell(
                    onTap: () => launchUrl(
                      Uri.parse(termsUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Text('Terms of Use', style: linkStyle),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('·', style: dotStyle),
                  ),
                  InkWell(
                    onTap: () => launchUrl(
                      Uri.parse(privacyUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Text('Privacy Policy', style: linkStyle),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter({required this.termsUrl, required this.privacyUrl});

  final String termsUrl;
  final String privacyUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withAlpha(140),
    );
    final linkStyle = style?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Support Tiers are optional monthly subscriptions that help fund '
          'client development.\n\n'
          '• Length: Monthly (auto-renewing)\n'
          '${_isAppleStore ? r'• Small $1.99 / Medium $3.99 / Large $5.99 per month (USD)' : '• Prices are shown on each tier card in your local currency'}'
          '\n'
          '• Payment is charged to your '
          '${_isAppleStore ? 'Apple ID' : 'Google account'} at confirmation '
          'of purchase.\n'
          '• Auto-renews unless cancelled at least 24 hours before the end of '
          'the current period.\n'
          '• Manage or cancel anytime from your '
          '${_isAppleStore ? 'Apple ID' : 'Google Play'} subscription '
          'settings.',
          style: style,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            InkWell(
              onTap: () => launchUrl(
                Uri.parse(termsUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: Text('Terms of Use', style: linkStyle),
            ),
            const SizedBox(width: 16),
            InkWell(
              onTap: () => launchUrl(
                Uri.parse(privacyUrl),
                mode: LaunchMode.externalApplication,
              ),
              child: Text('Privacy Policy', style: linkStyle),
            ),
          ],
        ),
      ],
    );
  }
}
