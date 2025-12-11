import 'package:flutter_test/flutter_test.dart';
import 'package:fall_down_detection_mobile/models/ring_buffer.dart';

void main() {
  group('RingBuffer', () {
    test('should initialize with correct capacity', () {
      final buffer = RingBuffer<int>(5);
      expect(buffer.capacity, 5);
      expect(buffer.length, 0);
      expect(buffer.isEmpty, true);
      expect(buffer.isFull, false);
    });

    test('should add elements and maintain count', () {
      final buffer = RingBuffer<int>(3);

      buffer.push(1);
      expect(buffer.length, 1);
      expect(buffer.isEmpty, false);

      buffer.push(2);
      expect(buffer.length, 2);

      buffer.push(3);
      expect(buffer.length, 3);
      expect(buffer.isFull, true);
    });

    test('should overwrite oldest element when full', () {
      final buffer = RingBuffer<int>(3);

      buffer.push(1);
      buffer.push(2);
      buffer.push(3);
      expect(buffer.toList(), [1, 2, 3]);

      buffer.push(4); // Should overwrite 1
      expect(buffer.toList(), [2, 3, 4]);

      buffer.push(5); // Should overwrite 2
      expect(buffer.toList(), [3, 4, 5]);
    });

    test('should return elements in chronological order', () {
      final buffer = RingBuffer<String>(4);

      buffer.push('a');
      buffer.push('b');
      buffer.push('c');

      expect(buffer.toList(), ['a', 'b', 'c']);
    });

    test('should handle wrapping correctly', () {
      final buffer = RingBuffer<int>(3);

      // Fill buffer
      buffer.push(1);
      buffer.push(2);
      buffer.push(3);

      // Wrap around multiple times
      buffer.push(4);
      buffer.push(5);
      buffer.push(6);
      buffer.push(7);

      expect(buffer.toList(), [5, 6, 7]);
      expect(buffer.length, 3);
    });

    test('should clear buffer correctly', () {
      final buffer = RingBuffer<int>(3);

      buffer.push(1);
      buffer.push(2);
      buffer.push(3);
      buffer.push(4); // Trigger wrap

      buffer.clear();

      expect(buffer.length, 0);
      expect(buffer.isEmpty, true);
      expect(buffer.isFull, false);
      expect(buffer.toList(), []);
    });

    test('should support indexed access', () {
      final buffer = RingBuffer<int>(5);

      buffer.push(10);
      buffer.push(20);
      buffer.push(30);

      expect(buffer[0], 10); // Oldest
      expect(buffer[1], 20);
      expect(buffer[2], 30); // Newest
    });

    test('should support indexed access after wrapping', () {
      final buffer = RingBuffer<int>(3);

      buffer.push(1);
      buffer.push(2);
      buffer.push(3);
      buffer.push(4); // Overwrites 1, buffer now [2, 3, 4]

      expect(buffer[0], 2); // Oldest
      expect(buffer[1], 3);
      expect(buffer[2], 4); // Newest
    });

    test('should throw RangeError for invalid index', () {
      final buffer = RingBuffer<int>(5);
      buffer.push(1);
      buffer.push(2);

      expect(() => buffer[-1], throwsRangeError);
      expect(() => buffer[2], throwsRangeError);
      expect(() => buffer[10], throwsRangeError);
    });

    test('should create immutable snapshot', () {
      final buffer = RingBuffer<int>(3);

      buffer.push(1);
      buffer.push(2);

      final snapshot = buffer.snapshot();
      expect(snapshot, [1, 2]);

      // Continue adding to buffer
      buffer.push(3);
      buffer.push(4);

      // Snapshot should remain unchanged
      expect(snapshot, [1, 2]);

      // Buffer should have new values
      expect(buffer.toList(), [2, 3, 4]);
    });

    test('should handle empty buffer operations', () {
      final buffer = RingBuffer<int>(5);

      expect(buffer.toList(), []);
      expect(buffer.snapshot(), []);
      expect(buffer.isEmpty, true);
    });

    test('should handle single element capacity', () {
      final buffer = RingBuffer<int>(1);

      buffer.push(1);
      expect(buffer.toList(), [1]);
      expect(buffer.isFull, true);

      buffer.push(2);
      expect(buffer.toList(), [2]);
    });

    test('should handle large number of insertions', () {
      final buffer = RingBuffer<int>(100);

      // Add 1000 elements
      for (int i = 0; i < 1000; i++) {
        buffer.push(i);
      }

      expect(buffer.length, 100);
      expect(buffer.isFull, true);

      // Should contain last 100 elements (900-999)
      final list = buffer.toList();
      expect(list.length, 100);
      expect(list.first, 900);
      expect(list.last, 999);
    });

    test('should work with complex objects', () {
      final buffer = RingBuffer<Map<String, dynamic>>(3);

      buffer.push({'time': 1.0, 'value': 10});
      buffer.push({'time': 2.0, 'value': 20});
      buffer.push({'time': 3.0, 'value': 30});

      final list = buffer.toList();
      expect(list.length, 3);
      expect(list[0]['time'], 1.0);
      expect(list[2]['value'], 30);
    });

    test('should maintain correct state after multiple clear operations', () {
      final buffer = RingBuffer<int>(3);

      buffer.push(1);
      buffer.push(2);
      buffer.clear();

      buffer.push(3);
      buffer.push(4);
      expect(buffer.toList(), [3, 4]);

      buffer.clear();
      expect(buffer.isEmpty, true);

      buffer.push(5);
      expect(buffer.toList(), [5]);
    });

    test('should have correct toString representation', () {
      final buffer = RingBuffer<int>(5);
      expect(buffer.toString(), contains('RingBuffer<int>'));
      expect(buffer.toString(), contains('capacity: 5'));
      expect(buffer.toString(), contains('length: 0'));
    });
  });
}
