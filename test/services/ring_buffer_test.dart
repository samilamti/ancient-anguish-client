import 'package:flutter_test/flutter_test.dart';

import 'package:ancient_anguish_client/core/utils/ring_buffer.dart';

void main() {
  group('RingBuffer', () {
    test('starts empty', () {
      final buffer = RingBuffer<int>(5);
      expect(buffer.isEmpty, true);
      expect(buffer.length, 0);
      expect(buffer.isFull, false);
    });

    test('add increments length', () {
      final buffer = RingBuffer<int>(5);
      buffer.add(1);
      buffer.add(2);
      expect(buffer.length, 2);
    });

    test('indexed access returns items in insertion order', () {
      final buffer = RingBuffer<int>(5);
      buffer.add(10);
      buffer.add(20);
      buffer.add(30);
      expect(buffer[0], 10);
      expect(buffer[1], 20);
      expect(buffer[2], 30);
    });

    test('isFull returns true when capacity reached', () {
      final buffer = RingBuffer<int>(3);
      buffer.add(1);
      buffer.add(2);
      buffer.add(3);
      expect(buffer.isFull, true);
      expect(buffer.length, 3);
    });

    test('overwrites oldest item when full', () {
      final buffer = RingBuffer<int>(3);
      buffer.add(1);
      buffer.add(2);
      buffer.add(3);
      buffer.add(4); // overwrites 1

      expect(buffer.length, 3);
      expect(buffer[0], 2); // oldest is now 2
      expect(buffer[1], 3);
      expect(buffer[2], 4); // newest
    });

    test('handles many overwrites correctly', () {
      final buffer = RingBuffer<int>(3);
      for (var i = 0; i < 100; i++) {
        buffer.add(i);
      }
      expect(buffer.length, 3);
      expect(buffer[0], 97);
      expect(buffer[1], 98);
      expect(buffer[2], 99);
    });

    test('toList returns items oldest to newest', () {
      final buffer = RingBuffer<int>(3);
      buffer.add(1);
      buffer.add(2);
      buffer.add(3);
      buffer.add(4);
      expect(buffer.toList(), [2, 3, 4]);
    });

    test('clear resets buffer', () {
      final buffer = RingBuffer<int>(3);
      buffer.add(1);
      buffer.add(2);
      buffer.clear();
      expect(buffer.isEmpty, true);
      expect(buffer.length, 0);
    });

    test('addAll adds multiple items', () {
      final buffer = RingBuffer<int>(5);
      buffer.addAll([1, 2, 3]);
      expect(buffer.length, 3);
      expect(buffer.toList(), [1, 2, 3]);
    });

    test('throws RangeError on invalid index', () {
      final buffer = RingBuffer<int>(3);
      buffer.add(1);
      expect(() => buffer[-1], throwsRangeError);
      expect(() => buffer[1], throwsRangeError);
    });

    test('capacity of 1 works correctly', () {
      final buffer = RingBuffer<int>(1);
      buffer.add(42);
      expect(buffer[0], 42);
      buffer.add(99);
      expect(buffer[0], 99);
      expect(buffer.length, 1);
    });
  });
}
