import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/widgets/social/social_message_list.dart' show SocialListType;

/// Shared focus nodes for each social input bar (Chat / Tells / Party).
///
/// Lives outside the input-bar widgets so external widgets — e.g. the panel
/// body itself — can request focus without reaching into the input bar's
/// internal state. The provider owns the nodes and disposes them when the
/// ProviderScope tears down.
final socialInputFocusProvider = Provider<Map<SocialListType, FocusNode>>((ref) {
  final nodes = <SocialListType, FocusNode>{
    SocialListType.chat: FocusNode(debugLabel: 'chat input'),
    SocialListType.tells: FocusNode(debugLabel: 'tells input'),
    SocialListType.party: FocusNode(debugLabel: 'party input'),
  };
  ref.onDispose(() {
    for (final n in nodes.values) {
      n.dispose();
    }
  });
  return nodes;
});

/// Shared focus node for the Notes panel's text field. Exposed so the
/// global keyboard shortcut (Ctrl/Opt+4) can focus the editor without
/// reaching into `_NotesBody` state.
final notesFocusProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'notes editor');
  ref.onDispose(node.dispose);
  return node;
});
