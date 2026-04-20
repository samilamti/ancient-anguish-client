import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';
import 'package:ancient_anguish_client/services/parser/map_emoji_transformer.dart';

StyledLine _line(String text) => StyledLine([StyledSpan(text: text)]);

void main() {
  group('MapEmojiTransformer.isMapContent', () {
    test('accepts a pipe-framed row', () {
      expect(
        MapEmojiTransformer.isMapContent('| /\\ oo OO ~~ == |'),
        isTrue,
      );
    });

    test('rejects a border line', () {
      expect(
        MapEmojiTransformer.isMapContent(
            '+-------------------------------------+'),
        isFalse,
      );
    });

    test('rejects a plain room description', () {
      expect(
        MapEmojiTransformer.isMapContent('You stand in a grassy field.'),
        isFalse,
      );
    });

    test('tolerates trailing whitespace', () {
      expect(
        MapEmojiTransformer.isMapContent('| oo oo |   '),
        isTrue,
      );
    });
  });

  group('MapEmojiTransformer.processLine — content transform', () {
    test('replaces known terrain tiles in a full row', () {
      final input = _line('| /\\ oo OO ~~ == |');
      final out = MapEmojiTransformer.processLine(input);
      expect(out.plainText, '| 🏔️ 🌿 🌲 🌊 🟫 |');
    });

    test('passes unknown tiles through unchanged', () {
      final input = _line('| /\\ xy oo |');
      final out = MapEmojiTransformer.processLine(input);
      expect(out.plainText, '| 🏔️ xy 🌿 |');
    });

    test('collapses road overlays to 🟫 except bridge', () {
      final input = _line('| +o +O +^ +" +@ +| |');
      final out = MapEmojiTransformer.processLine(input);
      expect(out.plainText, '| 🟫 🟫 🟫 🟫 🟫 🌉 |');
    });

    test('replaces <[]> player marker with 🔴 + ZWJ sentinel', () {
      // Use a contiguous chunk since the live data has no spaces around
      // the marker (see Tantallon world map sample).
      final input = _line('| +|<[]>== |');
      final out = MapEmojiTransformer.processLine(input);
      expect(out.plainText, '| +|${MapEmojiTransformer.playerMarker}== |');
    });

    test('leaves border lines untouched', () {
      final input = _line('+----------------------+');
      final out = MapEmojiTransformer.processLine(input);
      expect(identical(out, input), isTrue);
    });

    test('leaves non-map lines untouched', () {
      final input = _line('Mokkil chats: /\\ oo OO — looks like a map row');
      final out = MapEmojiTransformer.processLine(input);
      expect(identical(out, input), isTrue);
    });

    test('returns the original line when nothing matched', () {
      final input = _line('| xy zz |');
      final out = MapEmojiTransformer.processLine(input);
      expect(identical(out, input), isTrue);
    });
  });

  group('MapEmojiTransformer.processLine — style preservation', () {
    test('keeps per-span foreground colours on transformed glyphs', () {
      const blue = Color(0xFF0000FF);
      const green = Color(0xFF00FF00);
      final line = StyledLine([
        const StyledSpan(text: '| '),
        const StyledSpan(text: '~~', foreground: blue),
        const StyledSpan(text: ' '),
        const StyledSpan(text: 'OO', foreground: green),
        const StyledSpan(text: ' |'),
      ]);
      final out = MapEmojiTransformer.processLine(line);
      // Water tile keeps blue, forest tile keeps green.
      final waterSpan = out.spans.firstWhere((s) => s.text == '🌊');
      final forestSpan = out.spans.firstWhere((s) => s.text == '🌲');
      expect(waterSpan.foreground, blue);
      expect(forestSpan.foreground, green);
    });

    test('preserves bold/italic flags on transformed glyphs', () {
      final line = StyledLine([
        const StyledSpan(text: '| '),
        const StyledSpan(text: '##', bold: true, italic: true),
        const StyledSpan(text: ' |'),
      ]);
      final out = MapEmojiTransformer.processLine(line);
      final wallSpan = out.spans.firstWhere((s) => s.text == '🧱');
      expect(wallSpan.bold, isTrue);
      expect(wallSpan.italic, isTrue);
    });
  });
}
