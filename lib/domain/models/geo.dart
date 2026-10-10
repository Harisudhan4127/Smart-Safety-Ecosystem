import 'dart:math' as math;

/// A WGS-84 geographic position.
class GeoFix {
  const GeoFix({
    required this.latitude,
    required this.longitude,
    required this.fixedAt,
    this.satellites = 0,
    this.accuracyMetres = 0,
  });

  final double latitude;
  final double longitude;
  final DateTime fixedAt;

  /// Number of satellites used in the solution, when the receiver reports it.
  final int satellites;

  /// Horizontal accuracy estimate in metres, when the receiver reports it.
  final double accuracyMetres;

  bool get isValid => !latitude.isNaN && !longitude.isNaN;

  String get latitudeText => latitude.toStringAsFixed(6);
  String get longitudeText => longitude.toStringAsFixed(6);

  /// Human-readable summary used in the overview and incident list.
  String get display => '$latitudeText, $longitudeText';

  /// Great-circle distance to [other] in metres.
  double distanceTo(GeoFix other) {
    const earthRadius = 6371000.0;
    final dLat = _rad(other.latitude - latitude);
    final dLon = _rad(other.longitude - longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(latitude)) *
            math.cos(_rad(other.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180.0;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        'fixedAt': fixedAt.toIso8601String(),
        'satellites': satellites,
        'accuracyMetres': accuracyMetres,
      };

  static GeoFix fromJson(Map<String, dynamic> json) => GeoFix(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        fixedAt:
            DateTime.tryParse(json['fixedAt'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
        satellites: (json['satellites'] as num?)?.toInt() ?? 0,
        accuracyMetres: (json['accuracyMetres'] as num?)?.toDouble() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      other is GeoFix &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.fixedAt == fixedAt;

  @override
  int get hashCode => Object.hash(latitude, longitude, fixedAt);

  @override
  String toString() => 'GeoFix($display @ ${fixedAt.toIso8601String()})';
}

/// Formats a position as DMS degrees, which is what responders expect on a
/// printed incident record.
String formatGeoDms(GeoFix fix) {
  String part(double value, String pos, String neg) {
    final hemisphere = value >= 0 ? pos : neg;
    final abs = value.abs();
    final deg = abs.floor();
    final minutesFull = (abs - deg) * 60;
    final min = minutesFull.floor();
    final sec = (minutesFull - min) * 60;
    return '$deg\u00B0$min\'${sec.toStringAsFixed(2)}"$hemisphere';
  }

  return '${part(fix.latitude, 'N', 'S')} ${part(fix.longitude, 'E', 'W')}';
}