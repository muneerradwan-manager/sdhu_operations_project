import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/glass.dart';
import '../../application/report_editor_cubit.dart';
import '../../domain/report_block.dart';
import 'table_cell_input.dart';
import 'tag_list_field.dart';

/// Writing a general report.
///
/// A typed report is FILLED IN — its type declares the columns and the form
/// asks for them. This one is written, so the form's job is to make plain what
/// it can be made of: a heading, prose, a numbered list, a table, a link, a code
/// to scan. The row of "add" buttons is that statement — somebody who does not
/// know a report may carry a QR code finds out by looking at the form, which is
/// the only place they were ever going to look.
class ReportBlocksEditor extends StatelessWidget {
  const ReportBlocksEditor({
    super.key,
    required this.state,
    required this.cubit,
  });

  final ReportEditorState state;
  final ReportEditorCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.reportContentSection,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l.reportContentHint,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Every kind, always offered. A menu that hides the rare ones behind
        // "more" is a menu that decides for the writer what their notice needs.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final kind in ReportBlockKind.values)
              ActionChip(
                avatar: Icon(_iconFor(kind), size: 16),
                label: Text(_labelFor(context, kind)),
                visualDensity: VisualDensity.compact,
                onPressed: () => cubit.addBlock(kind),
              ),
          ],
        ),
        if (state.blocks.isEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(l.reportNoBlocks),
          ),
        ],
        for (var i = 0; i < state.blocks.length; i++) ...[
          const SizedBox(height: AppSpacing.sm),
          _BlockCard(
            key: ValueKey('block_$i'),
            index: i,
            block: state.blocks[i],
            total: state.blocks.length,
            cubit: cubit,
          ),
        ],
      ],
    );
  }
}

IconData _iconFor(ReportBlockKind kind) => switch (kind) {
  ReportBlockKind.heading => AppIcons.document,
  ReportBlockKind.subheading => AppIcons.document,
  ReportBlockKind.paragraph => AppIcons.file,
  ReportBlockKind.bullets => AppIcons.tasks,
  ReportBlockKind.numbers => AppIcons.tasks,
  ReportBlockKind.table => AppIcons.referenceData,
  ReportBlockKind.url => AppIcons.link,
  ReportBlockKind.qr => AppIcons.view,
  ReportBlockKind.note => AppIcons.pending,
  ReportBlockKind.divider => AppIcons.modules,
};

/// One typed column: its heading, what its cells are, and the means to move it.
///
/// Retyping is the one edit here that can invalidate data — `text → reference`
/// leaves a cell holding a name that is not an id — so the kind dropdown asks
/// the cubit for the loss count FIRST and puts a number in front of the person
/// before anything is emptied. Nothing else in this app empties a column
/// silently, and this must not be the first.
class _ColumnCard extends StatelessWidget {
  const _ColumnCard({
    super.key,
    required this.blockIndex,
    required this.column,
    required this.isFirst,
    required this.isLast,
    required this.cubit,
  });

  final int blockIndex;
  final TableColumn column;
  final bool isFirst;
  final bool isLast;
  final ReportEditorCubit cubit;

  Future<void> _retype(
    BuildContext context,
    TableColumnKind kind, {
    String? setCode,
  }) async {
    final l = context.l10n;
    final lost = cubit.retypeLossCount(
      blockIndex,
      column.id,
      kind,
      setCode: setCode,
    );
    if (lost > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l.blockColumnKind),
          content: Text(l.blockColumnRetypeWarning(lost)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l.commonCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l.commonDelete),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    cubit.retypeBlockColumn(blockIndex, column.id, kind, setCode: setCode);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final sets = cubit.state.referenceSets;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: GlassCard(
        subtle: true,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    // Keyed by the column's IDENTITY, so a reorder does not
                    // leave this controller's text under the next heading.
                    key: ValueKey('label_${column.id}'),
                    initialValue: column.label,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: l.blockColumnLabel,
                    ),
                    onChanged: (v) =>
                        cubit.renameBlockColumn(blockIndex, column.id, v),
                  ),
                ),
                // Two taps, not a drag: a drag inside a scrolling form fights
                // the scroll.
                IconButton(
                  tooltip: l.blockMoveUp,
                  visualDensity: VisualDensity.compact,
                  onPressed: isFirst
                      ? null
                      : () => cubit.moveBlockColumn(blockIndex, column.id, -1),
                  icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                ),
                IconButton(
                  tooltip: l.blockMoveDown,
                  visualDensity: VisualDensity.compact,
                  onPressed: isLast
                      ? null
                      : () => cubit.moveBlockColumn(blockIndex, column.id, 1),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                ),
                IconButton(
                  tooltip: l.commonDelete,
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      cubit.removeBlockColumn(blockIndex, column.id),
                  icon: Icon(AppIcons.delete, size: 16, color: scheme.error),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<TableColumnKind>(
                    initialValue: column.kind,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: l.blockColumnKind,
                    ),
                    items: [
                      for (final kind in TableColumnKind.values)
                        DropdownMenuItem(
                          value: kind,
                          child: Text(_kindLabel(l, kind)),
                        ),
                    ],
                    onChanged: (kind) {
                      if (kind == null || kind == column.kind) return;
                      // A reference needs its list before it means anything;
                      // the set dropdown beside this finishes the job.
                      _retype(
                        context,
                        kind,
                        setCode: kind == TableColumnKind.reference
                            ? column.setCode ?? sets.firstOrNull?.code
                            : null,
                      );
                    },
                  ),
                ),
                if (column.kind == TableColumnKind.reference) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: column.setCode,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: l.blockColumnSet,
                      ),
                      items: [
                        for (final set in sets)
                          DropdownMenuItem(
                            value: set.code,
                            child: Text(set.name.of(context)),
                          ),
                      ],
                      onChanged: (code) {
                        if (code == null) return;
                        _retype(
                          context,
                          TableColumnKind.reference,
                          setCode: code,
                        );
                      },
                    ),
                  ),
                ],
                // Merging equal list-cells downward is meaningless, so the
                // chip hides for tags rather than offering a dead switch.
                if (column.kind != TableColumnKind.tags) ...[
                  const SizedBox(width: AppSpacing.sm),
                  FilterChip(
                    label: Text(l.blockColumnSpan),
                    selected: column.span,
                    onSelected: (_) =>
                        cubit.toggleBlockColumnSpan(blockIndex, column.id),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _kindLabel(AppLocalizations l, TableColumnKind kind) => switch (kind) {
  TableColumnKind.text => l.blockColumnKindText,
  TableColumnKind.number => l.blockColumnKindNumber,
  TableColumnKind.date => l.blockColumnKindDate,
  TableColumnKind.time => l.blockColumnKindTime,
  TableColumnKind.timeRange => l.blockColumnKindTimeRange,
  TableColumnKind.reference => l.blockColumnKindReference,
  TableColumnKind.tags => l.blockColumnKindTags,
};

String _labelFor(BuildContext context, ReportBlockKind kind) {
  final l = context.l10n;
  return switch (kind) {
    ReportBlockKind.heading => l.blockHeading,
    ReportBlockKind.subheading => l.blockSubheading,
    ReportBlockKind.paragraph => l.blockParagraph,
    ReportBlockKind.bullets => l.blockBullets,
    ReportBlockKind.numbers => l.blockNumbers,
    ReportBlockKind.table => l.blockTable,
    ReportBlockKind.url => l.blockUrl,
    ReportBlockKind.qr => l.blockQr,
    ReportBlockKind.note => l.blockNote,
    ReportBlockKind.divider => l.blockDivider,
  };
}

/// One block, with the fields its kind needs and the means to move it.
class _BlockCard extends StatelessWidget {
  const _BlockCard({
    super.key,
    required this.index,
    required this.block,
    required this.total,
    required this.cubit,
  });

  final int index;
  final DraftBlock block;
  final int total;
  final ReportEditorCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_iconFor(block.kind), size: 18, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _labelFor(context, block.kind),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              // The order is what gets rewritten most, so it is two taps and
              // not a drag: a drag inside a scrolling form fights the scroll.
              IconButton(
                tooltip: l.blockMoveUp,
                visualDensity: VisualDensity.compact,
                onPressed: index == 0 ? null : () => cubit.moveBlock(index, -1),
                icon: const Icon(Icons.keyboard_arrow_up, size: 20),
              ),
              IconButton(
                tooltip: l.blockMoveDown,
                visualDensity: VisualDensity.compact,
                onPressed: index == total - 1
                    ? null
                    : () => cubit.moveBlock(index, 1),
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              ),
              IconButton(
                tooltip: l.commonDelete,
                visualDensity: VisualDensity.compact,
                onPressed: () => cubit.removeBlock(index),
                icon: Icon(AppIcons.delete, size: 18, color: scheme.error),
              ),
            ],
          ),
          ..._fields(context),
        ],
      ),
    );
  }

  /// One row's inputs, across the EFFECTIVE columns, each asked for the way
  /// its column says.
  ///
  /// The generated columns are resolved through the cubit's own expansion —
  /// the same resolution the reader uses — so the editor and the page agree
  /// about which heading a cell sits under. A generated column's field is
  /// labelled with its entry's name (تكتل الكعبة, not "عمود ١٦") and keyed by
  /// the entry's id; the typed ones are keyed by their COLUMN id, so moving a
  /// column does not strand a controller's text under the wrong heading.
  List<Widget> _rowFields(BuildContext context, int r) {
    final block = this.block;
    final expansion = cubit.state.expansionOf(block);
    final effective = block.effectiveTableColumns(expansion);

    return [
      for (var e = 0; e < effective.length; e++) ...[
        const SizedBox(height: AppSpacing.xs),
        TableCellInput(
          key: ValueKey('b${index}_r${r}_${effective[e].id}'),
          column: effective[e],
          value: e < block.rows[r].length ? block.rows[r][e] : '',
          set: effective[e].setCode == null
              ? null
              : cubit.state.referenceSets
                    .where((s) => s.code == effective[e].setCode)
                    .firstOrNull,
          seasonId: cubit.state.seasonId,
          onChanged: (v) => cubit.setBlockCell(index, r, e, v),
        ),
      ],
    ];
  }

  List<Widget> _fields(BuildContext context) {
    final l = context.l10n;

    switch (block.kind) {
      // Nothing to fill in: a rule is a rule.
      case ReportBlockKind.divider:
        return const [];

      case ReportBlockKind.heading:
      case ReportBlockKind.subheading:
      case ReportBlockKind.paragraph:
      case ReportBlockKind.note:
        final long =
            block.kind == ReportBlockKind.paragraph ||
            block.kind == ReportBlockKind.note;
        return [
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: block.text,
            maxLines: long ? 5 : 1,
            decoration: InputDecoration(
              isDense: true,
              labelText: long ? l.blockTextLong : l.blockTextShort,
            ),
            onChanged: (v) => cubit.setBlockValue(index, 'text', v),
          ),
        ];

      case ReportBlockKind.bullets:
      case ReportBlockKind.numbers:
        return [
          const SizedBox(height: AppSpacing.sm),
          TagListField(
            label: l.blockItems,
            items: block.items,
            hint: l.blockAddItem,
            onChanged: (v) => cubit.setBlockValue(index, 'items', v),
          ),
        ];

      case ReportBlockKind.url:
        return [
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: block.data['url']?.toString() ?? '',
            keyboardType: TextInputType.url,
            decoration: InputDecoration(isDense: true, labelText: l.blockUrl),
            onChanged: (v) => cubit.setBlockValue(index, 'url', v),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: block.data['label']?.toString() ?? '',
            decoration: InputDecoration(
              isDense: true,
              labelText: l.blockLabel,
              helperText: l.commonOptional,
            ),
            onChanged: (v) => cubit.setBlockValue(index, 'label', v),
          ),
        ];

      case ReportBlockKind.qr:
        return [
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: block.data['value']?.toString() ?? '',
            decoration: InputDecoration(
              isDense: true,
              labelText: l.blockQrValue,
              helperText: l.blockQrHint,
            ),
            onChanged: (v) => cubit.setBlockValue(index, 'value', v),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: block.data['label']?.toString() ?? '',
            decoration: InputDecoration(
              isDense: true,
              labelText: l.blockLabel,
              helperText: l.commonOptional,
            ),
            onChanged: (v) => cubit.setBlockValue(index, 'label', v),
          ),
        ];

      case ReportBlockKind.table:
        final columns = block.tableColumns;
        return [
          const SizedBox(height: AppSpacing.sm),
          // One card per column: its heading, what its cells ARE, and — for a
          // choice — which list they come from. The columns used to be a list
          // of bare strings and every cell a text box; giving the column a
          // kind is what lets the row below offer a date picker for a date
          // and this season's clusters for a تكتل, instead of a box to
          // misspell either into.
          for (final column in columns)
            _ColumnCard(
              key: ValueKey('col_${index}_${column.id}'),
              blockIndex: index,
              column: column,
              isFirst: column.id == columns.first.id,
              isLast: column.id == columns.last.id,
              cubit: cubit,
            ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => cubit.addBlockColumn(index),
              icon: const Icon(AppIcons.add, size: 18),
              label: Text(l.blockAddColumn),
            ),
          ),
          // NOTE deliberately absent: the "a column per entry of a list"
          // chooser. The EXPANSION mechanism stays — توزيع الوجبات, converted
          // by 0103, grows a column per تكتل through it, and the row fields
          // below render and edit those generated cells — but offering it on
          // every new table confused more than it served. A block that carries
          // an expansion keeps working; nothing in this editor creates one.
          if (block.columns.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                l.blockTableNeedsColumns,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            for (var r = 0; r < block.rows.length; r++) ...[
              const SizedBox(height: AppSpacing.sm),
              // One field per column, labelled with that column. Typed as a
              // single line with separators it was impossible to tell which
              // cell you were in, and one missing separator shifted the rest.
              GlassCard(
                subtle: true,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.reportRowNumber(r + 1),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        IconButton(
                          tooltip: l.commonDelete,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => cubit.removeBlockRow(index, r),
                          icon: Icon(
                            AppIcons.delete,
                            size: 16,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                    // Every column the table HAS — the typed ones AND the ones
                    // its expansion generates, each labelled by the entry it
                    // stands for and addressed at its EFFECTIVE index.
                    //
                    // Both halves of that sentence fix a live corruption. The
                    // loop used to cover the typed columns only, so a
                    // distribution table's thirteen cluster cells were never
                    // rendered and could not be edited at all. And it handed
                    // `setBlockCell` its typed loop index while the rows store
                    // effective positions — so the field labelled المجموع read
                    // and OVERWROTE the first تكتل's count, in both directions,
                    // silently.
                    ..._rowFields(context, r),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => cubit.addBlockRow(index),
                icon: const Icon(AppIcons.add, size: 18),
                label: Text(l.reportAddRow),
              ),
            ),
          ],
        ];
    }
  }
}
