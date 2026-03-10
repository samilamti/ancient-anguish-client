import 'package:flutter/painting.dart';

import '../../core/theme/terminal_colors.dart';

/// A styled segment of terminal text, produced by [AnsiParser].
///
/// Carries the text content plus all ANSI styling attributes. Can be converted
/// to a Flutter [TextSpan] for rendering in [RichText] widgets.
class StyledSpan {
  final String text;
  final Color foreground;
  final Color background;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;

  const StyledSpan({
    required this.text,
    this.foreground = TerminalColors.defaultForeground,
    this.background = TerminalColors.defaultBackground,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
  });

  /// Converts this styled span to a Flutter [TextSpan].
  ///
  /// Uses [fontFamily] and [fontSize] for the base text style.
  TextSpan toTextSpan({
    required String fontFamily,
    required double fontSize,
  }) {
    return TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        color: foreground,
        backgroundColor:
            background == TerminalColors.defaultBackground ? null : background,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        decoration: _textDecoration,
      ),
    );
  }

  TextDecoration get _textDecoration {
    final decorations = <TextDecoration>[];
    if (underline) decorations.add(TextDecoration.underline);
    if (strikethrough) decorations.add(TextDecoration.lineThrough);
    if (decorations.isEmpty) return TextDecoration.none;
    return TextDecoration.combine(decorations);
  }

  @override
  String toString() => 'StyledSpan("$text", bold=$bold, fg=$foreground)';
}

/// A complete line of styled terminal output, composed of one or more
/// [StyledSpan] segments.
class StyledLine {
  final List<StyledSpan> spans;

  /// The raw text content of this line (without styling).
  late final String plainText = spans.map((s) => s.text).join();

  StyledLine(this.spans);

  /// Converts this line to a Flutter [TextSpan] tree.
  TextSpan toTextSpan({
    required String fontFamily,
    required double fontSize,
  }) {
    if (spans.length == 1) {
      return spans.first.toTextSpan(fontFamily: fontFamily, fontSize: fontSize);
    }
    return TextSpan(
      children: spans
          .map((s) => s.toTextSpan(fontFamily: fontFamily, fontSize: fontSize))
          .toList(),
    );
  }

  /// Creates an empty (blank) line.
  factory StyledLine.empty() => StyledLine(const []);

  @override
  String toString() => 'StyledLine("$plainText")';
}
