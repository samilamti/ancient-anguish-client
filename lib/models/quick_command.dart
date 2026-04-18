/// A user-configurable shortcut button shown on mobile.
///
/// Each command renders as a single icon button in the quick-command row.
/// Tapping sends [command] directly, or — if [selectTarget] is true —
/// opens a target picker seeded from recent MUD words and appends the
/// chosen target (e.g. "kill" + "rabbit" → "kill rabbit").
class QuickCommand {
  final String id;
  final String label;
  final String iconName;
  final String command;
  final bool selectTarget;
  final bool enabled;

  const QuickCommand({
    required this.id,
    required this.label,
    required this.iconName,
    required this.command,
    this.selectTarget = false,
    this.enabled = true,
  });

  QuickCommand copyWith({
    String? id,
    String? label,
    String? iconName,
    String? command,
    bool? selectTarget,
    bool? enabled,
  }) {
    return QuickCommand(
      id: id ?? this.id,
      label: label ?? this.label,
      iconName: iconName ?? this.iconName,
      command: command ?? this.command,
      selectTarget: selectTarget ?? this.selectTarget,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'iconName': iconName,
        'command': command,
        'selectTarget': selectTarget,
        'enabled': enabled,
      };

  factory QuickCommand.fromJson(Map<String, dynamic> json) => QuickCommand(
        id: json['id'] as String,
        label: json['label'] as String,
        iconName: json['iconName'] as String,
        command: json['command'] as String,
        selectTarget: json['selectTarget'] as bool? ?? false,
        enabled: json['enabled'] as bool? ?? true,
      );

  /// The four built-in defaults for a fresh install.
  static const List<QuickCommand> defaults = [
    QuickCommand(
      id: 'default_look',
      label: 'Look',
      iconName: 'eye',
      command: 'look',
    ),
    QuickCommand(
      id: 'default_kill',
      label: 'Kill',
      iconName: 'skull',
      command: 'kill',
      selectTarget: true,
    ),
    QuickCommand(
      id: 'default_loot',
      label: 'Loot',
      iconName: 'treasure',
      command: 'get all from corpse',
    ),
    QuickCommand(
      id: 'default_inventory',
      label: 'Inventory',
      iconName: 'bag',
      command: 'inventory',
    ),
  ];
}
