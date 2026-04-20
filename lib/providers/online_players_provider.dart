import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Names of players reported by the most recent `qwho` response.
///
/// Populated passively: every time a qwho header is seen on the wire, the
/// notifier collects the following name columns until a blank line ends the
/// block. Used by the Tells autocomplete so the recipient dropdown is
/// pre-populated with everyone currently online.
final onlinePlayersProvider =
    NotifierProvider<OnlinePlayersNotifier, List<String>>(
  OnlinePlayersNotifier.new,
);

class OnlinePlayersNotifier extends Notifier<List<String>> {
  static final _headerPattern = RegExp(
    r'^There (?:are|is) \d+ players? currently adventuring:?$',
  );
  static final _nameToken = RegExp(r'^[A-Z][a-zA-Z]{1,19}$');

  bool _collecting = false;
  final List<String> _pending = [];

  @override
  List<String> build() => const [];

  /// Feed a plain-text line from the MUD. Detects and accumulates qwho
  /// output transparently; lines that aren't part of a qwho block are
  /// ignored.
  void processLine(String line) {
    final trimmed = line.trim();

    if (!_collecting) {
      if (_headerPattern.hasMatch(trimmed)) {
        _collecting = true;
        _pending.clear();
      }
      return;
    }

    // Collecting mode: blank line ends the block.
    if (trimmed.isEmpty) {
      if (_pending.isNotEmpty) {
        state = List.unmodifiable(_pending);
      }
      _collecting = false;
      _pending.clear();
      return;
    }

    // Collect name tokens from the line. Stop collecting if the line
    // doesn't look like a name row (e.g. the prompt came early).
    final tokens = trimmed.split(RegExp(r'\s+'));
    final names = tokens.where(_nameToken.hasMatch).toList();
    if (names.isEmpty) {
      // Unexpected non-name content; finish what we have.
      if (_pending.isNotEmpty) {
        state = List.unmodifiable(_pending);
      }
      _collecting = false;
      _pending.clear();
      return;
    }
    _pending.addAll(names);
  }

  void clear() {
    _collecting = false;
    _pending.clear();
    state = const [];
  }
}
