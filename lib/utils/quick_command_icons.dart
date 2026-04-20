import 'package:flutter/material.dart';

const Map<String, IconData> _kIcons = {
  'eye': Icons.visibility,
  'sword': Icons.sports_martial_arts,
  'shield': Icons.shield,
  'heart': Icons.favorite,
  'magic': Icons.auto_awesome,
  'scroll': Icons.description,
  'map': Icons.map,
  'person': Icons.person,
  'group': Icons.groups,
  'flee': Icons.directions_run,
  'home': Icons.home,
  'search': Icons.search,
  'north': Icons.arrow_upward,
  'south': Icons.arrow_downward,
  'east': Icons.arrow_forward,
  'west': Icons.arrow_back,
  'up': Icons.keyboard_arrow_up,
  'down': Icons.keyboard_arrow_down,
};

/// Icon names that render as a Unicode emoji instead of a Material Icon.
/// Material's core font has no glyphs for these, and the emoji reads better
/// on mobile anyway.
const Map<String, String> _kEmojis = {
  'skull': '💀',
  'bag': '🎒',
  'treasure': '🪎',
};

/// Canonical order of picker entries — emoji names first so they're easy to
/// find, followed by the Material icons.
List<String> availableIconNames() =>
    [..._kEmojis.keys, ..._kIcons.keys];

/// Returns a rendered leading widget for the given icon name, choosing
/// between an emoji glyph and a Material icon. Unknown names fall back to
/// [Icons.bolt]. Use [size] and [color] to match the surrounding widget.
Widget iconWidgetFromName(
  String name, {
  double size = 20,
  Color? color,
}) {
  final emoji = _kEmojis[name];
  if (emoji != null) {
    // Emoji glyphs render smaller than Material icons at the same nominal
    // size; bump the font size a little so they land visually balanced.
    return Text(
      emoji,
      style: TextStyle(fontSize: size, height: 1.0),
    );
  }
  return Icon(_kIcons[name] ?? Icons.bolt, size: size, color: color);
}
