import 'geo.dart';
import 'lora.dart';
import 'severity.dart';

/// The two event categories the platform keeps strictly separate.
///
/// Accident events and wearable screening records describe different things.
/// The product documentation is explicit that a screening reading must never be
/// presented as evidence that someone caused an accident, so the type is
/// carried on every record and never merged.
enum IncidentCategory {
  accident('Accident alert', 'Vehicle impact or rollover'),
  screening('Wearable screening', 'Preliminary screening record');

  const IncidentCategory(this.label, this.description);

  final String label;
  final String description;
}

/// Where a record is in its review lifecycle.
enum IncidentStatus {
  active('Active', Severity.critical),
  acknowledged('Acknowledged', Severity.caution),
  resolved('Resolved', Severity.safe),
  discarded('Discarded', Severity.info);

  const IncidentStatus(this.label, this.tone);

  final String label;

  /// Visual tone. The status label is always shown as text as well, so tone is
  /// never the only signal.
  final Severity tone;
}

/// Where a record came from. Demo Mode records are permanently distinguishable
/// from real hardware records.
enum IncidentOrigin {
  demo('Simulated'),
  hardware('Hardware');

  const IncidentOrigin(this.label);

  final String label;

  bool get isSimulated => this == IncidentOrigin.demo;
}

/// A single logged event.
class Incident {
  const Incident({
    required this.id,
    required this.category,
    required this.origin,
    required this.occurredAt,
    required this.status,
    required this.summary,
    required this.deviceId,
    this.severity = Severity.info,
    this.location,
    this.riskScore,
    this.band,
    this.deliveryOutcome,
    this.attempts = 0,
    this.acknowledgements = 0,
    this.notes = const <String>[],
    this.acknowledgedAt,
  });

  final String id;
  final IncidentCategory category;
  final IncidentOrigin origin;
  final DateTime occurredAt;
  final IncidentStatus status;
  final String summary;
  final String deviceId;
  final Severity severity;

  /// Present for accident records. Null means no position was ever known.
  final GeoFix? location;

  /// Present for screening records: the AWTRA score.
  final double? riskScore;
  final String? band;

  /// Present for accident records: the LoRa delivery result.
  final TransmissionOutcome? deliveryOutcome;

  /// Attempts and acknowledgements are stored separately and rendered
  /// separately, because they are different facts.
  final int attempts;
  final int acknowledgements;

  final List<String> notes;
  final DateTime? acknowledgedAt;

  bool get isSimulated => origin.isSimulated;

  bool get isOpen => status == IncidentStatus.active;

  bool get wasDelivered => deliveryOutcome?.isDelivered ?? false;

  /// True when a packet was sent but never confirmed. Surfaced as unresolved.
  bool get isUnresolvedDelivery =>
      deliveryOutcome == TransmissionOutcome.sentUnacknowledged;

  bool get gpsWasFlagged => location == null;

  Incident copyWith({
    IncidentStatus? status,
    Severity? severity,
    String? summary,
    List<String>? notes,
    DateTime? acknowledgedAt,
  }) {
    return Incident(
      id: id,
      category: category,
      origin: origin,
      occurredAt: occurredAt,
      status: status ?? this.status,
      severity: severity ?? this.severity,
      summary: summary ?? this.summary,
      deviceId: deviceId,
      location: location,
      riskScore: riskScore,
      band: band,
      deliveryOutcome: deliveryOutcome,
      attempts: attempts,
      acknowledgements: acknowledgements,
      notes: notes ?? this.notes,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'category': category.name,
        'origin': origin.name,
        'occurredAt': occurredAt.toIso8601String(),
        'status': status.name,
        'severity': severity.name,
        'summary': summary,
        'deviceId': deviceId,
        if (location != null) 'location': location!.toJson(),
        if (riskScore != null) 'riskScore': riskScore,
        if (band != null) 'band': band,
        if (deliveryOutcome != null)
          'deliveryOutcome': deliveryOutcome!.name,
        'attempts': attempts,
        'acknowledgements': acknowledgements,
        'notes': notes,
        if (acknowledgedAt != null)
          'acknowledgedAt': acknowledgedAt!.toIso8601String(),
      };

  /// Tolerant of missing or corrupt fields so one bad record cannot make the
  /// whole history unreadable.
  static Incident? fromJson(Map<String, dynamic> json) {
    try {
      return Incident(
        id: json['id'] as String,
        category: IncidentCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => IncidentCategory.accident,
        ),
        origin: IncidentOrigin.values.firstWhere(
          (o) => o.name == json['origin'],
          orElse: () => IncidentOrigin.demo,
        ),
        occurredAt:
            DateTime.tryParse(json['occurredAt'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
        status: IncidentStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => IncidentStatus.active,
        ),
        severity: Severity.values.firstWhere(
          (s) => s.name == json['severity'],
          orElse: () => Severity.info,
        ),
        summary: json['summary'] as String? ?? 'Untitled record',
        deviceId: json['deviceId'] as String? ?? 'unknown',
        location: json['location'] == null
            ? null
            : GeoFix.fromJson(json['location'] as Map<String, dynamic>),
        riskScore: (json['riskScore'] as num?)?.toDouble(),
        band: json['band'] as String?,
        deliveryOutcome: json['deliveryOutcome'] == null
            ? null
            : TransmissionOutcome.values.firstWhere(
                (o) => o.name == json['deliveryOutcome'],
                orElse: () => TransmissionOutcome.radioFailure,
              ),
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        acknowledgements: (json['acknowledgements'] as num?)?.toInt() ?? 0,
        notes: (json['notes'] as List<dynamic>?)
                ?.map((n) => n.toString())
                .toList() ??
            const <String>[],
        acknowledgedAt: json['acknowledgedAt'] == null
            ? null
            : DateTime.tryParse(json['acknowledgedAt'] as String),
      );
    } on Object {
      return null;
    }
  }
}