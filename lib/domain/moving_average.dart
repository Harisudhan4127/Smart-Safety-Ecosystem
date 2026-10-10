import 'dart:collection';

/// Fixed-window moving-average filter, the smoothing stage that sits between
/// the wearable sensors and AWTRA.
///
/// Implemented as a bounded ring buffer so that memory use is constant no
/// matter how long the device runs. [window] samples are the most recent ones
/// added.
class MovingAverage {
  MovingAverage(this.window) : assert(window > 0, 'window must be positive');

  final int window;
  final Queue<double> _samples = Queue<double>();

  /// True once the window has filled, i.e. when [average] is over a full set of
  /// samples rather than a partial one.
  bool get isPrimed => _samples.length >= window;

  int get sampleCount => _samples.length;

  void add(double value) {
    if (!value.isFinite) return; // Reject NaN/infinity from a faulty sensor.
    _samples.addLast(value);
    while (_samples.length > window) {
      _samples.removeFirst();
    }
  }

  /// Arithmetic mean of the buffered samples, or 0 while the buffer is empty.
  double get average {
    if (_samples.isEmpty) return 0;
    var sum = 0.0;
    for (final s in _samples) {
      sum += s;
    }
    return sum / _samples.length;
  }

  /// Most recent sample without disturbing the buffer.
  double get latest => _samples.isEmpty ? 0 : _samples.last;

  void clear() => _samples.clear();
}