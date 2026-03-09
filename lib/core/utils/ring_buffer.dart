/// A fixed-capacity ring buffer that efficiently stores the last [capacity]
/// items, discarding the oldest when full.
///
/// Used for the terminal scrollback buffer to cap memory usage while
/// maintaining O(1) append and O(1) indexed access.
class RingBuffer<T> {
  final int capacity;
  final List<T?> _buffer;
  int _head = 0; // next write position
  int _size = 0;

  RingBuffer(this.capacity) : _buffer = List<T?>.filled(capacity, null);

  /// The number of items currently stored.
  int get length => _size;

  /// Whether the buffer is empty.
  bool get isEmpty => _size == 0;

  /// Whether the buffer has reached capacity.
  bool get isFull => _size == capacity;

  /// Adds an item to the buffer. If full, the oldest item is overwritten.
  void add(T item) {
    _buffer[_head] = item;
    _head = (_head + 1) % capacity;
    if (_size < capacity) _size++;
  }

  /// Adds all items from [items] to the buffer.
  void addAll(Iterable<T> items) {
    for (final item in items) {
      add(item);
    }
  }

  /// Returns the item at logical index [i] (0 = oldest, length-1 = newest).
  T operator [](int i) {
    if (i < 0 || i >= _size) {
      throw RangeError.index(i, this, 'index', null, _size);
    }
    final actualIndex = (_head - _size + i) % capacity;
    return _buffer[actualIndex < 0 ? actualIndex + capacity : actualIndex]!;
  }

  /// Returns all items as a list, oldest first.
  List<T> toList() {
    final result = <T>[];
    for (var i = 0; i < _size; i++) {
      result.add(this[i]);
    }
    return result;
  }

  /// Clears all items from the buffer.
  void clear() {
    _head = 0;
    _size = 0;
    _buffer.fillRange(0, capacity, null);
  }
}
