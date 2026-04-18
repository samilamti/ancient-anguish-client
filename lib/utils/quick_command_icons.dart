import 'package:flutter/material.dart';

// Stock Flutter Material Icons has no dedicated skull glyph, so 'skull' maps to
// Icons.dangerous (circular skull-and-crossbones warning) as the closest visual
// analogue. Swapping in a real skull would require pulling in material_symbols.
const Map<String, IconData> _kIcons = {
  'eye': Icons.visibility,
  'skull': Icons.dangerous,
  'treasure': Icons.diamond,
  'bag': Icons.backpack,
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

IconData iconFromName(String name) => _kIcons[name] ?? Icons.bolt;

List<String> availableIconNames() => _kIcons.keys.toList(growable: false);
