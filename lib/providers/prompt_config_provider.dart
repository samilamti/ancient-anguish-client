import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/prompt_element.dart';
import '../services/prompt/prompt_command_builder.dart';
import 'settings_provider.dart';

/// Holds the compiled prompt command, regex, and element list.
///
/// Rebuilt automatically whenever the user's prompt element selections change.
class PromptConfig {
  /// The `prompt set @@...@@` command to send to the MUD.
  final String promptCommand;

  /// Regex matching the `@@...@@` payload with one capture group per element.
  final RegExp promptRegex;

  /// Active elements in canonical order (matches capture group order).
  final List<PromptElement> activeElements;

  const PromptConfig({
    required this.promptCommand,
    required this.promptRegex,
    required this.activeElements,
  });
}

/// Provides the current [PromptConfig] based on the user's enabled elements.
///
/// Watches [settingsProvider] so the command and regex are rebuilt whenever
/// the user changes their selections in Advanced Customization.
final promptConfigProvider = Provider<PromptConfig>((ref) {
  final settings = ref.watch(settingsProvider);
  final activeElements = resolveActiveElements(settings.enabledPromptElements);
  final command = buildPromptCommand(activeElements);
  final regex = buildPromptRegex(activeElements);

  return PromptConfig(
    promptCommand: command,
    promptRegex: regex,
    activeElements: activeElements,
  );
});
