import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/models/map_block.dart';
import 'package:ancient_anguish_client/providers/map_block_provider.dart';

void main() {
  group('mapBlocksProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('put() assigns incrementing ids', () {
      final notifier = container.read(mapBlocksProvider.notifier);
      final id1 = notifier.put(const MapBlock([]));
      final id2 = notifier.put(const MapBlock([]));
      expect(id2 - id1, 1);
      expect(container.read(mapBlocksProvider), containsPair(id1, isNotNull));
      expect(container.read(mapBlocksProvider), containsPair(id2, isNotNull));
    });

    test('clear() empties the store and resets the id counter', () {
      final notifier = container.read(mapBlocksProvider.notifier);
      notifier.put(const MapBlock([]));
      notifier.put(const MapBlock([]));
      notifier.clear();
      expect(container.read(mapBlocksProvider), isEmpty);
      final id = notifier.put(const MapBlock([]));
      expect(id, 0);
    });
  });

  group('sentinel round-trip', () {
    test('tryParseBlockId returns the id embedded by sentinelForBlockId', () {
      for (final id in [0, 1, 42, 9999]) {
        expect(tryParseBlockId(sentinelForBlockId(id)), id);
      }
    });

    test('tryParseBlockId returns null for non-sentinel text', () {
      expect(tryParseBlockId(''), isNull);
      expect(tryParseBlockId('| /\\ oo OO |'), isNull);
      expect(tryParseBlockId('just a line'), isNull);
    });

    test('tryParseBlockId returns null for malformed sentinels', () {
      // Prefix but no suffix.
      expect(tryParseBlockId('${kMapBlockSentinelPrefix}abc'), isNull);
      // Non-numeric id.
      expect(
        tryParseBlockId(
            '${kMapBlockSentinelPrefix}abc$kMapBlockSentinelSuffix'),
        isNull,
      );
    });
  });
}
