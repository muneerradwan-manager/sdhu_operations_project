import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';

/// A list of short things, added one at a time.
///
/// Everywhere this app asks for a list of small items — the contents of a meal,
/// the points of a notice, the columns of a table — the honest form is the same
/// one: type it, press enter, see it become a chip you can remove. A textarea
/// makes the list one blob whose items are separated by whatever the typist
/// happened to press, and nobody can tell an empty line from a deliberate one.
class TagListField extends StatefulWidget {
  const TagListField({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
    this.hint,
    this.helper,
  });

  final String label;
  final List<String> items;
  final ValueChanged<List<String>> onChanged;

  /// What the entry box says before anything is typed.
  final String? hint;
  final String? helper;

  @override
  State<TagListField> createState() => _TagListFieldState();
}

class _TagListFieldState extends State<TagListField> {
  final _entry = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _entry.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final v = _entry.text.trim();
    if (v.isEmpty) return;
    // A duplicate is a slip of the finger, not an instruction: a meal does not
    // contain خبز twice. Cleared and ignored rather than refused with a noise.
    if (!widget.items.contains(v)) {
      widget.onChanged([...widget.items, v]);
    }
    _entry.clear();
    // Focus stays put, because a list of nine is typed in one go.
    _focus.requestFocus();
  }

  void _remove(String tag) =>
      widget.onChanged(widget.items.where((t) => t != tag).toList());

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final tag in widget.items)
                    InputChip(
                      label: Text(tag),
                      visualDensity: VisualDensity.compact,
                      onDeleted: () => _remove(tag),
                    ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _entry,
                  focusNode: _focus,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.hint ?? l.reportAddTag,
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              IconButton(icon: const Icon(AppIcons.add), onPressed: _add),
            ],
          ),
        ],
      ),
    );
  }
}
