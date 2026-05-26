import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../widgets/common/escape_dismiss.dart';
import 'support_screen.dart';

/// About screen showing app info, credits, and license.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return EscapeDismiss(
      child: Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── App Info ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.castle,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Chosen's MUD Client",
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'for Ancient Anguish',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withAlpha(180),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  FutureBuilder<PackageInfo>(
                    future: _packageInfo,
                    builder: (context, snapshot) {
                      final label = snapshot.hasData
                          ? 'v${snapshot.data!.version}'
                          : '';
                      return Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(160),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A cross-platform MUD client for Ancient Anguish',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Support ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Support',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Optional monthly support tiers — purely cosmetic, '
                    'nothing gated.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SupportScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('View tiers'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Special Thanks ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Special Thanks',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CreditTile(
                    name: 'Tuinn',
                    role: 'Testing & feedback on Windows',
                  ),
                  const SizedBox(height: 8),
                  _CreditTile(
                    name: 'Bytre',
                    role: 'Advanced Customization concept & design',
                  ),
                  const SizedBox(height: 8),
                  _CreditTile(
                    name: 'Jerusulum',
                    role: 'Accessibility contributions',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Keyboard shortcuts ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.keyboard,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Keyboard shortcuts',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ShortcutRow(
                    keys: _shortcutLabel(context, 'L'),
                    description: 'Fire the most recently rendered text link',
                  ),
                  const SizedBox(height: 6),
                  _ShortcutRow(
                    keys: _shortcutLabel(context, '1 – 4'),
                    description:
                        'Focus Chat / Tells / Party / Notes in the Social Window Cluster',
                  ),
                  const SizedBox(height: 6),
                  _ShortcutRow(
                    keys: 'Esc',
                    description: 'Dismiss the current sub-screen',
                  ),
                  const SizedBox(height: 6),
                  _ShortcutRow(
                    keys: '↑ / ↓',
                    description: 'Cycle command history in the input bar',
                  ),
                  const SizedBox(height: 6),
                  _ShortcutRow(
                    keys: 'Tab',
                    description: 'Complete the current word from history',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── License ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'License',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'MIT License © 2026 Sami Xavier Lamti',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Platform-aware shortcut label — macOS/iOS users see `⌘`, everyone else
/// sees `Ctrl`. Returns just the modifier+key string, no surrounding
/// formatting; the [_ShortcutRow] renders the chip.
String _shortcutLabel(BuildContext context, String key) {
  final platform = Theme.of(context).platform;
  final isMacish =
      platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;
  return isMacish ? '⌘$key' : 'Ctrl+$key';
}

/// One row in the keyboard-shortcuts list: a monospace chip on the left
/// for the keys, a wrapping description on the right.
class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.keys, required this.description});

  final String keys;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withAlpha(140),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: theme.colorScheme.primary.withAlpha(60),
            ),
          ),
          child: Text(
            keys,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              description,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}

class _CreditTile extends StatelessWidget {
  const _CreditTile({required this.name, required this.role});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            name[0],
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            )),
            Text(role, style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(160),
            )),
          ],
        ),
      ],
    );
  }
}
