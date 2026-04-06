import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/protocol/ansi/styled_span.dart';
import 'package:ancient_anguish_client/services/parser/emoji_parser.dart';

void main() {
  group('EmojiParser.replaceEmoticons', () {
    test('replaces basic smiley', () {
      expect(EmojiParser.replaceEmoticons('hello :) world'),
          equals('hello \u{1F642} world'));
    });

    test('replaces nose-variant smiley', () {
      expect(EmojiParser.replaceEmoticons('hello :-) world'),
          equals('hello \u{1F642} world'));
    });

    test('replaces frown', () {
      expect(EmojiParser.replaceEmoticons('oh no :('),
          equals('oh no \u{1F641}'));
    });

    test('replaces grin', () {
      expect(EmojiParser.replaceEmoticons(':D'),
          equals('\u{1F600}'));
    });

    test('replaces wink', () {
      expect(EmojiParser.replaceEmoticons(';)'),
          equals('\u{1F609}'));
    });

    test('replaces tongue', () {
      expect(EmojiParser.replaceEmoticons(':P'),
          equals('\u{1F61B}'));
      expect(EmojiParser.replaceEmoticons(':p'),
          equals('\u{1F61B}'));
    });

    test('replaces laughing XD', () {
      expect(EmojiParser.replaceEmoticons('lol XD'),
          equals('lol \u{1F606}'));
      expect(EmojiParser.replaceEmoticons('lol xD'),
          equals('lol \u{1F606}'));
    });

    test('replaces open mouth', () {
      expect(EmojiParser.replaceEmoticons(':O'),
          equals('\u{1F62E}'));
      expect(EmojiParser.replaceEmoticons(':o'),
          equals('\u{1F62F}'));
    });

    test('replaces confused', () {
      expect(EmojiParser.replaceEmoticons('hmm :/'),
          equals('hmm \u{1F615}'));
    });

    test('replaces crying', () {
      expect(EmojiParser.replaceEmoticons(":'("),
          equals('\u{1F622}'));
    });

    test('replaces angry', () {
      expect(EmojiParser.replaceEmoticons('>:('),
          equals('\u{1F620}'));
    });

    test('replaces devil grin', () {
      expect(EmojiParser.replaceEmoticons('>:)'),
          equals('\u{1F608}'));
    });

    test('replaces sunglasses', () {
      expect(EmojiParser.replaceEmoticons('B)'),
          equals('\u{1F60E}'));
    });

    test('replaces angel', () {
      expect(EmojiParser.replaceEmoticons('O:)'),
          equals('\u{1F607}'));
      expect(EmojiParser.replaceEmoticons('0:)'),
          equals('\u{1F607}'));
    });

    test('replaces neutral', () {
      expect(EmojiParser.replaceEmoticons(':|'),
          equals('\u{1F610}'));
    });

    test('replaces heart', () {
      expect(EmojiParser.replaceEmoticons('love <3'),
          equals('love \u{2764}\u{FE0F}'));
    });

    test('replaces broken heart', () {
      expect(EmojiParser.replaceEmoticons('</3'),
          equals('\u{1F494}'));
    });

    test('replaces kaomoji', () {
      expect(EmojiParser.replaceEmoticons('^_^'),
          equals('\u{1F60A}'));
      expect(EmojiParser.replaceEmoticons('-_-'),
          equals('\u{1F611}'));
      expect(EmojiParser.replaceEmoticons('T_T'),
          equals('\u{1F62D}'));
      expect(EmojiParser.replaceEmoticons('o_O'),
          equals('\u{1F928}'));
      expect(EmojiParser.replaceEmoticons('O_o'),
          equals('\u{1F928}'));
    });

    test('replaces metal horns', () {
      expect(EmojiParser.replaceEmoticons(r'\m/'),
          equals('\u{1F918}'));
    });

    test('replaces kiss', () {
      expect(EmojiParser.replaceEmoticons(':*'),
          equals('\u{1F618}'));
    });

    test('replaces thumbs up', () {
      expect(EmojiParser.replaceEmoticons('(y)'),
          equals('\u{1F44D}'));
      // (n) removed — conflicts with MUD direction paths like (n) for north.
      expect(EmojiParser.replaceEmoticons('(n)'), equals('(n)'));
    });

    test('replaces multiple emoticons in one string', () {
      expect(
        EmojiParser.replaceEmoticons('hello :) how are you :D'),
        equals('hello \u{1F642} how are you \u{1F600}'),
      );
    });

    test('replaces adjacent emoticons', () {
      expect(
        EmojiParser.replaceEmoticons(':):D'),
        equals('\u{1F642}\u{1F600}'),
      );
    });

    test('returns original string when no emoticons', () {
      const text = 'no emoticons here';
      final result = EmojiParser.replaceEmoticons(text);
      expect(identical(result, text), isTrue);
    });

    test('returns original string for empty input', () {
      const text = '';
      final result = EmojiParser.replaceEmoticons(text);
      expect(identical(result, text), isTrue);
    });

    test('longest match wins: >:) matches devil not > + smiley', () {
      final result = EmojiParser.replaceEmoticons('>:)');
      expect(result, equals('\u{1F608}')); // devil, not ">" + smiley
    });

    test('longest match wins: </3 matches broken heart not <3', () {
      final result = EmojiParser.replaceEmoticons('</3');
      expect(result, equals('\u{1F494}')); // broken heart
    });

    test('preserves URLs with :// intact', () {
      const url = 'https://github.com/user/repo';
      expect(EmojiParser.replaceEmoticons(url), equals(url));
    });

    test('preserves http URLs', () {
      const url = 'http://example.com/path?q=1';
      expect(EmojiParser.replaceEmoticons(url), equals(url));
    });

    test('preserves URL but replaces emoticon outside it', () {
      expect(
        EmojiParser.replaceEmoticons('check https://x.com/path :)'),
        equals('check https://x.com/path \u{1F642}'),
      );
    });

    test('preserves multiple URLs in same string', () {
      const text = 'see https://a.com and http://b.com/foo';
      expect(EmojiParser.replaceEmoticons(text), equals(text));
    });

    test('does not false-positive on HP: 100', () {
      const text = 'HP: 100  SP: 50';
      expect(EmojiParser.replaceEmoticons(text), equals(text));
    });

    test('does not false-positive on timestamps', () {
      const text = '10:00 AM';
      expect(EmojiParser.replaceEmoticons(text), equals(text));
    });

    test('emoticon at start of line', () {
      expect(EmojiParser.replaceEmoticons(':) hello'),
          equals('\u{1F642} hello'));
    });

    test('emoticon at end of line', () {
      expect(EmojiParser.replaceEmoticons('hello :)'),
          equals('hello \u{1F642}'));
    });
  });

  group('EmojiParser.processLine', () {
    test('replaces emoticons in single-span line', () {
      final line = StyledLine([const StyledSpan(text: 'hello :) world')]);
      final result = EmojiParser.processLine(line);
      expect(result.plainText, equals('hello \u{1F642} world'));
    });

    test('preserves styling on replaced spans', () {
      final line = StyledLine([
        const StyledSpan(
          text: 'hello :)',
          foreground: Color(0xFFFF0000),
          bold: true,
        ),
      ]);
      final result = EmojiParser.processLine(line);
      expect(result.spans.length, equals(1));
      expect(result.spans[0].text, equals('hello \u{1F642}'));
      expect(result.spans[0].foreground, equals(const Color(0xFFFF0000)));
      expect(result.spans[0].bold, isTrue);
    });

    test('handles multi-span line', () {
      final line = StyledLine([
        const StyledSpan(text: 'hello '),
        const StyledSpan(
          text: ':) world',
          foreground: Color(0xFF00FF00),
        ),
      ]);
      final result = EmojiParser.processLine(line);
      expect(result.spans.length, equals(2));
      expect(result.spans[0].text, equals('hello '));
      expect(result.spans[1].text, equals('\u{1F642} world'));
      expect(result.spans[1].foreground, equals(const Color(0xFF00FF00)));
    });

    test('returns original line when no emoticons found', () {
      final line = StyledLine([const StyledSpan(text: 'no emoticons')]);
      final result = EmojiParser.processLine(line);
      expect(identical(result, line), isTrue);
    });

    test('only modified spans are replaced', () {
      final span1 = const StyledSpan(text: 'no change');
      final span2 = const StyledSpan(text: 'has :)');
      final line = StyledLine([span1, span2]);
      final result = EmojiParser.processLine(line);
      // First span should be the same instance.
      expect(identical(result.spans[0], span1), isTrue);
      // Second span is new since text changed.
      expect(result.spans[1].text, equals('has \u{1F642}'));
    });
  });

  group('EmojiParser coverage', () {
    test('every entry in emoticonMap is replaced correctly', () {
      for (final entry in EmojiParser.emoticonMap.entries) {
        final input = 'prefix ${entry.key} suffix';
        final expected = 'prefix ${entry.value} suffix';
        expect(
          EmojiParser.replaceEmoticons(input),
          equals(expected),
          reason: 'Failed for emoticon: ${entry.key}',
        );
      }
    });
  });

  group('EmojiParser.reverseEmojis', () {
    test('converts smiley emoji back to emoticon', () {
      expect(EmojiParser.reverseEmojis('hello \u{1F642} world'),
          equals('hello :) world'));
    });

    test('converts grin emoji back to emoticon', () {
      expect(EmojiParser.reverseEmojis('\u{1F600}'),
          equals(':D'));
    });

    test('converts wink emoji back to emoticon', () {
      expect(EmojiParser.reverseEmojis('\u{1F609}'),
          equals(';)'));
    });

    test('converts heart emoji back to emoticon', () {
      expect(EmojiParser.reverseEmojis('\u{2764}\u{FE0F}'),
          equals('<3'));
    });

    test('converts bare heart (without variation selector) back to emoticon',
        () {
      expect(EmojiParser.reverseEmojis('\u{2764}'),
          equals('<3'));
    });

    test('converts broken heart emoji back to emoticon', () {
      expect(EmojiParser.reverseEmojis('\u{1F494}'),
          equals('</3'));
    });

    test('converts thumbs up emoji back to emoticon', () {
      expect(EmojiParser.reverseEmojis('\u{1F44D}'),
          equals('(y)'));
      // 👎 no longer has a reverse mapping since (n) was removed.
      expect(EmojiParser.reverseEmojis('\u{1F44E}'),
          equals('\u{1F44E}'));
    });

    test('converts multiple emoji in one string', () {
      expect(
        EmojiParser.reverseEmojis('hey \u{1F642} how \u{1F600}'),
        equals('hey :) how :D'),
      );
    });

    test('returns original string when no emoji present', () {
      const text = 'no emoji here :)';
      final result = EmojiParser.reverseEmojis(text);
      expect(identical(result, text), isTrue);
    });

    test('returns original string for empty input', () {
      const text = '';
      final result = EmojiParser.reverseEmojis(text);
      expect(identical(result, text), isTrue);
    });

    test('handles mixed text and emoji', () {
      expect(
        EmojiParser.reverseEmojis('I feel \u{1F60A} today'),
        equals('I feel ^^ today'),
      );
    });

    test('picks shortest emoticon for each emoji', () {
      // 🙂 maps to both :) and :-) — should pick :)
      expect(EmojiParser.reverseEmojis('\u{1F642}'), equals(':)'));
      // 😛 maps to :P, :p, :-P, :-p — should pick :P or :p (length 2)
      final result = EmojiParser.reverseEmojis('\u{1F61B}');
      expect(result.length, equals(2));
    });

    test('roundtrip: emoticon → emoji → emoticon preserves meaning', () {
      // Forward then reverse should produce a valid emoticon for each emoji.
      const input = 'hello :) world :D <3';
      final forward = EmojiParser.replaceEmoticons(input);
      final roundtrip = EmojiParser.reverseEmojis(forward);
      // Re-forward should equal the forward result.
      expect(EmojiParser.replaceEmoticons(roundtrip), equals(forward));
    });
  });
}
