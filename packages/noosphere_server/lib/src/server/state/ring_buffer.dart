/// Takes a certain number of [T] objects, retaining the last added objects
class RingBuffer<T> {
  final List<T> buffer = [];
  final int maxSize;
  int next = 0;

  RingBuffer(this.maxSize) {
    RangeError.checkNotNegative(maxSize, "maxSize");
  }

  T? add(T element) {
    T? discarded;
    if (buffer.length < maxSize) {
      buffer.add(element);
    } else {
      discarded = buffer[next];
      buffer[next] = element;
    }
    next = (next + 1) % maxSize;
    return discarded;
  }

  List<T> flushBuffer() {
    final ordered = [...buffer.sublist(next), ...buffer.sublist(0, next)];
    buffer.clear();
    next = 0;
    return ordered;
  }
}
