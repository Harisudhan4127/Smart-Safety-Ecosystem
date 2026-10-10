import '../ui/components/telemetry_chart.dart';

/// A named, bounded telemetry stream.
class TelemetrySeries {
  TelemetrySeries(this.label, this.unit, {int capacity = 240})
      : buffer = SeriesBuffer(capacity: capacity);

  final String label;
  final String unit;
  final SeriesBuffer buffer;

  void add(double value, {required DateTime at}) => buffer.add(value, at: at);

  void clear() => buffer.clear();

  double? get latest => buffer.latest?.v;
}