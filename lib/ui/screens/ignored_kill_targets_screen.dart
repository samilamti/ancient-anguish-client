import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/kill_target_links_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/common/escape_dismiss.dart';
import '../widgets/common/settings_drawer_route.dart';

/// Review and un-ignore the words the user has muted from the terminal's
/// reddish `kill <target>` links.
///
/// Entries are added by long-pressing a red link in the output — an ignore
/// list you can only add to is a trap, so this is the way back out.
class IgnoredKillTargetsScreen extends ConsumerWidget {
  const IgnoredKillTargetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ignored =
        ref.watch(settingsProvider.select((s) => s.ignoredKillTargets));
    final theme = Theme.of(context);

    return EscapeDismiss(
      child: Scaffold(
        appBar: AppBar(title: const Text('Ignored Kill Targets')),
        body: ignored.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.link_off,
                        size: 64,
                        color: theme.colorScheme.primary.withAlpha(80),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nothing ignored',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Long-press a red kill link in the output to stop it '
                        'being highlighted.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withAlpha(120),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'These words are never highlighted as attackable. They '
                      'are still available in the Kill picker.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: ignored.length,
                      itemBuilder: (context, index) {
                        final target = ignored[index];
                        return ListTile(
                          leading: Icon(
                            Icons.link_off,
                            color: killTargetLinkColor.withAlpha(150),
                          ),
                          title: Text(
                            target,
                            style: const TextStyle(
                              fontFamily: 'JetBrainsMono',
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.undo),
                            tooltip: 'Highlight again',
                            onPressed: () => ref
                                .read(settingsProvider.notifier)
                                .removeIgnoredKillTarget(target),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Opens [IgnoredKillTargetsScreen] as a right-docked settings panel, matching
/// how the other configuration panes present themselves.
Future<void> openIgnoredKillTargetsEditor(BuildContext context) {
  return openSettingsDrawer(context, const IgnoredKillTargetsScreen());
}
