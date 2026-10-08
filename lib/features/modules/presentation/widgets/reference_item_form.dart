import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../application/reference_data_cubit.dart';
import '../../domain/module_type.dart';
import '../../domain/reference_item.dart';
import 'module_field_input.dart';

/// Add or edit one master-data entry. The form below the name is generated from
/// the set's own schema, which is why adding hotels and adding clusters is the
/// same code — and why a new master-data list needs none.
Future<void> showReferenceItemForm(
  BuildContext context, {
  required ReferenceSet set,
  ReferenceItem? item,
}) {
  final cubit = context.read<ReferenceDataCubit>();
  return showModalBottomSheet<void>(
    context: context,
    // Over the rail as well as the page — see [showAppSheet].
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _ItemForm(set: set, item: item),
    ),
  );
}

class _ItemForm extends StatefulWidget {
  const _ItemForm({required this.set, this.item});

  final ReferenceSet set;
  final ReferenceItem? item;

  @override
  State<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<_ItemForm> {
  late final _ar = TextEditingController(text: widget.item?.name.ar ?? '');
  late final _en = TextEditingController(text: widget.item?.name.en ?? '');
  late final Map<String, dynamic> _data = {...?widget.item?.data};

  bool _saving = false;

  @override
  void dispose() {
    _ar.dispose();
    _en.dispose();
    super.dispose();
  }

  void _setValue(String key, Object? value) {
    setState(() {
      if (value == null || (value is String && value.isEmpty)) {
        _data.remove(key);
      } else {
        _data[key] = value;
      }
    });
  }

  /// The name plus every field the set marks required.
  ({bool ok, String? label}) _validate(BuildContext context) {
    if (_ar.text.trim().isEmpty) {
      return (ok: false, label: context.l10n.referenceItemName);
    }
    for (final field in widget.set.fields.where((f) => f.isRequired)) {
      final value = _data[field.key];
      if (value == null || '$value'.trim().isEmpty) {
        return (ok: false, label: field.label.of(context));
      }
    }
    return (ok: true, label: null);
  }

  Future<void> _save() async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final cubit = context.read<ReferenceDataCubit>();

    final check = _validate(context);
    if (!check.ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${check.label} — ${l.commonRequired}')),
        );
      return;
    }

    setState(() => _saving = true);
    final item = widget.item;
    final result = item == null
        ? await cubit.addItem(
            setId: widget.set.id,
            nameAr: _ar.text.trim(),
            nameEn: _en.text.trim(),
            data: _data,
          )
        : await cubit.updateItem(
            id: item.id,
            nameAr: _ar.text.trim(),
            nameEn: _en.text.trim(),
            data: _data,
          );

    if (!mounted) return;
    setState(() => _saving = false);

    final message = switch (result.outcome) {
      ReferenceOutcome.ok => l.referenceItemSaved,
      ReferenceOutcome.duplicate => l.referenceDuplicate,
      ReferenceOutcome.inUse => l.referenceInUse,
      ReferenceOutcome.failed => result.message ?? '',
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    if (result.isOk) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Reference fields resolve their options against the freshest sets.
    final state = context.watch<ReferenceDataCubit>().state;
    final sets = state.sets;

    /// The list a reference field may CHOOSE from.
    ///
    /// Season-scoped for a scoped set: a مجموعة entered this year belongs to a
    /// تكتل contracted this year, and offering last year's would attach it to a
    /// cluster that is not running. Cities are not scoped and are unaffected —
    /// which is why nothing needed this until the groups arrived.
    ///
    /// Whatever is already chosen stays in the list even if it falls outside
    /// the season: hiding it would render a saved value as unassigned and lose
    /// it on the next save.
    ReferenceSet? optionsFor(ModuleField field) {
      final target = sets
          .where((s) => s.id == field.referenceSetId)
          .firstOrNull;
      if (target == null || !target.isSeasonScoped) return target;
      final visible = state.visibleItems(target.id);
      final chosen = _data[field.key];
      if (chosen != null && !visible.any((i) => i.id == chosen)) {
        final kept = target.items.where((i) => i.id == chosen).firstOrNull;
        if (kept != null) return target.copyWith(items: [kept, ...visible]);
      }
      return target.copyWith(items: visible);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.set.name.of(context),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _ar,
                  autofocus: widget.item == null,
                  decoration: InputDecoration(
                    labelText: '${l.referenceItemName} *',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _en,
                  decoration: InputDecoration(
                    labelText: l.referenceItemNameEn,
                    helperText: l.commonOptional,
                  ),
                ),
                for (final field in widget.set.fields) ...[
                  const SizedBox(height: AppSpacing.md),
                  ModuleFieldInput(
                    field: field,
                    value: _data[field.key],
                    referenceSet: optionsFor(field),
                    onChanged: (v) => _setValue(field.key, v),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : Text(l.commonSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
