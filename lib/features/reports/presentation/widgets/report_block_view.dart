import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/glass.dart';
import '../../../modules/domain/module_type.dart';
import '../../domain/report_block.dart';
import '../../domain/table_cells.dart';
import 'report_field_card.dart';
import 'report_table.dart';

/// One block of a written report, drawn as what it is.
///
/// Deliberately NOT all wrapped in cards. A notice reads as a document — its
/// headings sit on the page and its paragraphs run under them — and putting
/// every line in glass turns a page of prose into a stack of tiles. Only the
/// things that are OBJECTS rather than text get a card: a table, a link, a
/// code, and a note, which is set apart because being set apart is what makes
/// it a note.
class ReportBlockView extends StatelessWidget {
  const ReportBlockView({
    super.key,
    required this.block,
    this.expandedColumns = const [],
    this.tableText = const TableText(),
  });

  final ReportBlock block;

  /// What the block's `expand` list resolved to, in this document's season.
  ///
  /// Passed in rather than looked up. A block knows the CODE of the list its
  /// extra columns come from — `clusters` — and resolving that to this
  /// season's تكتلات needs the master data, which the screen already has and a
  /// leaf widget has no business fetching. Empty for a table that does not
  /// expand, which is every ordinary one.
  final List<String> expandedColumns;

  /// How a stored cell becomes the text a reader sees — the reference-name
  /// resolver, the time-range sentence, the date format. Defaulted to identity
  /// so a widget test can pump a block without master data behind it.
  final TableText tableText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    switch (block.kind) {
      case ReportBlockKind.heading:
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(block.text, style: text.titleLarge),
        );

      case ReportBlockKind.subheading:
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            block.text,
            style: text.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        );

      case ReportBlockKind.paragraph:
        return Align(
          alignment: AlignmentDirectional.centerStart,
          // Prose, so it gets prose's line height rather than a label's.
          child: Text(block.text, style: text.bodyLarge?.copyWith(height: 1.6)),
        );

      case ReportBlockKind.note:
        return GlassCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          tint: scheme.secondary,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcons.pending, size: 18, color: scheme.secondary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  block.text,
                  style: text.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        );

      case ReportBlockKind.bullets:
      case ReportBlockKind.numbers:
        final numbered = block.kind == ReportBlockKind.numbers;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < block.items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        numbered ? '${i + 1}.' : '•',
                        style: text.bodyLarge?.copyWith(color: scheme.primary),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        block.items[i],
                        style: text.bodyLarge?.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );

      case ReportBlockKind.divider:
        return Divider(
          height: AppSpacing.lg,
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        );

      case ReportBlockKind.url:
        return ReportFieldCard(
          label: block.label.isEmpty ? block.url : block.label,
          value: block.url,
          kind: ModuleFieldKind.url,
        );

      case ReportBlockKind.qr:
        return ReportFieldCard(
          label: block.label.isEmpty
              ? context.l10n.reportScanCode
              : block.label,
          value: block.value,
          kind: ModuleFieldKind.qr,
        );

      case ReportBlockKind.table:
        return _WrittenTable(
          block: block,
          expanded: expandedColumns,
          text: tableText,
        );
    }
  }
}

/// A table a notice carries its own columns for.
///
/// The columns come from the BLOCK rather than from a type, which is the whole
/// difference between a written report and a typed one. Everything after that —
/// whether there is room for a grid, and what to do when there is not — is the
/// same question [ReportTable] answers for both.
///
/// Since 0102 a block can do the two things only a report TYPE could before:
/// grow a column per entry of a master-data list, and print a repeated value
/// once against the rows it covers. Those two were the whole reason توزيع
/// الوجبات and مواعيد الوجبات needed types of their own.
class _WrittenTable extends StatelessWidget {
  const _WrittenTable({
    required this.block,
    required this.expanded,
    required this.text,
  });

  final ReportBlock block;
  final List<String> expanded;
  final TableText text;

  @override
  Widget build(BuildContext context) {
    // Resolution happens HERE, before ReportTable ever sees the rows, and the
    // placement is load-bearing. ReportTable MEASURES its text to choose
    // between the grid, the side-scroller and the stacked cards — and a
    // 36-character uuid measures roughly eight times wider than the name it
    // stands for, so an unresolved reference cell would not merely read badly,
    // it would push the whole table into the wrong layout.
    final typed = block.tableColumns;
    final at = block.expandAt ?? typed.length;
    final effective = <TableColumn>[
      ...typed.take(at),
      for (var i = 0; i < expanded.length; i++)
        TableColumn(id: 'x$i', label: expanded[i], kind: block.expandKind),
      ...typed.skip(at),
    ];

    return ReportTable(
      columns: [for (final c in effective) c.label],
      rows: [
        for (final row in block.rows)
          [
            for (var i = 0; i < effective.length; i++)
              drawCell(effective[i], i < row.length ? row[i] : '', text),
          ],
      ],
      // Only the TYPED columns can span. A generated one holds a count per
      // تكتل, and two clusters that happen to have the same number are not one
      // merged cell — they are a coincidence this would hide.
      //
      // Mapped through `effectiveIndexOf`, because the marks were ticked
      // against the typed columns and the table is drawn against the spliced
      // ones: an unmapped index would merge a cluster's count instead of the
      // date.
      spans: {
        for (var i = 0; i < typed.length; i++)
          if (typed[i].span) block.effectiveIndexOf(i, expanded.length),
      },
      tagged: {
        for (var i = 0; i < effective.length; i++)
          if (effective[i].kind == TableColumnKind.tags) i,
      },
    );
  }
}
