import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/framed_text_block.dart';
import 'package:ancient_anguish_client/providers/framed_text_block_provider.dart';

void main() {
  group('framedTextBlocksProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('put() assigns incrementing ids', () {
      final notifier = container.read(framedTextBlocksProvider.notifier);
      final id1 = notifier.put(const FramedTextBlock([]));
      final id2 = notifier.put(const FramedTextBlock([]));
      expect(id2 - id1, 1);
      expect(
        container.read(framedTextBlocksProvider),
        containsPair(id1, isNotNull),
      );
      expect(
        container.read(framedTextBlocksProvider),
        containsPair(id2, isNotNull),
      );
    });

    test('clear() empties the store and resets the id counter', () {
      final notifier = container.read(framedTextBlocksProvider.notifier);
      notifier.put(const FramedTextBlock([]));
      notifier.put(const FramedTextBlock([]));
      notifier.clear();
      expect(container.read(framedTextBlocksProvider), isEmpty);
      final id = notifier.put(const FramedTextBlock([]));
      expect(id, 0);
    });
  });

  group('sentinel round-trip', () {
    test(
      'tryParseFramedBlockId returns the id embedded by sentinelForFramedBlockId',
      () {
        for (final id in [0, 1, 42, 9999]) {
          expect(
            tryParseFramedBlockId(sentinelForFramedBlockId(id)),
            id,
          );
        }
      },
    );

    test('tryParseFramedBlockId returns null for non-sentinel text', () {
      expect(tryParseFramedBlockId(''), isNull);
      expect(tryParseFramedBlockId('| /\\ oo OO |'), isNull);
      expect(tryParseFramedBlockId('just a line'), isNull);
    });

    test('tryParseFramedBlockId returns null for malformed sentinels', () {
      expect(tryParseFramedBlockId('${kFramedBlockSentinelPrefix}abc'), isNull);
      expect(
        tryParseFramedBlockId(
          '${kFramedBlockSentinelPrefix}abc$kFramedBlockSentinelSuffix',
        ),
        isNull,
      );
    });

    test('map and framed sentinels do not collide', () {
      // Each prefix/suffix uses a distinct private-use code point so a
      // map sentinel isn't accidentally parsed as a framed one, or vice
      // versa. Verifying by cross-parsing.
      final framed = sentinelForFramedBlockId(7);
      expect(tryParseFramedBlockId(framed), 7);
      // A map-prefixed string isn't parsed by the framed parser.
      expect(tryParseFramedBlockId('\uF0E17\uF0E2'), isNull);
    });
  });
}
