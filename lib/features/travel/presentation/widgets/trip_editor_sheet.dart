import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../domain/travel_rules.dart';
import '../../domain/trip.dart';
import '../travel_labels.dart';

/// Entering a flight, a train or a coach.
///
/// The departure time is required and the arrival is not, and that asymmetry is
/// the schema's (0129): a trip IS a scheduled departure, and one whose hour is
/// unknown is an intention that should not be entered yet. An arrival is often
/// genuinely unknown at booking and nothing depends on it — a man's arrival is
/// measured by what he confirms, not by the timetable.
Future<TripDraft?> showTripEditorSheet(
  BuildContext context, {
  required List<TravelPoint> points,
  Trip? existing,
}) => showAppSheet<TripDraft>(
  context: context,
  builder: (_) => _TripEditorSheet(points: points, existing: existing),
);

class _TripEditorSheet extends StatefulWidget {
  const _TripEditorSheet({required this.points, this.existing});

  final List<TravelPoint> points;
  final Trip? existing;

  @override
  State<_TripEditorSheet> createState() => _TripEditorSheetState();
}

class _TripEditorSheetState extends State<_TripEditorSheet> {
  late LegRole _role = widget.existing?.role ?? LegRole.inbound;
  late TravelMode _mode =
      widget.existing?.mode ?? TravelRules.defaultModeFor(_role);
  late String? _from = widget.existing?.fromPointId;
  late String? _to = widget.existing?.toPointId;

  late DateTime _departs =
      widget.existing?.plannedDepartureAt ??
      DateTime.now().add(const Duration(days: 1));
  late DateTime? _arrives = widget.existing?.plannedArrivalAt;

  late final _number = TextEditingController(
    text: widget.existing?.tripNumber ?? '',
  );
  late final _note = TextEditingController(text: widget.existing?.note ?? '');

  String? _error;

  /// Changing the kind of movement changes what may carry it and where it may
  /// run, so anything already chosen that no longer fits is dropped rather than
  /// left to be refused on save. A form that silently keeps an impossible value
  /// is a form that fails at the last step for a reason nobody can see.
  void _setRole(LegRole role) {
    setState(() {
      _role = role;
      _error = null;
      if (!TravelRules.modesFor(role).contains(_mode)) {
        _mode = TravelRules.defaultModeFor(role);
      }
      final origins = TravelRules.originsFor(role, widget.points);
      final destinations = TravelRules.destinationsFor(role, widget.points);
      if (!origins.any((p) => p.id == _from)) _from = null;
      if (!destinations.any((p) => p.id == _to)) _to = null;
    });
  }

  @override
  void dispose() {
    _number.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? initial.hour,
      time?.minute ?? initial.minute,
    );
  }

  void _save() {
    final l = context.l10n;
    if (_from == null || _to == null) {
      setState(() => _error = l.travelFieldRequired);
      return;
    }
    if (_from == _to) {
      setState(() => _error = l.travelSameEndpoints);
      return;
    }
    Navigator.of(context).pop(
      TripDraft(
        mode: _mode,
        role: _role,
        fromPointId: _from!,
        toPointId: _to!,
        plannedDepartureAt: _departs,
        plannedArrivalAt: _arrives,
        tripNumber: _number.text,
        note: _note.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // The house shape for a sheet: the same 20/4/20/24 every other sheet in
    // this app uses, and a scroll view inside it. Both matter here — this form
    // is eleven controls tall and overflows a phone held in portrait without
    // one, which is a red-and-yellow crash bar rather than a scrollbar.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? l.travelNewTrip : l.travelEditTrip,
              style: text.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),

            Text(l.travelFieldRole, style: text.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final role in LegRole.values)
                  ChoiceChip(
                    selected: _role == role,
                    onSelected: (_) => _setRole(role),
                    label: Text(legRoleLabel(context, role)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Only what may carry a movement of this kind. An arrival offers the
            // aeroplane alone; an internal movement offers everything except it.
            Text(l.travelFieldMode, style: text.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final mode in TravelRules.modesFor(_role))
                  ChoiceChip(
                    selected: _mode == mode,
                    onSelected: (_) => setState(() => _mode = mode),
                    avatar: Icon(travelModeIcon(mode), size: 16),
                    label: Text(travelModeLabel(context, mode)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Syrian airports for an arrival's origin, Saudi ones for its
            // destination, and the two holy cities for anything internal.
            _PointField(
              label: l.travelFieldFrom,
              points: TravelRules.originsFor(_role, widget.points),
              value: _from,
              onChanged: (v) => setState(() {
                _from = v;
                _error = null;
              }),
            ),
            const SizedBox(height: AppSpacing.sm),
            _PointField(
              label: l.travelFieldTo,
              points: TravelRules.destinationsFor(_role, widget.points),
              value: _to,
              onChanged: (v) => setState(() {
                _to = v;
                _error = null;
              }),
            ),
            const SizedBox(height: AppSpacing.md),

            // The number alone. The operating airline was a second field here until
            // 0134: derivable from the number by anybody who wanted it, asked for
            // by nobody, and one more thing to mistype forty times in a sitting.
            TextField(
              controller: _number,
              decoration: InputDecoration(labelText: l.travelFieldNumber),
            ),
            const SizedBox(height: AppSpacing.sm),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.travelWhen),
              title: Text(l.travelFieldDeparture),
              subtitle: Text(travelWhen(context, _departs)),
              trailing: TextButton(
                onPressed: () async {
                  final picked = await _pick(_departs);
                  if (picked != null) setState(() => _departs = picked);
                },
                child: Text(l.travelPickDateTime),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.pending),
              title: Text(l.travelFieldArrival),
              subtitle: Text(travelWhen(context, _arrives)),
              trailing: TextButton(
                onPressed: () async {
                  final picked = await _pick(_arrives ?? _departs);
                  if (picked != null) setState(() => _arrives = picked);
                },
                child: Text(l.travelPickDateTime),
              ),
            ),

            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: l.travelFieldNote),
              minLines: 1,
              maxLines: 3,
            ),

            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: text.bodySmall?.copyWith(color: scheme.error),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: _save, child: Text(l.commonSave)),
          ],
        ),
      ),
    );
  }
}

class _PointField extends StatelessWidget {
  const _PointField({
    required this.label,
    required this.points,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<TravelPoint> points;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final point in points)
          DropdownMenuItem(
            value: point.id,
            child: Text(
              point.name.of(context),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
