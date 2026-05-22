import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/quick_command.dart';
import '../../../providers/common_targets_provider.dart';
import '../../../providers/connection_provider.dart';
import 'target_picker_sheet.dart';

/// Runs a [QuickCommand]: sends it directly, or — for `selectTarget: true` —
/// opens the target picker and appends the chosen target (e.g. "kill" +
/// "goblin" → "kill goblin"). Falls back to pre-filling the input when no
/// targets are available.
Future<void> runQuickCommand(
  BuildContext context,
  WidgetRef ref,
  QuickCommand cmd,
) async {
  final service = ref.read(connectionServiceProvider);

  if (!cmd.selectTarget) {
    service.sendCommand(cmd.command);
    return;
  }

  final targets = ref.read(commonTargetsProvider);
  if (targets.isEmpty) {
    // The static list is never empty in practice, but keep the safety hatch:
    // pre-fill the input so the user can type the target themselves.
    final controller = ref.read(inputControllerProvider);
    final prefix = '${cmd.command} ';
    controller.text = prefix;
    controller.selection = TextSelection.collapsed(offset: prefix.length);
    ref.read(inputFocusProvider).requestFocus();
    return;
  }

  final chosen = await TargetPickerSheet.show(
    context,
    commandLabel: cmd.label,
  );
  if (chosen == null || chosen.isEmpty) return;
  service.sendCommand('${cmd.command} $chosen');
}
