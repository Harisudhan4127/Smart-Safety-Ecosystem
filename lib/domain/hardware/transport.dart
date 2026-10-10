import 'dart:async';

import '../models/geo.dart';
import '../models/imu.dart';
import '../models/lora.dart';

/// A transport that can carry a [LoraPacket] from a vehicle node to a gateway.
///
/// This is the seam between Demo Mode and Real Hardware Mode. The application
/// core only ever talks to this interface, which is why the simulation and the
/// real radio path share the same detection logic.
///
/// Implementations must never fabricate a delivery: if they cannot reach a
/// gateway they must say so.
abstract interface class PacketTransport {
  /// Short human-readable name shown in diagnostics.
  String get name;

  /// Whether the transport is currently usable.
  bool get isConnected;

  /// When this transport last completed a transaction.
  DateTime? get lastActivity;

  /// Attempts to send [packet], returning the true outcome.
  ///
  /// Implementations must distinguish "sent" from "acknowledged".
  Future<TransmissionOutcome> transmit(
    LoraPacket packet, {
    Duration timeout = const Duration(seconds: 3),
  });

  Future<void> dispose();
}

/// A source of IMU samples.
///
/// Real Hardware Mode would implement this against the vehicle node. Demo Mode
/// implements it with a scripted, deterministic generator.
abstract interface class ImuSource {
  Stream<ImuSample> get samples;
  bool get isRunning;
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}

/// A source of GPS fixes.
abstract interface class GpsSource {
  /// Emits the current fix, or null when no fix is available.
  Stream<GeoFix?> get fixes;
  GeoFix? get current;
  Future<void> dispose();
}