import 'dart:ui' show Color;

import '../../models/alias_rule.dart';
import '../../models/area_config_entry.dart';
import '../../models/trigger_rule.dart';

/// Parses and serializes configuration data in human-readable Markdown format.
///
/// Format conventions:
/// - Immersions: `# Highlights` / `# Sounds` / `# Gags` sections
/// - Aliases: `# NN - keyword` headings
/// - `Key: value` property lines
/// - Markdown tables — area-to-path mappings
/// - Ordered lists — sequential items (e.g., battle themes)
class MarkdownConfigParser {
  // ── Immersions (triggers) ──

  /// Parses an `Immersions.md` file into a list of [TriggerRule]s.
  ///
  /// Format: H1 sections `# Highlights`, `# Sounds`, `# Gags`.
  /// Highlights/Sounds have `## NN - Name` entries with `Key: value` props.
  /// Gags are just backtick-wrapped patterns, one per line.
  static List<TriggerRule> parseImmersions(String content) {
    final rules = <TriggerRule>[];
    String section = ''; // 'highlights', 'sounds', 'gags'
    String? currentName;
    String? currentId;
    bool currentEnabled = true;
    final props = <String, String>{};
    int gagIndex = 0;

    void flush() {
      if (currentName != null && props.containsKey('pattern')) {
        final action = switch (section) {
          'sounds' => TriggerAction.playSound,
          'gags' => TriggerAction.gag,
          _ => TriggerAction.highlight,
        };
        rules.add(TriggerRule(
          id: currentId ?? '${_sectionPrefix(section)}_${rules.length}',
          name: currentName!,
          pattern: _stripBackticks(props['pattern'] ?? ''),
          enabled: currentEnabled,
          action: action,
          highlightForeground: _parseColor(props['foreground']),
          highlightBackground: _parseColor(props['background']),
          highlightBold: _parseBool(props['bold']),
          highlightWholeLine: _parseBool(props['whole line']),
          soundPath: props['sound'],
        ));
      }
      props.clear();
      currentName = null;
      currentId = null;
      currentEnabled = true;
    }

    for (final line in content.split('\n')) {
      final trimmed = line.trim();

      // H1 section heading.
      if (trimmed.startsWith('# ') && !trimmed.startsWith('## ')) {
        flush();
        final heading = trimmed.substring(2).trim().toLowerCase();
        if (heading == 'highlights' || heading == 'sounds' || heading == 'gags') {
          section = heading;
          gagIndex = 0;
        }
        continue;
      }

      // Gag section: backtick-wrapped patterns.
      if (section == 'gags') {
        final gagMatch = _backtickRegex.firstMatch(trimmed);
        if (gagMatch != null) {
          rules.add(TriggerRule(
            id: 'gag_$gagIndex',
            name: 'Gag ${gagIndex + 1}',
            pattern: gagMatch.group(1)!,
            action: TriggerAction.gag,
          ));
          gagIndex++;
        }
        continue;
      }

      // H2 entry heading: ## NN - Name or ## NN - Name (disabled)
      final h2Match = _numberedH2Regex.firstMatch(trimmed);
      if (h2Match != null) {
        flush();
        final num = h2Match.group(1)!;
        var name = h2Match.group(2)!.trim();
        currentId = '${_sectionPrefix(section)}_$num';
        if (name.endsWith('(disabled)')) {
          currentEnabled = false;
          name = name.substring(0, name.length - 10).trim();
        }
        currentName = name;
        continue;
      }

      // Property line: Key: value
      if (currentName != null) {
        final propMatch = _kvRegex.firstMatch(trimmed);
        if (propMatch != null) {
          final key = propMatch.group(1)!.trim().toLowerCase();
          final value = propMatch.group(2)!.trim();
          props[key] = value;
        }
      }
    }
    flush();
    return rules;
  }

  /// Serializes a list of [TriggerRule]s to `Immersions.md` format.
  static String serializeImmersions(List<TriggerRule> rules) {
    final highlights = <TriggerRule>[];
    final sounds = <TriggerRule>[];
    final gags = <TriggerRule>[];

    for (final rule in rules) {
      switch (rule.action) {
        case TriggerAction.highlight:
          highlights.add(rule);
        case TriggerAction.playSound:
          sounds.add(rule);
        case TriggerAction.highlightAndSound:
          // Split into both sections.
          highlights.add(rule);
          sounds.add(rule);
        case TriggerAction.gag:
          gags.add(rule);
      }
    }

    final buf = StringBuffer();
    var needsBlank = false;

    if (highlights.isNotEmpty) {
      buf.writeln('# Highlights');
      for (var i = 0; i < highlights.length; i++) {
        buf.writeln();
        final r = highlights[i];
        final num = (i + 1).toString().padLeft(2, '0');
        final suffix = r.enabled ? '' : ' (disabled)';
        buf.writeln('## $num - ${r.name}$suffix');
        buf.writeln('Pattern: `${r.pattern}`');
        if (r.highlightForeground != null) {
          buf.writeln('Foreground: ${_colorToHex(r.highlightForeground!)}');
        }
        if (r.highlightBackground != null) {
          buf.writeln('Background: ${_colorToHex(r.highlightBackground!)}');
        }
        if (r.highlightBold) buf.writeln('Bold: true');
        if (r.highlightWholeLine) buf.writeln('Whole Line: true');
      }
      needsBlank = true;
    }

    if (sounds.isNotEmpty) {
      if (needsBlank) buf.writeln();
      buf.writeln('# Sounds');
      for (var i = 0; i < sounds.length; i++) {
        buf.writeln();
        final r = sounds[i];
        final num = (i + 1).toString().padLeft(2, '0');
        final suffix = r.enabled ? '' : ' (disabled)';
        buf.writeln('## $num - ${r.name}$suffix');
        buf.writeln('Pattern: `${r.pattern}`');
        if (r.soundPath != null) buf.writeln('Sound: ${r.soundPath}');
      }
      needsBlank = true;
    }

    if (gags.isNotEmpty) {
      if (needsBlank) buf.writeln();
      buf.writeln('# Gags');
      buf.writeln();
      for (final r in gags) {
        buf.writeln('`${r.pattern}`');
      }
    }

    return buf.toString();
  }

  static String _sectionPrefix(String section) => switch (section) {
    'highlights' => 'hl',
    'sounds' => 'snd',
    'gags' => 'gag',
    _ => 'trig',
  };

  // ── Aliases ──

  /// Parses an `Aliases.md` file into a list of [AliasRule]s.
  ///
  /// Format: `# NN - keyword` headings with `Expansion:` and `Comments:` props.
  static List<AliasRule> parseAliases(String content) {
    final rules = <AliasRule>[];
    String? currentKeyword;
    String? currentId;
    bool currentEnabled = true;
    final props = <String, String>{};

    void flush() {
      if (currentKeyword != null && props.containsKey('expansion')) {
        rules.add(AliasRule(
          id: currentId ?? 'alias_${rules.length}',
          keyword: currentKeyword!,
          expansion: props['expansion'] ?? '',
          enabled: currentEnabled,
          description: props['comments'],
        ));
      }
      props.clear();
      currentKeyword = null;
      currentId = null;
      currentEnabled = true;
    }

    for (final line in content.split('\n')) {
      final trimmed = line.trim();

      // H1 heading: # NN - keyword or # NN - keyword (disabled)
      final h1Match = _numberedH1Regex.firstMatch(trimmed);
      if (h1Match != null) {
        flush();
        final num = h1Match.group(1)!;
        var keyword = h1Match.group(2)!.trim();
        currentId = 'alias_$num';
        if (keyword.endsWith('(disabled)')) {
          currentEnabled = false;
          keyword = keyword.substring(0, keyword.length - 10).trim();
        }
        currentKeyword = keyword;
        continue;
      }

      // Property line: Key: value
      if (currentKeyword != null) {
        final propMatch = _kvRegex.firstMatch(trimmed);
        if (propMatch != null) {
          final key = propMatch.group(1)!.trim().toLowerCase();
          final value = propMatch.group(2)!.trim();
          props[key] = value;
        }
      }
    }
    flush();
    return rules;
  }

  /// Serializes a list of [AliasRule]s to `Aliases.md` format.
  static String serializeAliases(List<AliasRule> rules) {
    final buf = StringBuffer();
    for (var i = 0; i < rules.length; i++) {
      if (i > 0) buf.writeln();
      final rule = rules[i];
      final num = (i + 1).toString().padLeft(2, '0');
      final suffix = rule.enabled ? '' : ' (disabled)';
      buf.writeln('# $num - ${rule.keyword}$suffix');
      buf.writeln('Expansion: ${rule.expansion}');
      if (rule.description != null && rule.description!.isNotEmpty) {
        buf.writeln('Comments: ${rule.description}');
      }
    }
    return buf.toString();
  }

  // ── Legacy triggers (old format, for migration) ──

  /// Parses old-format `triggers.md` (`## Name` + `- **Key:** value` props).
  static List<TriggerRule> parseLegacyTriggers(String content) {
    final rules = <TriggerRule>[];
    String? currentName;
    final props = <String, String>{};

    void flush() {
      if (currentName != null && props.containsKey('pattern')) {
        rules.add(_buildLegacyTriggerRule(currentName, props, rules.length));
      }
      props.clear();
    }

    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('## ')) {
        flush();
        currentName = trimmed.substring(3).trim();
        continue;
      }
      final propMatch = _propRegex.firstMatch(trimmed);
      if (propMatch != null && currentName != null) {
        final key = propMatch.group(1)!.trim().toLowerCase();
        final value = propMatch.group(2)!.trim();
        props[key] = value;
      }
    }
    flush();
    return rules;
  }

  static TriggerRule _buildLegacyTriggerRule(
    String name,
    Map<String, String> props,
    int index,
  ) {
    return TriggerRule(
      id: props['id'] ?? 'trig_$index',
      name: name,
      pattern: _stripBackticks(props['pattern'] ?? ''),
      enabled: _parseBool(props['enabled'], defaultValue: true),
      action: _parseTriggerAction(props['action']),
      highlightForeground: _parseColor(props['highlight foreground']),
      highlightBackground: _parseColor(props['highlight background']),
      highlightBold: _parseBool(props['highlight bold']),
      highlightWholeLine: _parseBool(props['highlight whole line']),
      soundPath: props['sound'],
    );
  }

  /// Parses old-format `aliases.md` (`## Name` + `- **Key:** value` props).
  static List<AliasRule> parseLegacyAliases(String content) {
    final rules = <AliasRule>[];
    String? currentName;
    final props = <String, String>{};

    void flush() {
      if (currentName != null && props.containsKey('keyword')) {
        rules.add(AliasRule(
          id: props['id'] ?? 'alias_${rules.length}',
          keyword: props['keyword'] ?? '',
          expansion: props['expansion'] ?? '',
          enabled: _parseBool(props['enabled'], defaultValue: true),
          description: props['description'],
        ));
      }
      props.clear();
    }

    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('## ')) {
        flush();
        currentName = trimmed.substring(3).trim();
        continue;
      }
      final propMatch = _propRegex.firstMatch(trimmed);
      if (propMatch != null && currentName != null) {
        final key = propMatch.group(1)!.trim().toLowerCase();
        final value = propMatch.group(2)!.trim();
        props[key] = value;
      }
    }
    flush();
    return rules;
  }

  // ── Area tables (images, audio tracks) ──

  /// Parses a Markdown table with two columns into a `Map<String, String>`.
  ///
  /// The table must have a header row and separator row. The first column
  /// becomes the key and the second column the value.
  static Map<String, String> parseAreaTable(String content) {
    final map = <String, String>{};
    final lines = content.split('\n');

    var inTable = false;
    for (final line in lines) {
      final trimmed = line.trim();

      // Detect table rows (start with |).
      if (!trimmed.startsWith('|')) {
        if (inTable) break; // End of table.
        continue;
      }

      // Skip separator row (| --- | --- |).
      if (_separatorRowRegex.hasMatch(trimmed)) {
        inTable = true;
        continue;
      }

      if (!inTable) {
        // This is the header row — skip it but mark that we've seen a table.
        continue;
      }

      // Parse data row.
      final cells = trimmed
          .split('|')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList();
      if (cells.length >= 2) {
        map[cells[0]] = cells[1];
      }
    }
    return map;
  }

  /// Serializes a `Map<String, String>` as a Markdown table.
  static String serializeAreaTable(
    Map<String, String> map,
    String title,
    String col1,
    String col2,
  ) {
    final buf = StringBuffer('# $title\n\n');
    buf.writeln('| $col1 | $col2 |');
    buf.writeln('|---|---|');
    for (final entry in map.entries) {
      buf.writeln('| ${entry.key} | ${entry.value} |');
    }
    return buf.toString();
  }

  // ── Area audio (table + battle themes list) ──

  /// Parses an `area-audio.md` file into area tracks and battle themes.
  static ({Map<String, String> tracks, List<String> battleThemes})
      parseAreaAudio(String content) {
    final tracks = <String, String>{};
    final battleThemes = <String>[];
    final lines = content.split('\n');

    var section = '';
    var inTable = false;
    var pastHeader = false;

    for (final line in lines) {
      final trimmed = line.trim();

      // Detect section headings.
      if (trimmed.startsWith('## ')) {
        section = trimmed.substring(3).trim().toLowerCase();
        inTable = false;
        pastHeader = false;
        continue;
      }

      if (section == 'area tracks') {
        if (trimmed.startsWith('|')) {
          if (_separatorRowRegex.hasMatch(trimmed)) {
            inTable = true;
            pastHeader = true;
            continue;
          }
          if (!pastHeader) continue; // Header row.
          if (!inTable) continue;

          final cells = trimmed
              .split('|')
              .map((c) => c.trim())
              .where((c) => c.isNotEmpty)
              .toList();
          if (cells.length >= 2) {
            tracks[cells[0]] = cells[1];
          }
        }
      } else if (section == 'battle themes') {
        // Ordered list item: 1. path/to/file.mp3
        final listMatch = _orderedListRegex.firstMatch(trimmed);
        if (listMatch != null) {
          battleThemes.add(listMatch.group(1)!.trim());
        }
      }
    }
    return (tracks: tracks, battleThemes: battleThemes);
  }

  /// Serializes area audio config to Markdown.
  static String serializeAreaAudio(
    Map<String, String> tracks,
    List<String> battleThemes,
  ) {
    final buf = StringBuffer('# Area Audio\n\n');

    buf.writeln('## Area Tracks');
    buf.writeln();
    buf.writeln('| Area | Track |');
    buf.writeln('|---|---|');
    for (final entry in tracks.entries) {
      buf.writeln('| ${entry.key} | ${entry.value} |');
    }

    if (battleThemes.isNotEmpty) {
      buf.writeln();
      buf.writeln('## Battle Themes');
      buf.writeln();
      for (var i = 0; i < battleThemes.length; i++) {
        buf.writeln('${i + 1}. ${battleThemes[i]}');
      }
    }

    return buf.toString();
  }

  // ── Unified area config ──

  /// Parses a unified `Area Configuration.md` into [UnifiedAreaConfig].
  ///
  /// Format:
  /// ```markdown
  /// # AreaName
  /// Coordinates:
  /// - x,y
  ///
  /// Backgrounds:
  /// - /path/to/image.png
  ///
  /// Music:
  /// - /path/to/track.mp3
  ///
  /// # Battle Themes
  /// - /path/to/battle.mp3
  /// ```
  static UnifiedAreaConfig parseUnifiedAreaConfig(String content) {
    final areas = <String, AreaConfigEntry>{};
    final battleThemes = <String>[];
    final lines = content.split('\n');

    String? currentArea;
    String subsection = ''; // 'coordinates', 'backgrounds', 'music', or ''
    var inBattleThemes = false;

    void flush() {
      // Nothing to flush — entries are built incrementally.
    }

    for (final line in lines) {
      final trimmed = line.trim();

      // H1 heading: new area or Battle Themes.
      if (trimmed.startsWith('# ') && !trimmed.startsWith('## ')) {
        flush();
        final heading = trimmed.substring(2).trim();
        if (heading.toLowerCase() == 'battle themes') {
          currentArea = null;
          inBattleThemes = true;
          subsection = '';
          continue;
        }
        currentArea = heading;
        inBattleThemes = false;
        subsection = '';
        areas.putIfAbsent(
            heading,
            () => AreaConfigEntry(name: heading));
        continue;
      }

      // Battle Themes list items.
      if (inBattleThemes) {
        final itemMatch = _unorderedListRegex.firstMatch(trimmed);
        if (itemMatch != null) {
          battleThemes.add(itemMatch.group(1)!.trim());
        }
        continue;
      }

      if (currentArea == null) continue;

      // Subsection labels.
      final lowerTrimmed = trimmed.toLowerCase();
      if (lowerTrimmed == 'coordinates:') {
        subsection = 'coordinates';
        continue;
      }
      if (lowerTrimmed == 'backgrounds:') {
        subsection = 'backgrounds';
        continue;
      }
      if (lowerTrimmed == 'music:') {
        subsection = 'music';
        continue;
      }

      // List items under a subsection.
      final itemMatch = _unorderedListRegex.firstMatch(trimmed);
      if (itemMatch != null && subsection.isNotEmpty) {
        final value = itemMatch.group(1)!.trim();
        if (value.isEmpty) continue;

        final areaName = currentArea;
        final entry = areas[areaName]!;
        switch (subsection) {
          case 'coordinates':
            areas[areaName] = entry.copyWith(
              coordinates: [...entry.coordinates, value],
            );
          case 'backgrounds':
            areas[areaName] = entry.copyWith(
              backgrounds: [...entry.backgrounds, value],
            );
          case 'music':
            areas[areaName] = entry.copyWith(
              music: [...entry.music, value],
            );
        }
      }
    }

    return UnifiedAreaConfig(areas: areas, battleThemes: battleThemes);
  }

  /// Serializes a [UnifiedAreaConfig] to Markdown.
  static String serializeUnifiedAreaConfig(UnifiedAreaConfig config) {
    final buf = StringBuffer();
    var first = true;

    for (final entry in config.areas.values) {
      if (!first) buf.writeln();
      first = false;

      buf.writeln('# ${entry.name}');

      if (entry.coordinates.isNotEmpty) {
        buf.writeln('Coordinates:');
        for (final coord in entry.coordinates) {
          buf.writeln('- $coord');
        }
      }

      if (entry.backgrounds.isNotEmpty) {
        if (entry.coordinates.isNotEmpty) buf.writeln();
        buf.writeln('Backgrounds:');
        for (final bg in entry.backgrounds) {
          buf.writeln('- $bg');
        }
      }

      if (entry.music.isNotEmpty) {
        if (entry.coordinates.isNotEmpty || entry.backgrounds.isNotEmpty) {
          buf.writeln();
        }
        buf.writeln('Music:');
        for (final m in entry.music) {
          buf.writeln('- $m');
        }
      }
    }

    if (config.battleThemes.isNotEmpty) {
      if (config.areas.isNotEmpty) buf.writeln();
      buf.writeln('# Battle Themes');
      for (final theme in config.battleThemes) {
        buf.writeln('- $theme');
      }
    }

    return buf.toString();
  }

  // ── Helpers ──

  /// Matches `## NN - Name` headings (for immersions).
  static final _numberedH2Regex = RegExp(r'^## (\d+) - (.+)$');

  /// Matches `# NN - Name` headings (for aliases).
  static final _numberedH1Regex = RegExp(r'^# (\d+) - (.+)$');

  /// Matches simple `Key: value` property lines.
  static final _kvRegex = RegExp(r'^(\w[\w\s]*?):\s+(.+)$');

  /// Matches backtick-wrapped patterns like `` `regex` ``.
  static final _backtickRegex = RegExp(r'^`(.+)`$');

  /// Matches `- **Key:** value` (legacy format).
  static final _propRegex =
      RegExp(r'^-\s+\*\*(.+?):\*\*\s*(.*)$');

  /// Matches a table separator row like `| --- | --- |`.
  static final _separatorRowRegex = RegExp(r'^\|[\s\-:|]+\|$');

  /// Matches ordered list items like `1. path`.
  static final _orderedListRegex = RegExp(r'^\d+\.\s+(.+)$');

  /// Matches unordered list items like `- value`.
  static final _unorderedListRegex = RegExp(r'^-\s+(.+)$');

  static String _stripBackticks(String s) {
    if (s.startsWith('`') && s.endsWith('`') && s.length >= 2) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }

  static bool _parseBool(String? value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    return value.toLowerCase() == 'true';
  }

  static TriggerAction _parseTriggerAction(String? value) {
    if (value == null) return TriggerAction.highlight;
    for (final action in TriggerAction.values) {
      if (action.name.toLowerCase() == value.toLowerCase()) return action;
    }
    return TriggerAction.highlight;
  }

  static Color? _parseColor(String? value) {
    if (value == null || value.isEmpty) return null;
    var hex = value.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex'; // Add alpha.
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  static String _colorToHex(Color color) {
    final argb = color.toARGB32();
    // If fully opaque, use 6-digit hex.
    if ((argb >> 24) == 0xFF) {
      return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    }
    return '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }
}
