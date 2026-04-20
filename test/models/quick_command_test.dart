import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/quick_command.dart';

void main() {
  group('QuickCommand - defaults', () {
    test('bundles kill, loot, inventory (Look lives in the D-Pad)', () {
      final labels = QuickCommand.defaults.map((c) => c.label).toList();
      expect(labels, ['Kill', 'Loot', 'Inventory']);
    });

    test('kill is the only selectTarget default', () {
      for (final cmd in QuickCommand.defaults) {
        expect(cmd.selectTarget, cmd.label == 'Kill');
      }
    });

    test('loot sends "get all from corpse"', () {
      final loot = QuickCommand.defaults.firstWhere((c) => c.label == 'Loot');
      expect(loot.command, 'get all from corpse');
    });
  });

  group('QuickCommand - copyWith', () {
    test('preserves unspecified fields', () {
      const cmd = QuickCommand(
        id: 'q1',
        label: 'Look',
        iconName: 'eye',
        command: 'look',
      );
      final copied = cmd.copyWith(enabled: false);
      expect(copied.id, 'q1');
      expect(copied.label, 'Look');
      expect(copied.iconName, 'eye');
      expect(copied.command, 'look');
      expect(copied.selectTarget, isFalse);
      expect(copied.enabled, isFalse);
    });
  });

  group('QuickCommand - JSON round-trip', () {
    test('preserves all fields', () {
      const original = QuickCommand(
        id: 'q1',
        label: 'Kill',
        iconName: 'skull',
        command: 'kill',
        selectTarget: true,
        enabled: false,
      );

      final json = original.toJson();
      final restored = QuickCommand.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.label, original.label);
      expect(restored.iconName, original.iconName);
      expect(restored.command, original.command);
      expect(restored.selectTarget, original.selectTarget);
      expect(restored.enabled, original.enabled);
    });

    test('defaults selectTarget to false and enabled to true when missing', () {
      final json = {
        'id': 'q1',
        'label': 'Look',
        'iconName': 'eye',
        'command': 'look',
      };
      final cmd = QuickCommand.fromJson(json);
      expect(cmd.selectTarget, isFalse);
      expect(cmd.enabled, isTrue);
    });
  });
}
