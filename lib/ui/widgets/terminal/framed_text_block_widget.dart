import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/theme/terminal_colors.dart';
import '../../../models/framed_text_block.dart';
import '../../../protocol/ansi/styled_span.dart';

/// Renders a [FramedTextBlock] as a parchment / burnt-paper card: warm
/// yellowish background, dark-brown text, with the MUD-native `+---+` and
/// `|` frame characters already stripped upstream so the widget frames
/// itself cleanly.
class FramedTextBlockWidget extends StatelessWidget {
  final FramedTextBlock block;
  final double fontSize;

  const FramedTextBlockWidget({
    super.key,
    required this.block,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final papyrus = brightness == Brightness.dark
        ? const Color(0xFFE8D5A8)
        : const Color(0xFFF4E5C3);
    const ink = Color(0xFF2A1F0F);
    const edge = Color(0xFF8B7355);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Container(
        decoration: BoxDecoration(
          color: papyrus,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: edge, width: 1.0),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in block.lines)
              _FramedTextLine(line: line, fontSize: fontSize, ink: ink),
          ],
        ),
      ),
    );
  }
}

class _FramedTextLine extends StatelessWidget {
  final StyledLine line;
  final double fontSize;
  final Color ink;

  const _FramedTextLine({
    required this.line,
    required this.fontSize,
    required this.ink,
  });

  @override
  Widget build(BuildContext context) {
    if (line.spans.isEmpty) {
      return Text(
        ' ',
        style: TextStyle(
          fontFamily: TerminalDefaults.fontFamily,
          fontSize: fontSize,
          color: ink,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        children: [
          for (final span in line.spans)
            TextSpan(
              text: span.displayText,
              style: TextStyle(
                fontFamily: TerminalDefaults.fontFamily,
                fontSize: fontSize,
                // Default MUD foreground on parchment would be illegible;
                // swap to ink. Trigger-coloured spans (anything the user
                // explicitly styled) keep their colour.
                color: span.foreground == TerminalColors.defaultForeground
                    ? ink
                    : span.foreground,
                fontWeight: span.bold ? FontWeight.bold : FontWeight.normal,
                fontStyle: span.italic ? FontStyle.italic : FontStyle.normal,
                decoration: span.underline
                    ? TextDecoration.underline
                    : (span.strikethrough
                        ? TextDecoration.lineThrough
                        : TextDecoration.none),
              ),
            ),
        ],
      ),
      softWrap: false,
    );
  }
}
