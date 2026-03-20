import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/services/social/social_message_parser.dart';

void main() {
  group('SocialMessageParser', () {
    group('matchChatLine', () {
      test('matches standard chat say', () {
        final result = SocialMessageParser.matchChatLine(
          '[Chat] Chosen: totes! Did you find a pupper yet?',
        );
        expect(result, isNotNull);
        expect(result!.sender, 'Chosen');
        expect(result.text, 'totes! Did you find a pupper yet?');
        expect(result.isEmote, isFalse);
      });

      test('matches chat say with short message', () {
        final result = SocialMessageParser.matchChatLine(
          '[Chat] Roric: mis',
        );
        expect(result, isNotNull);
        expect(result!.sender, 'Roric');
        expect(result.text, 'mis');
        expect(result.isEmote, isFalse);
      });

      test('matches chat emote', () {
        final result = SocialMessageParser.matchChatLine(
          '[Chat] Chosen nods solemnly.',
        );
        expect(result, isNotNull);
        expect(result!.sender, 'Chosen');
        expect(result.text, 'nods solemnly.');
        expect(result.isEmote, isTrue);
      });

      test('matches chat emote with complex action', () {
        final result = SocialMessageParser.matchChatLine(
          '[Chat] Creeper grins mischievously.',
        );
        expect(result, isNotNull);
        expect(result!.sender, 'Creeper');
        expect(result.text, 'grins mischievously.');
        expect(result.isEmote, isTrue);
      });

      test('matches chat say with long message', () {
        final result = SocialMessageParser.matchChatLine(
          "[Chat] Roric: I say that to the invasive tree out side my house that I've",
        );
        expect(result, isNotNull);
        expect(result!.sender, 'Roric');
        expect(result.isEmote, isFalse);
      });

      test('returns null for non-chat lines', () {
        expect(SocialMessageParser.matchChatLine('Hello world'), isNull);
        expect(SocialMessageParser.matchChatLine('You see a sword.'), isNull);
        expect(
            SocialMessageParser.matchChatLine('Tuinn tells you: hi'), isNull);
      });

      test('returns null for empty string', () {
        expect(SocialMessageParser.matchChatLine(''), isNull);
      });
    });

    group('matchTellLine', () {
      test('matches incoming tell', () {
        final result = SocialMessageParser.matchTellLine(
          'Tuinn tells you: so nothing happens when I click the exe',
        );
        expect(result, isNotNull);
        expect(result!.sender, 'Tuinn');
        expect(result.text, 'so nothing happens when I click the exe');
        expect(result.isOutgoing, isFalse);
      });

      test('matches incoming tell with short message', () {
        final result = SocialMessageParser.matchTellLine(
          'Tuinn tells you: BOOM, I got it',
        );
        expect(result, isNotNull);
        expect(result!.sender, 'Tuinn');
        expect(result.text, 'BOOM, I got it');
        expect(result.isOutgoing, isFalse);
      });

      test('matches outgoing tell', () {
        final result = SocialMessageParser.matchTellLine(
          'You tell Tuinn: try running it as administrator',
        );
        expect(result, isNotNull);
        expect(result!.sender, 'Tuinn');
        expect(result.text, 'try running it as administrator');
        expect(result.isOutgoing, isTrue);
      });

      test('returns null for non-tell lines', () {
        expect(SocialMessageParser.matchTellLine('Hello world'), isNull);
        expect(SocialMessageParser.matchTellLine('[Chat] Chosen: hi'), isNull);
        expect(SocialMessageParser.matchTellLine('You see a sword.'), isNull);
      });

      test('returns null for empty string', () {
        expect(SocialMessageParser.matchTellLine(''), isNull);
      });

      test('matches tell with special characters in text', () {
        final result = SocialMessageParser.matchTellLine(
          "Tuinn tells you: I guess the new windows has an \"S\" mode?",
        );
        expect(result, isNotNull);
        expect(result!.sender, 'Tuinn');
        expect(result.isOutgoing, isFalse);
      });
    });

    group('matchPartyLine', () {
      test('matches standard party message', () {
        final result = SocialMessageParser.matchPartyLine(
          '<womp womp> [Godsend] : I like ice cream',
        );
        expect(result, isNotNull);
        expect(result!.partyName, 'womp womp');
        expect(result.sender, 'Godsend');
        expect(result.text, 'I like ice cream');
      });

      test('matches party with single-word name', () {
        final result = SocialMessageParser.matchPartyLine(
          '<Raiders> [Chosen] : lets go',
        );
        expect(result, isNotNull);
        expect(result!.partyName, 'Raiders');
        expect(result.sender, 'Chosen');
        expect(result.text, 'lets go');
      });

      test('matches party with long message', () {
        final result = SocialMessageParser.matchPartyLine(
          '<The Fellowship> [Gandalf] : You shall not pass! This is a very long message.',
        );
        expect(result, isNotNull);
        expect(result!.partyName, 'The Fellowship');
        expect(result.sender, 'Gandalf');
        expect(result.text, 'You shall not pass! This is a very long message.');
      });

      test('returns null for non-party lines', () {
        expect(SocialMessageParser.matchPartyLine('Hello world'), isNull);
        expect(SocialMessageParser.matchPartyLine('[Chat] Chosen: hi'), isNull);
        expect(SocialMessageParser.matchPartyLine('Tuinn tells you: hi'), isNull);
      });

      test('returns null for empty string', () {
        expect(SocialMessageParser.matchPartyLine(''), isNull);
      });

      test('returns null for malformed party line (missing brackets)', () {
        expect(SocialMessageParser.matchPartyLine('<womp> Godsend : hi'), isNull);
      });

      test('returns null for missing colon separator', () {
        expect(SocialMessageParser.matchPartyLine('<womp> [Godsend] hi'), isNull);
      });
    });

    group('isContinuation', () {
      test('detects chat continuation (7 spaces)', () {
        expect(
          SocialMessageParser.isContinuation(
              '       battling for a few years.'),
          isTrue,
        );
      });

      test('detects tell continuation (many spaces)', () {
        expect(
          SocialMessageParser.isContinuation(
              '                 you can make easy sure.'),
          isTrue,
        );
      });

      test('rejects normal text', () {
        expect(SocialMessageParser.isContinuation('Normal text'), isFalse);
      });

      test('rejects single space', () {
        expect(SocialMessageParser.isContinuation(' Single space'), isFalse);
      });

      test('rejects 6 spaces (below threshold)', () {
        expect(
            SocialMessageParser.isContinuation('      six spaces'), isFalse);
      });

      test('accepts exactly 7 spaces', () {
        expect(
          SocialMessageParser.isContinuation('       seven spaces text'),
          isTrue,
        );
      });

      test('rejects empty string', () {
        expect(SocialMessageParser.isContinuation(''), isFalse);
      });

      test('rejects spaces only', () {
        expect(SocialMessageParser.isContinuation('          '), isFalse);
      });
    });
  });
}
