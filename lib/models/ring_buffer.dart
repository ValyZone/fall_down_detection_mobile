/// A memory-efficient circular buffer (ring buffer) implementation.
///
/// This class provides a fixed-size FIFO (First-In-First-Out) buffer that
/// automatically overwrites the oldest data when capacity is reached.
/// Designed for continuous sensor data collection without memory leaks.
class RingBuffer<T> {
  /// Maximum number of elements the buffer can hold
  final int capacity;

  /// Internal storage list
  late final List<T?> _buffer;

  /// Current write position in the buffer
  int _writeIndex = 0;

  /// Number of elements currently in the buffer
  int _count = 0;

  /// Whether the buffer has wrapped around (written past capacity once)
  bool _hasWrapped = false;

  /// Creates a ring buffer with the specified capacity
  RingBuffer(this.capacity) : assert(capacity > 0, 'Capacity must be positive') {
    _buffer = List<T?>.filled(capacity, null);
  }

  /// Adds an element to the buffer.
  /// If the buffer is full, the oldest element is overwritten.
  void push(T item) {
    _buffer[_writeIndex] = item;
    _writeIndex = (_writeIndex + 1) % capacity;

    if (_count < capacity) {
      _count++;
    } else {
      _hasWrapped = true;
    }
  }

  /// Returns all elements in the buffer in chronological order (oldest first).
  /// Only returns the valid elements that have been added.
  List<T> toList() {
    if (_count == 0) return [];

    final List<T> result = [];

    if (_count == capacity) {
      // Buffer is full - read from write position (oldest) to end, then wrap
      for (int i = _writeIndex; i < capacity; i++) {
        result.add(_buffer[i] as T);
      }
      // Then read from start to write position
      for (int i = 0; i < _writeIndex; i++) {
        result.add(_buffer[i] as T);
      }
    } else {
      // Buffer not full yet - read from 0 to writeIndex
      for (int i = 0; i < _count; i++) {
        result.add(_buffer[i] as T);
      }
    }

    return result;
  }

  /// Clears all elements from the buffer and resets state
  void clear() {
    _buffer.fillRange(0, capacity, null);
    _writeIndex = 0;
    _count = 0;
    _hasWrapped = false;
  }

  /// Returns the number of elements currently in the buffer
  int get length => _count;

  /// Returns true if the buffer is at full capacity
  bool get isFull => _count == capacity;

  /// Returns true if the buffer is empty
  bool get isEmpty => _count == 0;

  /// Returns the current capacity of the buffer
  int get size => capacity;

  /// Gets the element at the specified index in chronological order.
  /// Index 0 is the oldest element, index [length-1] is the newest.
  /// Throws [RangeError] if index is out of bounds.
  T operator [](int index) {
    if (index < 0 || index >= _count) {
      throw RangeError('Index $index out of range [0, ${_count - 1}]');
    }

    final int actualIndex = _count == capacity
        ? (_writeIndex + index) % capacity
        : index;

    return _buffer[actualIndex] as T;
  }

  /// Freezes the buffer and returns a snapshot as an immutable list.
  /// This is useful when you need to preserve the current state
  /// while continuing to add new data.
  List<T> snapshot() {
    return List<T>.unmodifiable(toList());
  }

  @override
  String toString() {
    return 'RingBuffer<$T>(capacity: $capacity, length: $length, isFull: $isFull)';
  }
}
