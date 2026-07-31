import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../protocol/ansi/styled_span.dart';
import '../../../providers/framed_text_block_provider.dart';
import '../../../providers/map_block_provider.dart';
import 'framed_text_block_widget.dart';
import 'map_block_widget.dart';
import 'terminal_selection.dart';

/// A single line of styled terminal output.
///
/// Renders a [StyledLine] as a [RichText] with the terminal's monospace
/// font. Recognises two sentinel line forms inserted by the buffer:
/// map blocks (rendered as a painted tile grid) and framed text blocks
/// (rendered as a parchment card).
class TerminalLine extends StatelessWidget {
  final StyledLine line;
  final int lineIndex;
  final TerminalSelection? selection;
  final double fontSize;
  final void Function(String command)? onCommandTap;
  final void Function(String command)? onCommandLongPress;

  /// Extra vertical breathing room, split evenly above and below the text.
  /// Driven by the line-spacing setting; the terminal's hit-testing folds the
  /// same value into its line-height maths, so the two must not diverge.
  final double extraSpacing;

  const TerminalLine({
    super.key,
    required this.line,
    required this.lineIndex,
    this.selection,
    required this.fontSize,
    this.onCommandTap,
    this.onCommandLongPress,
    this.extraSpacing = 0,
  });

  /// Half the extra spacing on each side, on top of the baseline 0.5.
  EdgeInsets get _padding =>
      EdgeInsets.symmetric(vertical: 0.5 + extraSpacing / 2);

  @override
  Widget build(BuildContext context) {
    if (line.spans.isEmpty) {
      return Padding(
        padding: _padding,
        child: RichText(
          text: TextSpan(
            text: ' ',
            style: TextStyle(
              fontFamily: TerminalDefaults.fontFamily,
              fontSize: fontSize,
            ),
          ),
        ),
      );
    }

    final blockId = tryParseBlockId(line.plainText);
    if (blockId != null) {
      return Consumer(
        builder: (context, ref, _) {
          final block = ref.watch(mapBlocksProvider)[blockId];
          if (block == null) return const SizedBox.shrink();
          return MapBlockWidget(block: block, fontSize: fontSize);
        },
      );
    }

    final framedId = tryParseFramedBlockId(line.plainText);
    if (framedId != null) {
      return Consumer(
        builder: (context, ref, _) {
          final block = ref.watch(framedTextBlocksProvider)[framedId];
          if (block == null) return const SizedBox.shrink();
          return FramedTextBlockWidget(block: block, fontSize: fontSize);
        },
      );
    }

    final range = selection?.selectedRangeForLine(
      lineIndex,
      line.plainText.length,
    );

    final textSpan = range != null
        ? line.toSelectedTextSpan(
            fontFamily: TerminalDefaults.fontFamily,
            fontSize: fontSize,
            startCol: range.startCol,
            endCol: range.endCol,
            onCommandTap: onCommandTap,
            onCommandLongPress: onCommandLongPress,
          )
        : line.toTextSpan(
            fontFamily: TerminalDefaults.fontFamily,
            fontSize: fontSize,
            onCommandTap: onCommandTap,
            onCommandLongPress: onCommandLongPress,
          );

    return Padding(
      padding: _padding,
      child: RichText(
        text: textSpan,
        softWrap: true,
      ),
    );
  }
}
