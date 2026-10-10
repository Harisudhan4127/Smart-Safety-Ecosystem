import 'dart:async';

import '../models/lora.dart';
import 'transport.dart';

/// A LoRa transport that has no gateway to talk to.
///
/// This is the **honest** default for Real Hardware Mode on a machine with no
/// radio attached. It reports "no gateway in range" for every attempt instead of
/// quietly succeeding, which is what stops the UI from implying that a packet
/// was delivered when nothing was ever transmitted.
///
/// Replacing it with a real serial or TCP adapter requires implementing
/// [PacketTransport] and changing one factory call; nothing else in the app
/// knows the difference.
class UnavailablePacketTransport implements PacketTransport {
  UnavailablePacketTransport({this.reason = 'No LoRa gateway is connected.'});

  /// Why this transport cannot operate, shown verbatim in diagnostics.
  final String reason;

  @override
  String get name => 'Unavailable LoRa transport';

  @override
  bool get isConnected => false;

  @override
  DateTime? get lastActivity => null;

  @override
  Future<TransmissionOutcome> transmit(
    LoraPacket packet, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    // No radio was ever opened, so nothing was transmitted. Reporting anything
    // other than a failure here would be a lie.
    return TransmissionOutcome.noGatewayInRange;
  }

  @override
  Future<void> dispose() async {}
}