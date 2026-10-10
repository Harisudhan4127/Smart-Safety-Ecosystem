import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/app_theme.dart';
import '../../core/design/tokens.dart';

/// A bounded ring of chart points.
///
/// Telemetry arrives far faster than the screen can usefully repaint, so the
/// buffer is capped: memory stays constant no matter how long a session runs.
class SeriesBuffer {
  SeriesBuffer({this.capacity = 240});

  final int capacity;
  final List<({double t, double v})> _points = <({double t, double v})>[];

  int get length => _points.length;
  bool get isEmpty => _points.isEmpty;

  void add(double value, {required DateTime at}) {
    _points.add((t: at.millisecondsSinceEpoch.toDouble(), v: value));
    while (_points.length > capacity) {
      _points.removeAt(0);
    }
  }

  ({double t, double v})? get latest => _points.isEmpty ? null : _points.last;

  List<({double t, double v})> get points => _points;

  void clear() => _points.clear();
}

/// Interactive line chart for telemetry.
///
/// Hand-painted with a [CustomPainter] rather than pulled from a charting
/// package: it keeps the dependency surface small, gives exact control over the
/// two theme palettes, and avoids a full-screen widget subtree per data point.
///
/// Interaction is read-only (crosshair + value readout) because this is a
/// monitoring view; it never offers controls that appear to change data.
class TelemetryChart extends StatefulWidget {
  const TelemetryChart({
    super.key,
    required this.buffer,
    required this.color,
    required this.unit,
    this.label,
    this.min,
    this.max,
    this.threshold,
    this.height = 180,
    this.fill = true,
  });

  final SeriesBuffer buffer;
  final Color color;
  final String unit;
  final String? label;

  /// Forces the vertical scale; otherwise it is derived from the data.
  final double? min;
  final double? max;

  /// Optional reference line, e.g. a calibrated threshold.
  final double? threshold;

  final double height;

  /// Whether to paint a soft area fill beneath the line.
  final bool fill;

  @override
  State<TelemetryChart> createState() => _TelemetryChartState();
}

class _TelemetryChartState extends State<TelemetryChart> {
  int? _hoverIndex;

  void _updateHover(Offset localPosition, double width) {
    final points = widget.buffer.points;
    if (points.isEmpty || width <= 0) return;

    final minT = points.first.t;
    final maxT = points.last.t;
    if (maxT <= minT) return;

    final fraction = (localPosition.dx / width).clamp(0.0, 1.0);
    final target = minT + (maxT - minT) * fraction;
    final index = (target - minT) / (maxT - minT) * (points.length - 1);
    final rounded = index.round().clamp(0, points.length - 1);

    if (rounded != _hoverIndex) {
      setState(() => _hoverIndex = rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);

    return Semantics(
      label: '${widget.label ?? 'Telemetry'} chart'
          '${_hoverIndex == null ? '' : ', value ${widget.buffer.points[_hoverIndex!].v.toStringAsFixed(1)} ${widget.unit}'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.label != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Flexible(
                  child: Text(
                    widget.label!,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const Spacer(),
              if (_hoverIndex != null &&
                  _hoverIndex! < widget.buffer.length)
                Builder(
                  builder: (context) {
                    final point = widget.buffer.points[_hoverIndex!];
                    return Text(
                      '${point.v.toStringAsFixed(2)} ${widget.unit}',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: widget.color),
                    );
                  },
                )
              else
                Text(widget.unit, style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: Insets.sm),
          SizedBox(
            height: widget.height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return MouseRegion(
                  onHover: (e) =>
                      _updateHover(e.localPosition, constraints.maxWidth),
                  onExit: (_) => setState(() => _hoverIndex = null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (e) => _updateHover(
                      e.localPosition,
                      constraints.maxWidth,
                    ),
                    onHorizontalDragEnd: (_) =>
                        setState(() => _hoverIndex = null),
                    onTapDown: (e) =>
                        _updateHover(e.localPosition, constraints.maxWidth),
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _ChartPainter(
                        points: widget.buffer.points,
                        color: widget.color,
                        gridColor: colors.chartGrid,
                        labelColor: colors.textTertiary,
                        fillColor: widget.color,
                        threshold: widget.threshold,
                        thresholdColor: colors.warning,
                        hoverIndex: _hoverIndex,
                        forcedMin: widget.min,
                        forcedMax: widget.max,
                        fillArea: widget.fill,
                        textDirection: Directionality.of(context),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.points,
    required this.color,
    required this.gridColor,
    required this.labelColor,
    required this.fillColor,
    required this.threshold,
    required this.thresholdColor,
    required this.hoverIndex,
    required this.forcedMin,
    required this.forcedMax,
    required this.fillArea,
    required this.textDirection,
  });

  final List<({double t, double v})> points;
  final Color color;
  final Color gridColor;
  final Color labelColor;
  final Color fillColor;
  final double? threshold;
  final Color thresholdColor;
  final int? hoverIndex;
  final double? forcedMin;
  final double? forcedMax;
  final bool fillArea;
  final TextDirection textDirection;

  static const int _gridLines = 4;
  static const double _leftGutter = 46;

  @override
  void paint(Canvas canvas, Size size) {
    const plotLeft = _leftGutter;
    final plotWidth = size.width - _leftGutter;
    final plotHeight = size.height - 20;

    if (plotWidth <= 0 || plotHeight <= 0) return;

    if (points.isEmpty) {
      _paintAxisLabels(canvas, size, plotLeft, plotWidth, plotHeight, 0, 1);
      return;
    }

    // Derive the vertical scale from the data, honouring explicit bounds.
    var lo = points.first.v;
    var hi = points.first.v;
    for (final p in points) {
      lo = math.min(lo, p.v);
      hi = math.max(hi, p.v);
    }
    final threshold = this.threshold;
    if (threshold != null) {
      lo = math.min(lo, threshold);
      hi = math.max(hi, threshold);
    }
    lo = math.min(lo, forcedMin ?? lo);
    hi = math.max(hi, forcedMax ?? hi);

    // A flat line still needs a visible band.
    if ((hi - lo).abs() < 1e-9) {
      final pad = math.max(1.0, hi.abs() * 0.1);
      lo -= pad;
      hi += pad;
    }
    final span = hi - lo;

    final minT = points.first.t;
    final maxT = points.last.t;
    final tSpan = (maxT - minT).abs() < 1e-9 ? 1.0 : maxT - minT;

    Offset toOffset(double t, double v) => Offset(
          plotLeft + (t - minT) / tSpan * plotWidth,
          plotHeight - (v - lo) / span * plotHeight,
        );

    _paintGrid(canvas, size, plotLeft, plotWidth, plotHeight, lo, hi);

    if (threshold != null) {
      final y = plotHeight - (threshold - lo) / span * plotHeight;
      canvas.drawLine(
        Offset(plotLeft, y),
        Offset(plotLeft + plotWidth, y),
        Paint()
          ..color = thresholdColor.withValues(alpha: 0.55)
          ..strokeWidth = 1,
      );
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final offset = toOffset(p.t, p.v);
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }

    if (fillArea) {
      final fillPath = Path.from(path)
        ..lineTo(plotLeft + plotWidth, plotHeight)
        ..lineTo(plotLeft, plotHeight)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              fillColor.withValues(alpha: 0.22),
              fillColor.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, plotHeight)),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final hover = hoverIndex;
    if (hover != null && hover < points.length) {
      final offset = toOffset(points[hover].t, points[hover].v);
      canvas.drawLine(
        Offset(offset.dx, 0),
        Offset(offset.dx, plotHeight),
        Paint()
          ..color = labelColor.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(offset, 5, Paint()..color = color);
      canvas.drawCircle(
        offset,
        5,
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      );
    }

    _paintAxisLabels(canvas, size, plotLeft, plotWidth, plotHeight, lo, hi);
  }

  void _paintGrid(
    Canvas canvas,
    Size size,
    double left,
    double width,
    double height,
    double lo,
    double hi,
  ) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= _gridLines; i++) {
      final y = height - height / _gridLines * i;
      canvas.drawLine(Offset(left, y), Offset(left + width, y), paint);
    }
  }

  void _paintAxisLabels(
    Canvas canvas,
    Size size,
    double left,
    double width,
    double height,
    double lo,
    double hi,
  ) {
    for (var i = 0; i <= _gridLines; i++) {
      final value = hi - (hi - lo) / _gridLines * i;
      final y = height - height / _gridLines * i;
      final painter = TextPainter(
        text: TextSpan(
          text: value.abs() >= 100
              ? value.toStringAsFixed(0)
              : value.toStringAsFixed(1),
          style: TextStyle(fontSize: 10, color: labelColor),
        ),
        textDirection: textDirection,
      )..layout(maxWidth: _leftGutter - 6);
      painter.paint(canvas, Offset(left - painter.width - 6, y - 6));
    }
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) =>
      oldDelegate.points.length != points.length ||
      oldDelegate.hoverIndex != hoverIndex ||
      oldDelegate.color != color ||
      (points.isNotEmpty &&
          oldDelegate.points.isNotEmpty &&
          oldDelegate.points.last.v != points.last.v);
}