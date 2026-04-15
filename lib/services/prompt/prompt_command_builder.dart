import '../../models/prompt_element.dart';

/// Builds the MUD `prompt set` command from the active prompt elements.
///
/// Elements are emitted in canonical order (enum declaration order) so that
/// the positional parser knows which capture group maps to which field.
String buildPromptCommand(List<PromptElement> activeElements) {
  final tokens = activeElements.map((e) => '|${e.mudToken}|').join(' ');
  return 'prompt set @@$tokens@@';
}

/// Builds a [RegExp] that matches the `@@...@@` prompt payload for the
/// given active elements.
///
/// Each element contributes a capture group whose pattern depends on its
/// [PromptDataType]. Groups are space-separated and wrapped in `@@` markers.
RegExp buildPromptRegex(List<PromptElement> activeElements) {
  final groups = activeElements.map((e) {
    return switch (e.dataType) {
      PromptDataType.integer => r'(\d+)',
      PromptDataType.signedInteger => r'(-?\d+)',
      PromptDataType.string => r'(\S+)',
      PromptDataType.percentage => r'(\d+)',
    };
  }).join(r'\s+');
  return RegExp('@@\\s*$groups@@');
}

/// Returns the active [PromptElement]s for the given set of enabled MUD
/// tokens, sorted in canonical order.
List<PromptElement> resolveActiveElements(Set<String> enabledTokens) {
  return PromptElement.allElements
      .where((e) => enabledTokens.contains(e.mudToken))
      .toList();
}
