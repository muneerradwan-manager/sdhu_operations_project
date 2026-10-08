import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/permission_codes.dart';
import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../auth/application/session_cubit.dart';
import '../../../profile/domain/profile.dart';
import '../../application/module_editor_cubit.dart';
import '../../domain/module_type.dart';
import '../../domain/reference_item.dart';
import '../employee_picker_screen.dart';
import 'module_field_input.dart';
import 'picker_sheet.dart';

/// Adds or edits one place in a file — a sector, or a hotel inside one — with
/// everyone who holds a role there.
///
/// One sheet serves both because the LEVEL decides what it asks for: a level
/// with a master-data list asks which entry (which hotel), a level without one
/// asks for a name ("القطاع الأول"), and each then asks for its own roles. A
/// third level would need no new screen.
Future<NodeDraft?> showNodeEditorSheet(
  BuildContext context, {
  required ModuleLevel level,
  required String seasonId,
  required List<Profile> employees,
  ReferenceSet? referenceSet,
  ReferenceSet? secondarySet,
  ReferenceSet? hotelsSet,
  List<ReferenceSet> referenceSets = const [],
  Set<String> takenEntries = const {},
  Set<String> takenSecondaryEntries = const {},
  NodeDraft? existing,
  String? suggestedLabel,
}) {
  return showModalBottomSheet<NodeDraft>(
    context: context,
    // Over the rail as well as the page — see [showAppSheet].
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _NodeEditorSheet(
      level: level,
      seasonId: seasonId,
      employees: employees,
      referenceSet: referenceSet,
      secondarySet: secondarySet,
      hotelsSet: hotelsSet,
      referenceSets: referenceSets,
      takenEntries: takenEntries,
      takenSecondaryEntries: takenSecondaryEntries,
      existing: existing,
      suggestedLabel: suggestedLabel,
    ),
  );
}

class _NodeEditorSheet extends StatefulWidget {
  const _NodeEditorSheet({
    required this.level,
    required this.seasonId,
    required this.employees,
    required this.referenceSet,
    required this.secondarySet,
    required this.hotelsSet,
    required this.referenceSets,
    required this.takenEntries,
    required this.takenSecondaryEntries,
    required this.existing,
    required this.suggestedLabel,
  });

  final ModuleLevel level;
  final String seasonId;

  /// The season's participants, kept for rendering the names already chosen.
  /// Choosing someone new goes to the picker page, which asks the database.
  final List<Profile> employees;
  final ReferenceSet? referenceSet;

  /// The list the level ties a node to, as opposed to the one it is drawn from
  /// — the التكتلات behind a برج. Null for a level that ties to nothing.
  final ReferenceSet? secondarySet;

  /// The الفنادق, for asking where each man on this node sleeps. Offered only
  /// where the node is not a place itself: a برج IS a hotel and its people are
  /// housed by being posted to it, so asking there would be asking somebody to
  /// re-enter what the file already says (0136, 0139).
  final ReferenceSet? hotelsSet;

  /// Every list loaded, for a level field of the `reference` kind to resolve
  /// its own against.
  final List<ReferenceSet> referenceSets;

  final Set<String> takenEntries;
  final Set<String> takenSecondaryEntries;
  final NodeDraft? existing;
  final String? suggestedLabel;

  @override
  State<_NodeEditorSheet> createState() => _NodeEditorSheetState();
}

class _NodeEditorSheetState extends State<_NodeEditorSheet> {
  late final _label = TextEditingController(
    text: widget.existing?.label ?? widget.suggestedLabel ?? '',
  );
  late String? _entry = widget.existing?.referenceItemId;
  late String? _secondary = widget.existing?.secondaryReferenceItemId;
  late final Map<String, dynamic> _data = {
    ...(widget.existing?.data ?? const <String, dynamic>{}),
  };
  late final Map<String, Set<String>> _members = {
    for (final role in widget.level.roles)
      role.id: {...(widget.existing?.membersOf(role.id) ?? const <String>{})},
  };
  late final Map<String, Map<String, String?>> _housing = {
    for (final role in widget.level.roles)
      role.id: {
        ...(widget.existing?.housingOf(role.id) ?? const <String, String?>{}),
      },
  };

  /// Whether this level asks where its people sleep. A tower does not: it IS
  /// the hotel.
  bool get _asksHousing => !widget.level.isPlace && widget.hotelsSet != null;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _pickEntry() async {
    final l = context.l10n;
    // This season's hotels only, and only this level's slice of the list. The
    // set still holds every season's — a tower saved last year has to keep
    // resolving to its name — but you cannot pick one of them for a tower this
    // year; and since 0095 one مخيمات list serves both مشاعر, so the منى file
    // is offered منى's camps and not عرفات's.
    final items =
        widget.referenceSet?.itemsToOffer(
          widget.seasonId,
          filter: widget.level.referenceFilter,
        ) ??
        const <ReferenceItem>[];
    final result = await showPickerSheet(
      context,
      title: widget.level.name.of(context),
      // An entry standing elsewhere in this file is left out: a hotel belongs
      // to exactly one sector, and the database refuses a second one anyway.
      options: [
        for (final i in items)
          if (i.id == _entry || !widget.takenEntries.contains(i.id))
            PickerOption(id: i.id, label: i.name.of(context)),
      ],
      selected: {?_entry},
      emptyMessage: l.referenceEmpty,
    );
    if (result != null) setState(() => _entry = result.firstOrNull);
  }

  /// The second list — what this node is tied to. Same rules as the first: this
  /// season's entries, and never one already taken elsewhere in the file, which
  /// is the point of recording it at all.
  Future<void> _pickSecondary() async {
    final l = context.l10n;
    final set = widget.secondarySet;
    final items =
        set?.itemsForSeason(widget.seasonId) ?? const <ReferenceItem>[];
    final result = await showPickerSheet(
      context,
      title: set?.name.of(context) ?? '',
      options: [
        for (final i in items)
          if (i.id == _secondary ||
              !widget.takenSecondaryEntries.contains(i.id))
            PickerOption(id: i.id, label: i.name.of(context)),
      ],
      selected: {?_secondary},
      emptyMessage: l.referenceEmpty,
    );
    if (result != null) setState(() => _secondary = result.firstOrNull);
  }

  Future<void> _pickRole(ModuleRole role) async {
    final result = await showEmployeePicker(
      context,
      title: role.name.of(context),
      seasonId: widget.seasonId,
      multiple: role.allowsMultiple,
      selected: _members[role.id] ?? const {},
    );
    if (result != null && mounted) {
      setState(() {
        _members[role.id] = result;
        // A man taken off the role takes his hotel with him: leaving the entry
        // behind would put it back on him if he were ever added again.
        _housing[role.id]?.removeWhere((id, _) => !result.contains(id));
      });
    }
  }

  /// Where one man on this node sleeps. Any hotel of this season — he may well
  /// be housed in a tower of a different sector, and the office is the judge of
  /// that rather than this list.
  Future<void> _pickHousing(ModuleRole role, Profile person) async {
    final l = context.l10n;
    final set = widget.hotelsSet;
    if (set == null) return;
    final current = _housing[role.id]?[person.id];
    final result = await showPickerSheet(
      context,
      title: '${l.moduleMemberHousing} — ${person.fullName}',
      options: [
        for (final i in set.itemsForSeason(widget.seasonId))
          PickerOption(id: i.id, label: i.name.of(context)),
      ],
      selected: {?current},
      emptyMessage: l.referenceEmpty,
    );
    if (result != null && mounted) {
      setState(() => _housing[role.id]![person.id] = result.firstOrNull);
    }
  }

  void _submit() {
    Navigator.of(context).pop(
      NodeDraft(
        id: widget.existing?.id,
        referenceItemId: widget.level.isNamedByHand ? null : _entry,
        secondaryReferenceItemId: widget.secondarySet == null
            ? null
            : _secondary,
        label: widget.level.isNamedByHand ? _label.text.trim() : null,
        data: _data,
        roleMembers: _members,
        housing: _asksHousing ? _housing : const {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final level = widget.level;
    final entry = widget.referenceSet?.items
        .where((i) => i.id == _entry)
        .firstOrNull;
    // Resolved against every season's entries, never this season's: a تكتل
    // chosen last year still has to render its name this year.
    final secondary = widget.secondarySet?.items
        .where((i) => i.id == _secondary)
        .firstOrNull;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        // Not ResponsivePage: its `Center` expands to whatever height it is
        // allowed, which here is the 0.85 cap — so a sheet with four rows in it
        // stood nearly full-height with its content marooned in the middle.
        // `heightFactor: 1` sizes this to the content instead, and the cap goes
        // back to being a cap rather than a height.
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.existing == null
                              ? l.moduleNodeAdd(level.name.of(context))
                              : l.moduleNodeEdit(level.name.of(context)),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    children: [
                      if (level.isNamedByHand)
                        TextField(
                          controller: _label,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: '${l.moduleNodeName} *',
                            prefixIcon: const Icon(AppIcons.moduleType),
                          ),
                        )
                      else
                        InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          onTap: _pickEntry,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: '${level.name.of(context)} *',
                              prefixIcon: const Icon(AppIcons.organization),
                              suffixIcon: const Icon(Icons.arrow_drop_down),
                            ),
                            child: Text(
                              entry?.name.of(context) ?? l.moduleRoleUnassigned,
                              style: entry == null
                                  ? TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      // Directly beneath what the node IS: the برج is chosen,
                      // and then the تكتل it falls under. Required, and never
                      // one already tied to another برج in this file.
                      if (widget.secondarySet case final set?) ...[
                        const SizedBox(height: AppSpacing.md),
                        InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          onTap: _pickSecondary,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: '${set.name.of(context)} *',
                              prefixIcon: const Icon(AppIcons.participants),
                              suffixIcon: const Icon(Icons.arrow_drop_down),
                            ),
                            child: Text(
                              secondary?.name.of(context) ??
                                  l.moduleRoleUnassigned,
                              style: secondary == null
                                  ? TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                      // What this node carries besides its name: the الطاقة
                      // الاستيعابية of a مخيم, and where it is. Same widget the
                      // file's own fields use — a field is a field.
                      for (final field in level.fields) ...[
                        const SizedBox(height: AppSpacing.md),
                        ModuleFieldInput(
                          field: field,
                          value: _data[field.key],
                          referenceSet: widget.referenceSets
                              .where((s) => s.id == field.referenceSetId)
                              .firstOrNull,
                          onChanged: (v) =>
                              setState(() => _data[field.key] = v),
                        ),
                      ],
                      // Staffing is its own permission: an editor without
                      // modules.members shapes the node but does not put
                      // people on it, so the pickers are not offered.
                      if (context.watch<SessionCubit>().state.can(
                        PermissionCodes.modulesMembers,
                      ))
                        for (final role in level.roles) ...[
                          const SizedBox(height: AppSpacing.md),
                          _RolePicker(
                            role: role,
                            people: [
                              for (final e in widget.employees)
                                if ((_members[role.id] ?? const {}).contains(
                                  e.id,
                                ))
                                  e,
                            ],
                            onTap: () => _pickRole(role),
                            // Null where the level does not ask — a تكتل and a
                            // برج are not asked the same question.
                            housing: _asksHousing
                                ? (_housing[role.id] ?? const {})
                                : null,
                            hotels: widget.hotelsSet,
                            onPickHousing: (p) => _pickHousing(role, p),
                          ),
                        ],
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(AppIcons.approve),
                        label: Text(l.commonSave),
                      ),
                      SizedBox(
                        height: MediaQuery.viewPaddingOf(context).bottom,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One role and who holds it. Nothing stops the same person appearing under two
/// roles here — a sector supervisor commonly stands in as his own deputy.
///
/// Where the level asks where its people sleep, the names stop being chips and
/// become rows: a chip cannot carry a second fact, and the hotel has to be
/// readable and tappable per man. A برج passes [housing] null and the card is
/// exactly what it always was.
class _RolePicker extends StatelessWidget {
  const _RolePicker({
    required this.role,
    required this.people,
    required this.onTap,
    this.housing,
    this.hotels,
    this.onPickHousing,
  });

  final ModuleRole role;
  final List<Profile> people;
  final VoidCallback onTap;

  /// Profile id to hotel entry id, or null for a level that does not ask.
  final Map<String, String?>? housing;
  final ReferenceSet? hotels;
  final void Function(Profile)? onPickHousing;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final asksHousing = housing != null && hotels != null;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      // Tapping the card picks the PEOPLE. With housing rows inside it the card
      // is no longer one target, so the header carries the tap instead.
      onTap: asksHousing ? null : onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: asksHousing ? onTap : null,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    role.isRequired
                        ? '${role.name.of(context)} *'
                        : role.name.of(context),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Icon(
                  role.allowsMultiple
                      ? AppIcons.participants
                      : AppIcons.jobTitle,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (people.isEmpty)
            Text(
              l.moduleRoleUnassigned,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          else if (!asksHousing)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final p in people)
                  Chip(
                    avatar: ProfileAvatar(
                      photoUrl: p.photoUrl,
                      name: p.fullName,
                      radius: 11,
                    ),
                    label: Text(p.fullName),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            )
          else
            for (final p in people)
              _HousedPerson(
                person: p,
                // Resolved against every entry rather than this season's: a
                // hotel chosen last year still has to render its name.
                hotel: hotels!.items
                    .where((i) => i.id == housing![p.id])
                    .firstOrNull,
                onTap: () => onPickHousing?.call(p),
              ),
        ],
      ),
    );
  }
}

/// One man on a role, and the hotel he sleeps in. Left blank rather than
/// required: a قطاع entered before anyone has been told where its supervisor is
/// staying is still a قطاع, and a required field would make it unsaveable.
class _HousedPerson extends StatelessWidget {
  const _HousedPerson({
    required this.person,
    required this.hotel,
    required this.onTap,
  });

  final Profile person;
  final ReferenceItem? hotel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final unset = hotel == null;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              ProfileAvatar(
                photoUrl: person.photoUrl,
                name: person.fullName,
                radius: 14,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.fullName,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      unset
                          ? l.moduleHousingUnset
                          : '${l.moduleMemberHousing}: '
                                '${hotel!.name.of(context)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: unset ? FontStyle.italic : null,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(AppIcons.organization, size: 16, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
