import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/prompt_element.dart';
import '../../providers/settings_provider.dart';

/// Screen where players choose which MUD prompt values to receive,
/// directly shaping the HUD panels shown during gameplay.
class AdvancedCustomizationScreen extends ConsumerWidget {
  const AdvancedCustomizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    final enabled = settings.enabledPromptElements;

    // Group elements by category.
    final byCategory = <PromptCategory, List<PromptElement>>{};
    for (final e in PromptElement.allElements) {
      byCategory.putIfAbsent(e.category, () => []).add(e);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Advanced Customization')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Intro text.
          Text(
            'Choose which stats the MUD sends to your client. '
            'Each selection adds a live panel to your HUD.',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withAlpha(160),
            ),
          ),
          const SizedBox(height: 12),

          // Donator toggle.
          SwitchListTile(
            title: const Text('Donator Features'),
            subtitle: const Text(
              'Enable elements exclusive to donators',
            ),
            value: settings.isDonator,
            onChanged: (_) => notifier.toggleDonator(),
            secondary: Icon(
              Icons.star,
              color: settings.isDonator
                  ? const Color(0xFFD4A057)
                  : theme.colorScheme.onSurface.withAlpha(60),
            ),
          ),
          const Divider(height: 24),

          // Element categories.
          for (final category in PromptCategory.values) ...[
            if (byCategory.containsKey(category)) ...[
              _CategorySection(
                category: category,
                elements: byCategory[category]!,
                enabled: enabled,
                isDonator: settings.isDonator,
                onToggle: (mudToken, selected) {
                  final updated = Set<String>.from(enabled);
                  if (selected) {
                    updated.add(mudToken);
                  } else {
                    updated.remove(mudToken);
                  }
                  notifier.setEnabledPromptElements(updated);
                },
              ),
              const SizedBox(height: 16),
            ],
          ],

          // Active prompt preview.
          const Divider(height: 24),
          _PromptPreview(enabled: enabled),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final PromptCategory category;
  final List<PromptElement> elements;
  final Set<String> enabled;
  final bool isDonator;
  final void Function(String mudToken, bool selected) onToggle;

  const _CategorySection({
    required this.category,
    required this.elements,
    required this.enabled,
    required this.isDonator,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter out donator elements when not a donator.
    final visible =
        elements.where((e) => !e.donatorOnly || isDonator).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_categoryIcon(category),
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              category.displayName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              category.description,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withAlpha(100),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final e in visible)
              FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (e.donatorOnly) ...[
                      Icon(Icons.star, size: 12,
                          color: const Color(0xFFD4A057)),
                      const SizedBox(width: 4),
                    ],
                    Text(e.displayName),
                    if (e.isCore) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.lock, size: 11,
                          color: theme.colorScheme.onSurface.withAlpha(80)),
                    ],
                  ],
                ),
                tooltip: e.description,
                selected: enabled.contains(e.mudToken),
                onSelected: e.isCore
                    ? null // Core elements cannot be deselected.
                    : (selected) => onToggle(e.mudToken, selected),
              ),
          ],
        ),
      ],
    );
  }

  static IconData _categoryIcon(PromptCategory cat) {
    return switch (cat) {
      PromptCategory.vitals => Icons.favorite,
      PromptCategory.combat => Icons.shield,
      PromptCategory.experience => Icons.trending_up,
      PromptCategory.character => Icons.person,
      PromptCategory.world => Icons.public,
      PromptCategory.survival => Icons.eco,
      PromptCategory.wealth => Icons.monetization_on,
    };
  }
}

/// Shows the prompt command that will be sent to the MUD.
class _PromptPreview extends StatelessWidget {
  final Set<String> enabled;

  const _PromptPreview({required this.enabled});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = PromptElement.allElements
        .where((e) => enabled.contains(e.mudToken))
        .toList();
    final tokens = active.map((e) => '|${e.mudToken}|').join(' ');
    final command = 'prompt set @@$tokens@@';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.terminal, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'MUD Command Preview',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(80),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: theme.colorScheme.primary.withAlpha(40),
            ),
          ),
          child: SelectableText(
            command,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              color: Color(0xFF44BB44),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${active.length} element${active.length == 1 ? '' : 's'} active',
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withAlpha(100),
          ),
        ),
      ],
    );
  }
}
