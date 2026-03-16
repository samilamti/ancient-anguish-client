import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show SystemMouseCursors;
import 'package:url_launcher/url_launcher.dart';

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
  final Uri? link;

  const StyledSpan({
    required this.text,
    this.foreground = TerminalColors.defaultForeground,
    this.background = TerminalColors.defaultBackground,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.link,
  });

  /// Display text — strips http(s):// prefix for link spans.
  String get displayText {
    if (link == null) return text;
    return text
        .replaceFirst(RegExp(r'^https://'), '')
        .replaceFirst(RegExp(r'^http://'), '');
  }

  /// Converts this styled span to a Flutter [TextSpan].
  ///
  /// Uses [fontFamily] and [fontSize] for the base text style.
  TextSpan toTextSpan({
    required String fontFamily,
    required double fontSize,
  }) {
    final isLink = link != null;
    return TextSpan(
      text: displayText,
      style: TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        color: foreground,
        backgroundColor:
            background == TerminalColors.defaultBackground ? null : background,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        decoration: isLink ? TextDecoration.underline : _textDecoration,
        decorationColor: isLink ? foreground : null,
        shadows: const [
          Shadow(color: Color(0xFF000000), blurRadius: 1.0),
        ],
      ),
      recognizer: isLink
          ? (TapGestureRecognizer()
            ..onTap = () => launchUrl(link!, mode: LaunchMode.externalApplication))
          : null,
      mouseCursor: isLink ? SystemMouseCursors.click : null,
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

  /// Returns a [TextSpan] tree with inverse colors on the selected range.
  ///
  /// Characters in `[startCol, endCol)` get their foreground and background
  /// swapped (the classic terminal "inverse video" selection highlight).
  /// Characters outside the range render normally.
  TextSpan toSelectedTextSpan({
    required String fontFamily,
    required double fontSize,
    required int startCol,
    required int endCol,
  }) {
    final children = <TextSpan>[];
    var offset = 0;

    for (final span in spans) {
      final spanStart = offset;
      final spanEnd = offset + span.text.length;

      if (spanEnd <= startCol || spanStart >= endCol) {
        // Entirely outside selection.
        children.add(span.toTextSpan(
          fontFamily: fontFamily,
          fontSize: fontSize,
        ));
      } else {
        // Partially or fully inside selection – split at boundaries.
        if (spanStart < startCol) {
          // Unselected prefix.
          children.add(StyledSpan(
            text: span.text.substring(0, startCol - spanStart),
            foreground: span.foreground,
            background: span.background,
            bold: span.bold,
            italic: span.italic,
            underline: span.underline,
            strikethrough: span.strikethrough,
          ).toTextSpan(fontFamily: fontFamily, fontSize: fontSize));
        }

        // Selected middle.
        final selStart = (startCol - spanStart).clamp(0, span.text.length);
        final selEnd = (endCol - spanStart).clamp(0, span.text.length);
        children.add(StyledSpan(
          text: span.text.substring(selStart, selEnd),
          foreground: span.background,
          background: span.foreground,
          bold: span.bold,
          italic: span.italic,
          underline: span.underline,
          strikethrough: span.strikethrough,
        ).toTextSpan(fontFamily: fontFamily, fontSize: fontSize));

        if (spanEnd > endCol) {
          // Unselected suffix.
          children.add(StyledSpan(
            text: span.text.substring(endCol - spanStart),
            foreground: span.foreground,
            background: span.background,
            bold: span.bold,
            italic: span.italic,
            underline: span.underline,
            strikethrough: span.strikethrough,
          ).toTextSpan(fontFamily: fontFamily, fontSize: fontSize));
        }
      }

      offset = spanEnd;
    }

    if (children.length == 1) return children.first;
    return TextSpan(children: children);
  }

  /// Returns a new [StyledLine] with the first [startCol] characters removed.
  StyledLine subLine(int startCol) {
    if (startCol <= 0) return this;
    final result = <StyledSpan>[];
    var offset = 0;
    for (final span in spans) {
      final spanEnd = offset + span.text.length;
      if (spanEnd <= startCol) {
        // Entire span is before startCol — skip.
      } else if (offset >= startCol) {
        // Entire span is after startCol — keep.
        result.add(span);
      } else {
        // Span straddles startCol — keep the tail.
        result.add(StyledSpan(
          text: span.text.substring(startCol - offset),
          foreground: span.foreground,
          background: span.background,
          bold: span.bold,
          italic: span.italic,
          underline: span.underline,
          strikethrough: span.strikethrough,
          link: span.link,
        ));
      }
      offset = spanEnd;
    }
    return StyledLine(result);
  }

  /// Returns a new [StyledLine] with characters in `[start, end)` removed.
  StyledLine removeRange(int start, int end) {
    if (start >= end) return this;
    final result = <StyledSpan>[];
    var offset = 0;
    for (final span in spans) {
      final spanStart = offset;
      final spanEnd = offset + span.text.length;

      if (spanEnd <= start || spanStart >= end) {
        // Entirely outside removal range — keep.
        result.add(span);
      } else {
        // Partially or fully inside removal range.
        final keepBefore = start > spanStart
            ? span.text.substring(0, start - spanStart)
            : '';
        final keepAfter = end < spanEnd
            ? span.text.substring(end - spanStart)
            : '';
        final kept = keepBefore + keepAfter;
        if (kept.isNotEmpty) {
          result.add(StyledSpan(
            text: kept,
            foreground: span.foreground,
            background: span.background,
            bold: span.bold,
            italic: span.italic,
            underline: span.underline,
            strikethrough: span.strikethrough,
            link: span.link,
          ));
        }
      }
      offset = spanEnd;
    }
    return StyledLine(result);
  }

  /// Returns a new [StyledLine] with a plain text span prepended.
  StyledLine prepend(String text, {Color foreground = TerminalColors.defaultForeground}) {
    return StyledLine([
      StyledSpan(text: text, foreground: foreground),
      ...spans,
    ]);
  }

  /// Creates an empty (blank) line.
  factory StyledLine.empty() => StyledLine(const []);

  @override
  String toString() => 'StyledLine("$plainText")';
}
