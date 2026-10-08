import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../domain/journey_leg.dart';
import '../../domain/travel_rules.dart';
import '../../domain/trip.dart';
import '../travel_labels.dart';

/// Recording a movement nobody booked.
///
/// This is the sheet the whole «القطار ليس إلزامياً» requirement comes down to.
/// A man who drove from مكة to المدينة opens it, says so, and his timeline
/// shows a car where somebody else's shows a train — with no note anywhere
/// that anything is missing, because nothing is.
///
/// It defaults to [SelfLegDraft.completed] because the common case by far is a
/// man recording a journey he has already made, not one he intends to make.
///
/// [legs] is what he has already — see [TravelRules.internalOriginCity]. The
/// sheet offers an internal movement only out of the city the record already
/// puts him in, because the alternative is what happened: a second مكة →
/// المدينة recorded for a man who was in المدينة, which no single-movement
/// rule can catch and which comes back out of the register as two stays in
/// مكة with nothing in between that could have taken him back.
Future<SelfLegDraft?> showRecordLegSheet(
  BuildContext context, {
  required List<TravelPoint> points,
  List<JourneyLeg> legs = const [],
  LegRole role = LegRole.internal,
  String? fromPointId,
  String? toPointId,
}) => showAppSheet<SelfLegDraft>(
  context: context,
  builder: (_) => _RecordLegSheet(
    points: points,
    legs: legs,
    role: role,
    fromPointId: fromPointId,
    toPointId: toPointId,
  ),
);

class _RecordLegSheet extends StatefulWidget {
  const _RecordLegSheet({
    required this.points,
    required this.legs,
    required this.role,
    this.fromPointId,
    this.toPointId,
  });

  final List<TravelPoint> points;

  /// The movements already recorded for this man, which decide where a new one
  /// may set out from.
  final List<JourneyLeg> legs;

  final LegRole role;
  final String? fromPointId;
  final String? toPointId;

  @override
  State<_RecordLegSheet> createState() => _RecordLegSheetState();
}

class _RecordLegSheetState extends State<_RecordLegSheet> {
  late LegRole _role = widget.role;

  /// Road first, and that is not an accident: this sheet exists for the private
  /// car, and the commonest answer should be the one already selected. It is a
  /// legal mode for an internal movement, which is what this sheet opens on.
  TravelMode _mode = TravelMode.road;

  late String? _from = widget.fromPointId;
  late String? _to = widget.toPointId;

  /// See [_TripEditorSheetState._setRole]: a role change narrows what may
  /// carry the movement and where it may run, so anything now impossible is
  /// dropped instead of being refused at the last step.
  void _setRole(LegRole role) {
    setState(() {
      _role = role;
      _error = null;
      if (!TravelRules.modesFor(role).contains(_mode)) {
        _mode = TravelRules.defaultModeFor(role);
      }
      _prune();
    });
  }

  /// The city the record already puts him in when this movement sets out, or
  /// null where nothing narrows it. Only asked of a تنقّل داخلي: a man in مكة
  /// flies home from جدة, so «the airport must be in the city he is in» is
  /// false of a return and would refuse the commonest one there is.
  String? get _mustDepartFrom => _role != LegRole.internal
      ? null
      : TravelRules.internalOriginCity(
          legs: widget.legs,
          points: widget.points,
          at: _at,
        );

  /// Where this movement may start: the office's rule, narrowed to where he
  /// actually is.
  List<TravelPoint> get _origins {
    final city = _mustDepartFrom;
    return TravelRules.originsFor(_role, widget.points)
        .where((p) => TravelRules.canDepartFrom(p, city))
        .toList();
  }

  /// Where it may end — never a point in the city it started from. The id
  /// check alone lets «مكة المكرمة → محطة مكة المكرمة» through, which is two
  /// rows of master data and one place, and would land in the register as a
  /// movement that carried him nowhere.
  List<TravelPoint> get _destinations {
    final from = _origins.where((p) => p.id == _from).firstOrNull;
    return TravelRules.destinationsFor(_role, widget.points)
        .where((p) => p.id != _from && (from == null || p.city != from.city))
        .toList();
  }

  /// Drops a choice the current shape no longer allows, so nothing is refused
  /// at the last step that could have been withdrawn when it stopped being
  /// possible.
  void _prune() {
    if (!_origins.any((p) => p.id == _from)) _from = null;
    if (!_destinations.any((p) => p.id == _to)) _to = null;
  }

  DateTime _at = DateTime.now();
  bool _completed = true;
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (!mounted) return;
    setState(() {
      _at = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _at.hour,
        time?.minute ?? _at.minute,
      );
      _error = null;
      // The day decides which movement came before this one, so moving it can
      // move where he was — a drive backdated to before the train sets out
      // from مكة, the same drive dated after it sets out from المدينة.
      _prune();
    });
  }

  void _save() {
    final l = context.l10n;
    if (_from == null || _to == null) {
      setState(() => _error = l.travelFieldRequired);
      return;
    }
    // Both lists are already narrowed to what may be chosen; this is the same
    // question asked once more at the last moment, because the day can change
    // under a choice already made.
    if (!_origins.any((p) => p.id == _from)) {
      setState(() {
        _error = l.travelMustStartWhereHeIs;
        _prune();
      });
      return;
    }
    if (!_destinations.any((p) => p.id == _to)) {
      setState(() {
        _error = l.travelSameEndpoints;
        _prune();
      });
      return;
    }
    Navigator.of(context).pop(
      SelfLegDraft(
        role: _role,
        mode: _mode,
        fromPointId: _from!,
        toPointId: _to!,
        departureAt: _at,
        note: _note.text,
        completed: _completed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // The same 20/4/20/24 and the same scroll view every other sheet in this app
    // uses. See [showTripEditorSheet]'s note: showAppSheet supplies the bottom
    // inset and nothing else, so the horizontal padding is each sheet's own.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.travelRecordTitle, style: text.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.travelRecordSubtitle,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),

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

            _PointField(
              label: l.travelFieldFrom,
              points: _origins,
              value: _from,
              onChanged: (v) => setState(() {
                _from = v;
                _error = null;
                // The destination cannot be in the city just chosen to leave.
                _prune();
              }),
            ),
            // Why the list is short, said rather than left to be discovered.
            // A picker that has quietly dropped مكة is a picker the reader
            // thinks is broken until somebody tells him he is in المدينة.
            if (_mustDepartFrom case final city?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l.travelCurrentlyIn(city),
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            _PointField(
              label: l.travelFieldTo,
              points: _destinations,
              value: _to,
              onChanged: (v) => setState(() {
                _to = v;
                _error = null;
              }),
            ),
            const SizedBox(height: AppSpacing.md),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.travelWhen),
              title: Text(l.travelFieldDeparture),
              subtitle: Text(travelWhen(context, _at)),
              trailing: TextButton(
                onPressed: _pickWhen,
                child: Text(l.travelPickDateTime),
              ),
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _completed,
              onChanged: (v) => setState(() => _completed = v),
              title: Text(l.travelRecordAlreadyHappened),
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
