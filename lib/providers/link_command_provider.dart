import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alias_provider.dart';
import 'connection_provider.dart';

/// Sends a command that came from a tappable link — a text-link rule, a
/// kill-target link, or the Ctrl/Cmd+L shortcut — to the MUD.
///
/// The command is expanded through the alias engine first, exactly as if the
/// player had typed it into the input bar, so a rule may emit `k hare` and get
/// whatever the player's own `k` alias does with it (`kill $1`, or a chain
/// like `kill $1;wield sword`). Expansion can therefore yield several
/// commands; each is sent in order.
///
/// Returned as a function rather than a service so call sites stay one line
/// and tests can drive it from a bare [ProviderContainer].
final linkCommandSenderProvider = Provider<void Function(String)>((ref) {
  return (String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return;
    final service = ref.read(connectionServiceProvider);
    for (final outgoing in ref.read(aliasEngineProvider).expand(trimmed)) {
      if (outgoing.trim().isEmpty) continue;
      service.sendCommand(outgoing);
    }
  };
});
