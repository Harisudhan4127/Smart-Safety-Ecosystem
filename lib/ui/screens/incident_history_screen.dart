import 'package:flutter/material.dart';

import '../../core/design/app_theme.dart';
import '../../core/design/tokens.dart';

import '../../data/incident_store.dart';
import '../../domain/models/geo.dart';
import '../../domain/models/incident.dart';
import '../../domain/models/severity.dart';
import '../../state/app_controller.dart';
import '../components/surface_card.dart';
import '../shell/app_shell.dart';
import 'overview_screen.dart';
import 'simulation_lab_screen.dart';

/// Incident history with search, category filtering and record actions.
class IncidentHistoryScreen extends StatefulWidget {
  const IncidentHistoryScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<IncidentHistoryScreen> createState() => _IncidentHistoryScreenState();
}

class _IncidentHistoryScreenState extends State<IncidentHistoryScreen> {
  final TextEditingController _search = TextEditingController();
  IncidentCategory? _categoryFilter;
  bool _openOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Incident> _filtered(List<Incident> all) {
    var result = widget.controller.incidentStore.search(_search.text);
    if (_categoryFilter != null) {
      result = result.where((i) => i.category == _categoryFilter).toList();
    }
    if (_openOnly) {
      result = result.where((i) => i.isOpen).toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.controller,
        widget.controller.incidentStore.listenable,
      ]),
      builder: (context, _) {
        final all = widget.controller.incidentStore.all;
        final incidents = _filtered(all);

        return PageBody(
          children: [
            _Toolbar(
              search: _search,
              onSearchChanged: (_) => setState(() {}),
              categoryFilter: _categoryFilter,
              onCategoryChanged: (value) =>
                  setState(() => _categoryFilter = value),
              openOnly: _openOnly,
              onOpenOnlyChanged: (value) => setState(() => _openOnly = value),
            ),
            const SizedBox(height: Insets.lg),
            if (all.isEmpty)
              SurfaceCard(
                child: EmptyState(
                  icon: Icons.history_outlined,
                  title: 'No incidents recorded yet',
                  message:
                      'Alerts and screening records appear here once something '
                      'happens. Run a scenario in the Simulation Lab to see the '
                      'flow end to end.',
                  actionLabel: 'Open Simulation Lab',
                  onAction: () => _openLab(context),
                ),
              )
            else if (incidents.isEmpty)
              SurfaceCard(
                child: EmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'No matching records',
                  message: 'Try clearing the search box or filters.',
                  actionLabel: 'Clear filters',
                  onAction: () => setState(() {
                    _search.clear();
                    _categoryFilter = null;
                    _openOnly = false;
                  }),
                ),
              )
            else ...[
              Text(
                '${incidents.length} of ${all.length} records',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: Insets.md),
              SurfaceCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg,
                  vertical: Insets.sm,
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < incidents.length; i++) ...[
                      if (i > 0)
                        Divider(color: context.colors.border, height: 1),
                      IncidentRow(
                        incident: incidents[i],
                        onTap: () => _openRecord(context, incidents[i]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Insets.lg),
              _DatabaseActions(controller: widget.controller),
            ],
          ],
        );
      },
    );
  }

  void _openLab(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SimulationLabScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _openRecord(BuildContext context, Incident incident) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _RecordSheet(incident: incident, controller: widget.controller),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.search,
    required this.onSearchChanged,
    required this.categoryFilter,
    required this.onCategoryChanged,
    required this.openOnly,
    required this.onOpenOnlyChanged,
  });

  final TextEditingController search;
  final ValueChanged<String> onSearchChanged;
  final IncidentCategory? categoryFilter;
  final ValueChanged<IncidentCategory?> onCategoryChanged;
  final bool openOnly;
  final ValueChanged<bool> onOpenOnlyChanged;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: search,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search by summary, device or note',
              prefixIcon: Icon(Icons.search, size: 19),
            ),
          ),
          const SizedBox(height: Insets.md),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                label: const Text('All'),
                selected: categoryFilter == null,
                onSelected: (_) => onCategoryChanged(null),
              ),
              for (final category in IncidentCategory.values)
                FilterChip(
                  label: Text(category.label),
                  selected: categoryFilter == category,
                  onSelected: (selected) =>
                      onCategoryChanged(selected ? category : null),
                ),
              const SizedBox(width: Insets.sm),
              FilterChip(
                label: const Text('Active only'),
                avatar: Icon(
                  Icons.radio_button_unchecked,
                  size: 15,
                  color: openOnly
                      ? context.colors.accent
                      : context.colors.textTertiary,
                ),
                selected: openOnly,
                onSelected: onOpenOnlyChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full record detail with the available lifecycle actions.
class _RecordSheet extends StatelessWidget {
  const _RecordSheet({required this.incident, required this.controller});

  final Incident incident;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Insets.xl, 0, Insets.xl, Insets.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    incident.summary,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                StatusBadge(
                  label: incident.status.label,
                  severity: incident.status.tone,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            Row(
              children: [
                StatusBadge(
                  label: incident.category.label,
                  severity: Severity.info,
                  icon: incident.category == IncidentCategory.accident
                      ? Icons.car_crash_outlined
                      : Icons.monitor_heart_outlined,
                  dense: true,
                ),
                const SizedBox(width: Insets.sm),
                if (incident.isSimulated)
                  const StatusBadge(
                    label: 'Simulated',
                    severity: Severity.caution,
                    icon: Icons.science_outlined,
                    dense: true,
                  ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            DetailRow(
              label: 'Recorded',
              value:
                  '${incident.occurredAt.toLocal()} (${formatRelative(incident.occurredAt)})',
            ),
            DetailRow(label: 'Device', value: incident.deviceId),
            if (incident.category == IncidentCategory.accident) ...[
              DetailRow(
                label: 'Position',
                value: incident.location != null
                    ? formatGeoDms(incident.location!)
                    : 'Unavailable \u2014 flagged on the packet',
                valueColor: incident.location == null ? colors.warning : null,
              ),
              DetailRow(
                label: 'Delivery',
                value: incident.deliveryOutcome == null
                    ? '\u2014'
                    : describeOutcome(incident.deliveryOutcome!),
                valueColor: incident.wasDelivered
                    ? colors.success
                    : colors.warning,
              ),
              DetailRow(
                label: 'Attempts / ACKs',
                value: '${incident.attempts} / ${incident.acknowledgements}',
              ),
            ] else ...[
              DetailRow(
                label: 'Risk score',
                value: incident.riskScore?.toStringAsFixed(0) ?? '\u2014',
              ),
              DetailRow(label: 'Band', value: incident.band ?? '\u2014'),
            ],
            if (incident.acknowledgedAt != null)
              DetailRow(
                label: 'Acknowledged',
                value: incident.acknowledgedAt!.toLocal().toString(),
              ),
            if (incident.notes.isNotEmpty) ...[
              const SizedBox(height: Insets.md),
              Text('Notes', style: theme.textTheme.titleSmall),
              const SizedBox(height: Insets.sm),
              for (final note in incident.notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('\u2022 $note', style: theme.textTheme.bodySmall),
                ),
            ],
            const SizedBox(height: Insets.xl),
            if (incident.isOpen) ...[
              FilledButton.icon(
                onPressed: () {
                  controller.incidentStore.acknowledge(incident.id);
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.done_rounded, size: 17),
                label: const Text('Acknowledge'),
              ),
              const SizedBox(height: Insets.sm),
              OutlinedButton.icon(
                onPressed: () {
                  controller.incidentStore.resolve(incident.id);
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.archive_outlined, size: 17),
                label: const Text('Mark resolved'),
              ),
              const SizedBox(height: Insets.sm),
            ],
            TextButton(
              onPressed: () => _discard(context),
              style: TextButton.styleFrom(foregroundColor: colors.critical),
              child: const Text('Discard record'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _discard(BuildContext context) async {
    final confirmed = await confirmAction(
      context,
      title: 'Discard this record?',
      message:
          'The record stays in history but is marked discarded, so it no '
          'longer counts as an active alert. This cannot be undone from here.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!confirmed) return;
    await controller.incidentStore.discard(incident.id);
    if (context.mounted) Navigator.of(context).pop();
  }
}

/// Storage and logging controls.
class _DatabaseActions extends StatelessWidget {
  const _DatabaseActions({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final store = controller.incidentStore;

    return AdvancedDisclosure(
      title: 'Database and logging',
      subtitle: 'Export, retention and maintenance',
      icon: Icons.storage_outlined,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailRow(label: 'Stored records', value: '${store.count}'),
            DetailRow(label: 'Active records', value: '${store.open.length}'),
            DetailRow(
              label: 'Retention limit',
              value: '${store.capacity} records',
            ),
            const DetailRow(
              label: 'Storage',
              value: 'JSON document in the app data directory',
            ),
            const SizedBox(height: Insets.md),
            Text(
              'Incident history is written to disk on every change. If the log '
              'is ever unreadable the app still starts, with an empty history, '
              'rather than failing.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Insets.lg),
            OutlinedButton.icon(
              onPressed: () => _clear(context, store),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.critical,
              ),
              icon: const Icon(Icons.delete_outline, size: 17),
              label: const Text('Clear all records'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clear(BuildContext context, IncidentStore store) async {
    final confirmed = await confirmAction(
      context,
      title: 'Clear all incident records?',
      message:
          'Every stored record will be permanently deleted, including active '
          'alerts. This cannot be undone.',
      confirmLabel: 'Delete everything',
      destructive: true,
    );
    if (!confirmed) return;
    await store.clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Incident history cleared.')),
        );
    }
  }
}
