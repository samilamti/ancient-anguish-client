import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/subscription_state.dart';
import '../../models/support_tier.dart';
import '../../providers/subscription_provider.dart';

/// Optional supporter-tier subscription screen.
///
/// Tiers are purely cosmetic — no content gating — so the UI is
/// straightforward: three cards, a restore button, a manage-subscription
/// deep link, and the Apple-mandated auto-renewal disclosure.
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  static const String _manageUrl =
      'https://apps.apple.com/account/subscriptions';
  static const String _termsUrl = 'https://anguish.org/connect.php';
  static const String _privacyUrl = 'https://anguish.org/privacy.html';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subscriptionProvider);
    final notifier = ref.read(subscriptionProvider.notifier);

    return Scaffold(
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
            'Contacting App Store…',
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
      const SizedBox(height: 16),
      for (final tier in SupportTier.values) ...[
        _TierCard(
          tier: tier,
          state: state,
          onSubscribe: () => notifier.purchase(tier),
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
      const _LegalFooter(
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
  });

  final SupportTier tier;
  final SubscriptionState state;
  final VoidCallback onSubscribe;

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
          r'• Small $1.99 / Medium $3.99 / Large $5.99 per month (USD)'
          '\n'
          '• Payment is charged to your Apple ID at confirmation of purchase.\n'
          '• Auto-renews unless cancelled at least 24 hours before the end of '
          'the current period.\n'
          '• Manage or cancel anytime from your Apple ID subscription '
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
