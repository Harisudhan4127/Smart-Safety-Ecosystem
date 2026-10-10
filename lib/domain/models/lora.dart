import 'dart:math' as math;

import 'geo.dart';

/// LoRa radio parameters, surfaced in the radio diagnostics panel.
///
/// These describe the link between the vehicle node and the gateway. LoRa is
/// only that link: it never contacts a hospital directly, which is why the
/// architecture routes through a gateway and a backend.
class LoraRadioParams {
  const LoraRadioParams({
    this.frequencyMhz = 868.0,
    this.spreadingFactor = 7,
    this.bandwidthKhz = 125,
    this.codingRate = 5,
    this.txPowerDbm = 14,
  });

  /// 868 MHz for EU/IN region 1, 915 MHz for the US.
  final double frequencyMhz;

  /// 7 is the usual compromise between airtime and link budget.
  final int spreadingFactor;

  /// 125 kHz is the standard narrowband channel.
  final int bandwidthKhz;

  /// Coding rate denominator 5..8; 5 is the highest throughput.
  final int codingRate;
  final int txPowerDbm;

  /// Approximate time-on-air in milliseconds for a payload of [payloadBytes],
  /// following the Semtech datasheet formula (low data rate optimisation is
  /// assumed for SF11/SF12). Used by the packet inspector to explain why a
  /// compact payload matters.
  double timeOnAirMs(int payloadBytes) {
    final sf = spreadingFactor.clamp(6, 12);
    final bw = bandwidthKhz.toDouble();
    final cr = codingRate.clamp(5, 8);
    final lowDataRateOptimisation = sf >= 11 ? 1 : 0;

    const preambleSymbols = 8;
    final numerator =
        8 * payloadBytes - 4 * sf + 28 + 16 * (cr - 4);
    final denominator = 4 * (sf - 2 * lowDataRateOptimisation);
    final payloadSymbols =
        8 + math.max(0, (numerator + denominator - 1) ~/ denominator);

    final timeSeconds = (preambleSymbols * math.pow(2, sf) / bw) +
        ((payloadSymbols * (sf + 4)) / bw);
    return timeSeconds * 1000.0;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'frequencyMhz': frequencyMhz,
        'spreadingFactor': spreadingFactor,
        'bandwidthKhz': bandwidthKhz,
        'codingRate': codingRate,
        'txPowerDbm': txPowerDbm,
      };

  static LoraRadioParams fromJson(Map<String, dynamic> json) =>
      LoraRadioParams(
        frequencyMhz:
            (json['frequencyMhz'] as num?)?.toDouble() ?? 868.0,
        spreadingFactor: (json['spreadingFactor'] as num?)?.toInt() ?? 7,
        bandwidthKhz: (json['bandwidthKhz'] as num?)?.toInt() ?? 125,
        codingRate: (json['codingRate'] as num?)?.toInt() ?? 5,
        txPowerDbm: (json['txPowerDbm'] as num?)?.toInt() ?? 14,
      );
}

/// The kind of event a packet carries.
enum LoraEventType {
  accident('ACCIDENT'),
  telemetry('TELEMETRY'),
  heartbeat('HEARTBEAT'),
  cancel('CANCEL');

  const LoraEventType(this.wireName);

  /// The compact code used on the wire, to keep payloads small.
  final String wireName;

  static LoraEventType fromWire(String value) =>
      LoraEventType.values.firstWhere(
        (t) => t.wireName == value,
        orElse: () => LoraEventType.telemetry,
      );
}

/// A compact accident alert packet as transmitted from the vehicle node.
///
/// The payload is kept small on purpose: LoRa airtime grows with payload size,
/// and this packet has to fit inside a short budget after an impact.
class LoraPacket {
  const LoraPacket({
    required this.sequence,
    required this.deviceId,
    required this.type,
    required this.timestamp,
    required this.accelerationG,
    required this.tiltDegrees,
    required this.batteryPercent,
    this.gpsValid = false,
    this.location,
    this.sequenceOfRetries = 0,
  });

  final int sequence;
  final String deviceId;
  final LoraEventType type;
  final DateTime timestamp;

  /// Peak acceleration magnitude observed during the event, in g.
  final double accelerationG;

  /// Peak tilt observed during the event, in degrees.
  final double tiltDegrees;

  final int batteryPercent;

  /// False when the receiver had no fix. The packet is still sent, flagged, and
  /// carries the last known position when one exists \u2014 per the documented
  /// "no GPS fix" alternate path.
  final bool gpsValid;

  /// Null when no position is known at all.
  final GeoFix? location;

  final int sequenceOfRetries;

  /// A simple additive checksum over the numeric fields. This is an integrity
  /// check for a noisy link, not a security control.
  int get checksum {
    var sum = sequence + type.wireName.length + (gpsValid ? 1 : 0);
    sum += (accelerationG * 10).round();
    sum += (tiltDegrees * 10).round();
    sum += batteryPercent;
    return sum & 0xFFFF;
  }

  int get payloadBytes => toHex().length ~/ 2;

  /// Compact hex encoding, grouped into byte pairs for readability.
  String toHex() {
    final buffer = StringBuffer()
      ..write(sequence.toRadixString(16).padLeft(4, '0'))
      ..write(deviceId)
      ..write(type.wireName.codeUnitAt(0).toRadixString(16).padLeft(2, '0'))
      ..write(timestamp.millisecondsSinceEpoch.toRadixString(16).padLeft(12, '0'))
      ..write((accelerationG * 100).round().toRadixString(16).padLeft(6, '0'))
      ..write((tiltDegrees * 100).round().toRadixString(16).padLeft(6, '0'))
      ..write(batteryPercent.toRadixString(16).padLeft(2, '0'))
      ..write(gpsValid ? '1' : '0')
      ..write(gpsValid
          ? ((location?.latitude ?? 0) * 1e6).round().toRadixString(16).padLeft(16, '0')
          : '0'.padLeft(16, '0'))
      ..write(gpsValid
          ? ((location?.longitude ?? 0) * 1e6).round().toRadixString(16).padLeft(16, '0')
          : '0'.padLeft(16, '0'))
      ..write(checksum.toRadixString(16).padLeft(4, '0'));
    return buffer.toString().toUpperCase();
  }

  /// Human-readable field breakdown for the advanced packet inspector.
  Map<String, String> get inspectedFields => <String, String>{
        'Sequence': '#$sequence',
        'Device': deviceId,
        'Type': type.wireName,
        'Timestamp (UTC)': timestamp.toUtc().toIso8601String(),
        'Accel peak': '${accelerationG.toStringAsFixed(2)} g',
        'Tilt peak': '${tiltDegrees.toStringAsFixed(1)}\u00B0',
        'Battery': '$batteryPercent%',
        'GPS valid': gpsValid ? 'Yes' : 'No',
        if (gpsValid && location != null)
          'Latitude': location!.latitudeText,
        if (gpsValid && location != null)
          'Longitude': location!.longitudeText,
        'Retry': '#$sequenceOfRetries',
        'Checksum': '0x${checksum.toRadixString(16).toUpperCase().padLeft(4, '0')}',
      };

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sequence': sequence,
        'deviceId': deviceId,
        'type': type.wireName,
        'timestamp': timestamp.toIso8601String(),
        'accelerationG': accelerationG,
        'tiltDegrees': tiltDegrees,
        'batteryPercent': batteryPercent,
        'gpsValid': gpsValid,
        if (location != null) 'location': location!.toJson(),
        'sequenceOfRetries': sequenceOfRetries,
        'hex': toHex(),
      };

  static LoraPacket fromJson(Map<String, dynamic> json) => LoraPacket(
        sequence: (json['sequence'] as num).toInt(),
        deviceId: json['deviceId'] as String,
        type: LoraEventType.fromWire(json['type'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
        accelerationG: (json['accelerationG'] as num).toDouble(),
        tiltDegrees: (json['tiltDegrees'] as num).toDouble(),
        batteryPercent: (json['batteryPercent'] as num).toInt(),
        gpsValid: json['gpsValid'] as bool? ?? false,
        location: json['location'] == null
            ? null
            : GeoFix.fromJson(json['location'] as Map<String, dynamic>),
        sequenceOfRetries: (json['sequenceOfRetries'] as num?)?.toInt() ?? 0,
      );

  @override
  String toString() => 'LoraPacket($deviceId #$sequence ${type.wireName})';
}

/// The outcome of one transmission attempt.
///
/// Attempts and confirmed acknowledgements are deliberately different types.
/// The monitoring UI must never present "we sent it" as "it was delivered".
enum TransmissionOutcome {
  /// Packet was sent and the gateway acknowledged receipt.
  acknowledged,

  /// Packet left the node but no acknowledgement arrived before the timeout.
  sentUnacknowledged,

  /// The node has no gateway in range; it will retry.
  noGatewayInRange,

  /// The radio reported a transmit failure.
  radioFailure,

  /// The GSM fallback path was used instead of LoRa.
  fallbackGsm;

  bool get isDelivered => this == TransmissionOutcome.acknowledged;
}