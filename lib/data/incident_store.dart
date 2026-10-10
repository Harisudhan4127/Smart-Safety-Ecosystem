import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/models/incident.dart';
import '../domain/models/severity.dart';

/// Persistent incident log.
///
/// Incident history must survive a restart on every supported platform.
/// SQLite is deliberately not used because it has no Linux, Windows or macOS
/// implementation; instead records are held in memory and flushed as a single
/// JSON document in the platform documents directory.
///
/// The store owns no UI concerns: it exposes a [ValueListenable] so widgets can
/// rebuild without pulling in a state-management dependency.
class IncidentStore extends ChangeNotifier {
  IncidentStore({this.capacity = 500});

  /// Maximum retained records. Older entries are dropped on write, which bounds
  /// both memory and file size.
  final int capacity;

  final ValueNotifier<List<Incident>> _incidents =
      ValueNotifier<List<Incident>>(const <Incident>[]);

  /// Newest first. Exposed as a [ValueListenable] so screens can rebuild
  /// without a state-management dependency.
  ValueListenable<List<Incident>> get listenable => _incidents;
  List<Incident> get all => _incidents.value;
  int get count => _incidents.value.length;

  /// Records still awaiting review.
  List<Incident> get open =>
      _incidents.value.where((i) => i.isOpen).toList(growable: false);

  /// The most severe open record, used by the overview banner.
  Incident? get mostSevereOpen {
    Incident? best;
    for (final incident in _incidents.value) {
      if (!incident.isOpen) continue;
      if (best == null || incident.severity.rank > best.severity.rank) {
        best = incident;
      }
    }
    return best;
  }

  File? _file;
  bool _loaded = false;

  /// Loads persisted records. Safe to call more than once.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/incidents.json');
      _file = file;
      if (!file.existsSync()) return;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final records = <Incident>[];
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        final incident = Incident.fromJson(entry);
        if (incident != null) records.add(incident);
      }
      _incidents.value = records;
    } on Object catch (error) {
      // A corrupt or unreadable log must never prevent the app from starting.
      debugPrint('IncidentStore: could not read incident log ($error)');
    }
  }

  /// Appends a record and persists.
  Future<void> add(Incident incident) async {
    final next = <Incident>[incident, ..._incidents.value];
    _incidents.value = _trim(next);
    await _persist();
  }

  /// Replaces a record with an updated copy.
  Future<void> update(Incident incident) async {
    final next = _incidents.value
        .map((i) => i.id == incident.id ? incident : i)
        .toList(growable: false);
    _incidents.value = next;
    await _persist();
  }

  /// Acknowledges a record.
  Future<void> acknowledge(String id, {DateTime? at}) async {
    final incident = byId(id);
    if (incident == null || !incident.isOpen) return;
    await update(
      incident.copyWith(
        status: IncidentStatus.acknowledged,
        acknowledgedAt: at ?? DateTime.now(),
      ),
    );
  }

  /// Marks a record resolved.
  Future<void> resolve(String id) async {
    final incident = byId(id);
    if (incident == null) return;
    await update(incident.copyWith(status: IncidentStatus.resolved));
  }

  /// Discards a record. Callers are responsible for confirming this with the
  /// user first.
  Future<void> discard(String id) async {
    final incident = byId(id);
    if (incident == null) return;
    await update(incident.copyWith(status: IncidentStatus.discarded));
  }

  Incident? byId(String id) {
    for (final incident in _incidents.value) {
      if (incident.id == id) return incident;
    }
    return null;
  }

  /// Removes all records. Destructive; the UI confirms before calling.
  Future<void> clear() async {
    _incidents.value = const <Incident>[];
    await _persist();
  }

  /// Filters records by free-text query across summary, device and notes.
  List<Incident> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return all;
    return all
        .where(
          (i) =>
              i.summary.toLowerCase().contains(needle) ||
              i.deviceId.toLowerCase().contains(needle) ||
              i.band?.toLowerCase().contains(needle) == true ||
              i.notes.any((n) => n.toLowerCase().contains(needle)),
        )
        .toList(growable: false);
  }

  List<Incident> _trim(List<Incident> input) =>
      input.length > capacity ? input.sublist(0, capacity) : input;

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    try {
      final payload = jsonEncode(
        _incidents.value.map((i) => i.toJson()).toList(),
      );
      // Write to a sibling temp file then rename, so a crash mid-write cannot
      // leave a truncated log behind.
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(payload, flush: true);
      await temp.rename(file.path);
    } on Object catch (error) {
      debugPrint('IncidentStore: could not write incident log ($error)');
    }
  }

  @override
  void dispose() {
    _incidents.dispose();
    super.dispose();
  }
}