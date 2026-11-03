import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/room_insight.dart';
import '../services/parser/room_line_classifier.dart';
import 'settings_provider.dart';

/// The room the Room Insight panel shows, or `null` while there is none to
/// show (nothing seen yet, or a room was entered less than
/// [RoomInsightNotifier.settleDelay] ago).
///
/// Fed the same plain-text lines as `roomTargetsProvider`.
final roomInsightProvider =
    NotifierProvider<RoomInsightNotifier, RoomInsight?>(
        RoomInsightNotifier.new);

/// [roomInsightProvider] with the player's recategorisations
/// (`AppSettings.roomEntityKinds`) applied. What the Room tab renders.
final roomInsightViewProvider = Provider<RoomInsight?>((ref) {
  final room = ref.watch(roomInsightProvider);
  if (room == null) return null;
  final stored = ref.watch(settingsProvider.select((s) => s.roomEntityKinds));
  final overrides = <String, RoomEntityKind>{};
  stored.forEach((phrase, name) {
    final kind = RoomEntityKind.fromName(name);
    if (kind != null) overrides[phrase] = kind;
  });
  return room.withOverrides(overrides);
});

class RoomInsightNotifier extends Notifier<RoomInsight?> {
  /// How long a room must stay the current one before the panel shows it.
  /// Walking through several rooms quickly therefore shows only the one the
  /// player stops in, instead of flickering through each.
  static Duration settleDelay = const Duration(seconds: 1);

  Timer? _timer;
  bool _inBlock = false;
  bool _shown = false;
  RoomInsight? _room;
  final List<RoomEntity> _entities = [];
  final Map<String, int> _seen = {};

  @override
  RoomInsight? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  /// Feeds one plain-text MUD output line.
  void processLine(String plainText) {
    final line = plainText.trimRight();

    final header = RoomInsightParser.parseHeader(line);
    if (header != null) {
      _room = header;
      _entities.clear();
      _seen.clear();
      _inBlock = true;
      _shown = false;
      // The room just left is not rendered while the new one settles.
      if (state != null) state = null;
      _timer?.cancel();
      _timer = Timer(settleDelay, () {
        _shown = true;
        _publish();
      });
      return;
    }

    if (!_inBlock) return;
    if (line.trim().isEmpty || RoomLineClassifier.isPromptShape(line)) {
      _inBlock = false;
      return;
    }

    final entity = RoomInsightParser.parseEntity(line, _seen);
    if (entity == null) return;
    _entities.add(entity);
    if (_shown) _publish();
  }

  void _publish() {
    final room = _room;
    if (room == null) return;
    state = RoomInsight(
      name: room.name,
      exits: room.exits,
      entities: List.unmodifiable(_entities),
    );
  }
}
