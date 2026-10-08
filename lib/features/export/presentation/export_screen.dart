import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/share/save_to_device.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/session_cubit.dart';
import '../application/export_cubit.dart';
import '../data/export_runner.dart';
import '../domain/export_dataset.dart';

/// Taking data out of the app: what, which parts of it, and in what shape.
///
/// Three questions in that order, and the middle one is the reason this screen
/// exists rather than an export button on each list. What a person wants out of
/// the employees is almost never all forty of their fields — it is the name,
/// the trade and the telephone, for one particular purpose — and a system that
/// exports everything makes him delete columns in Excel, which is where files
/// get quietly wrong.
class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionCubit>().state;
    return BlocProvider(
      create: (_) => ExportCubit(
        isAdmin: session.profile?.isAdmin ?? false,
        permissions: session.permissions,
      ),
      child: const _ExportView(),
    );
  }
}

class _ExportView extends StatelessWidget {
  const _ExportView();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      appBar: GlassAppBar(title: Text(l.exportTitle)),
      body: BlocConsumer<ExportCubit, ExportState>(
        listenWhen: (a, b) =>
            a.error != b.error ||
            a.lastRowCount != b.lastRowCount ||
            a.lastRecordCount != b.lastRecordCount ||
            a.savedPath != b.savedPath,
        listener: (context, state) {
          final messenger = ScaffoldMessenger.of(context);
          if (state.error != null) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    state.error == 'export_save_failed'
                        ? l.exportSaveFailed
                        : friendlyError(context, state.error),
                  ),
                ),
              );
            return;
          }
          final rows = state.lastRowCount;
          if (rows == null) return;

          final path = state.savedPath;
          final records = state.lastRecordCount;
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  // "Exported 0 rows" is the single most useful sentence this
                  // screen produces: it almost always means an option is on the
                  // wrong answer, and without it the person emails an empty
                  // sheet. It outranks saying where the file went — a person
                  // told where to find an empty file goes and finds one.
                  rows == 0
                      ? l.exportNothingMatched
                      : (path != null && path.isNotEmpty)
                      ? l.exportSavedTo(path)
                      // Records where the export carried records: one whole
                      // operational file is thirty-odd lines across five
                      // blocks, and «صُدِّر 34 سطراً» says nothing about
                      // whether he got the file he asked for.
                      : records != null
                      ? l.exportDoneRecords(records)
                      : l.exportDoneRows(rows),
                ),
              ),
            );
        },
        builder: (context, state) {
          if (state.datasets.isEmpty) {
            return EmptyState(
              icon: AppIcons.upload,
              title: l.exportNothingAvailable,
              message: l.exportNothingAvailableHint,
            );
          }

          // A form of choices rather than a reading column, so it stops well
          // short of a monitor's width; and its bottom padding comes from
          // `scrollPadding`, which is what keeps the export button above the
          // Android 15 gesture bar instead of behind it.
          return ResponsivePage(
            width: PageWidth.form,
            builder: (context, size) => SinglePaneLayout(
              gutter: size.gutter,
              children: [
                SectionHeader(l.exportWhat),
                _DatasetPicker(state: state),
                // Everything below step one is disclosed by step one, which is
                // right — the columns of a dataset nobody has named cannot be
                // drawn — and it left the screen with a heading, a row of chips
                // and then nothing at all: a page that reads as broken rather
                // than as waiting. So the space says what it is waiting for.
                if (state.dataset == null)
                  const _AwaitingDataset()
                else ...[
                  for (final option in state.dataset!.options)
                    _OptionPicker(option: option, state: state),
                  const SizedBox(height: AppSpacing.md),
                  // A record dataset offers no columns — it hands over the
                  // whole record — so there is no checklist to draw. The space
                  // says so rather than closing over silently: a person who has
                  // exported the employees knows this step exists, and its
                  // absence would read as a screen that failed to load.
                  if (state.columns.isEmpty) ...[
                    SectionHeader(l.exportWholeRecord),
                    _WholeRecordNote(state: state),
                  ] else ...[
                    SectionHeader(
                      l.exportWhichColumns,
                      trailing: _ColumnActions(state: state),
                    ),
                    _ColumnPicker(state: state),
                    _SensitiveNotice(state: state),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  SectionHeader(l.exportFormat),
                  _FormatPicker(state: state),
                  const SizedBox(height: AppSpacing.lg),
                  _RunButton(state: state),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// What stands in the space the rest of the form will fill.
///
/// A well rather than a pane — [GlassCard.subtle] is the recessed fill, and a
/// recess is what says "something goes here" instead of "here is a thing". It
/// carries no control and takes no tap: the only thing to press is already
/// above it, and a second button here would be a second answer to a question
/// that has one.
///
/// It says what is coming rather than only that something is missing. «اختر
/// جدولاً» alone would restate the heading four centimetres above it; the line
/// under it — columns, then a format, then the two buttons — is the shape of
/// the whole errand, which is worth knowing before starting it.
class _AwaitingDataset extends StatelessWidget {
  const _AwaitingDataset();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: GlassCard(
        subtle: true,
        shadow: false,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          children: [
            Icon(AppIcons.file, size: 34, color: muted.withValues(alpha: 0.55)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l.exportPickFirst,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.exportPickFirstHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: muted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What stands where the column checklist would be, for a dataset that has no
/// columns to offer.
///
/// The heading above it says «يُصدَّر كاملاً» and this says what "كاملاً"
/// covers. Both are needed: a person who has exported the employees has ticked
/// columns before and will look for them here, and a step that simply vanished
/// would read as a screen that half-loaded rather than as a deliberate answer.
class _WholeRecordNote extends StatelessWidget {
  const _WholeRecordNote({required this.state});
  final ExportState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The same loader the checklist shows, for the same reason: the options
    // above are being resolved and the form below them is not settled yet.
    if (state.status == ExportStatus.preparing) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: AppLoader(),
      );
    }

    return GlassCard(
      subtle: true,
      shadow: false,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            AppIcons.file,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              context.l10n.exportWholeRecordHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DatasetPicker extends StatelessWidget {
  const _DatasetPicker({required this.state});
  final ExportState state;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final dataset in state.datasets)
          ChoiceChip(
            label: Text(dataset.name.inLanguage(language)),
            selected: state.dataset?.id == dataset.id,
            onSelected: (_) =>
                context.read<ExportCubit>().selectDataset(dataset),
          ),
      ],
    );
  }
}

class _OptionPicker extends StatelessWidget {
  const _OptionPicker({required this.option, required this.state});

  final ExportOption option;
  final ExportState state;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final choices = state.choices[option.key] ?? const <ExportChoice>[];
    final value = state.options[option.key];

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: DropdownButtonFormField<String>(
        initialValue: choices.any((c) => c.id == value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: option.label.inLanguage(language),
          // An optional one says so, because "الموسم" with nothing chosen is
          // read as "not chosen yet" rather than as "every season".
          helperText: option.required ? null : context.l10n.exportOptionAny,
        ),
        items: [
          for (final choice in choices)
            DropdownMenuItem(
              value: choice.id,
              child: Text(
                choice.label.inLanguage(language),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (picked) {
          if (picked == null) return;
          context.read<ExportCubit>().setOption(option.key, picked);
        },
      ),
    );
  }
}

class _ColumnActions extends StatelessWidget {
  const _ColumnActions({required this.state});
  final ExportState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<ExportCubit>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: cubit.selectDefaultColumns,
          child: Text(l.exportColumnsDefault),
        ),
        TextButton(
          onPressed: cubit.selectAllColumns,
          child: Text(l.exportColumnsAll),
        ),
      ],
    );
  }
}

class _ColumnPicker extends StatelessWidget {
  const _ColumnPicker({required this.state});
  final ExportState state;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final l = context.l10n;

    if (state.status == ExportStatus.preparing) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: AppLoader(),
      );
    }

    return GlassCard(
      child: Column(
        children: [
          for (final column in state.columns)
            CheckboxListTile(
              dense: true,
              value: state.selected.contains(column.key),
              title: Text(column.label.inLanguage(language)),
              onChanged: (_) =>
                  context.read<ExportCubit>().toggleColumn(column.key),
            ),
          if (state.selected.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                l.exportPickAtLeastOne,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

/// A word about a column that leaves the screen's protections behind it.
///
/// Under the checklist rather than beside the export button, because it is
/// caused by a tick and unticking it should take it away — a warning that
/// outlives what caused it is a warning people stop reading. And it appears
/// only when something is ticked that earns it: see [ExportColumn.isSensitive],
/// which is deliberately set on one column in the whole app.
///
/// It does not block, and there is no second confirmation on the button. The
/// person is entitled to the column — he would not be on this screen otherwise
/// — and the thing he may not have in mind is not the permission but the FILE:
/// it outlives the screen, and it carries his name out with it.
class _SensitiveNotice extends StatelessWidget {
  const _SensitiveNotice({required this.state});
  final ExportState state;

  @override
  Widget build(BuildContext context) {
    final ticked = state.sensitiveColumns;
    if (ticked.isEmpty) return const SizedBox.shrink();

    final language = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final tint = theme.colorScheme.tertiary;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: GlassCard(
        tint: tint,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(AppIcons.pending, size: 18, color: tint),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                // Named, not listed: one column carries this mark, and a
                // sentence that says WHICH one is a sentence a person can act
                // on by finding it in the list above.
                context.l10n.exportSensitiveNotice(
                  ticked.first.label.inLanguage(language),
                ),
                style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatPicker extends StatelessWidget {
  const _FormatPicker({required this.state});
  final ExportState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SegmentedButton<ExportFormat>(
      segments: [
        ButtonSegment(
          value: ExportFormat.csv,
          label: Text(l.exportFormatCsv),
          icon: const Icon(AppIcons.file, size: 16),
        ),
        ButtonSegment(
          value: ExportFormat.pdf,
          label: Text(l.exportFormatPdf),
          icon: const Icon(AppIcons.file, size: 16),
        ),
      ],
      selected: {state.format},
      onSelectionChanged: (picked) =>
          context.read<ExportCubit>().setFormat(picked.first),
    );
  }
}

/// The two things a finished file can be for.
///
/// Saving is the filled one and sharing is the outlined one, and the ranking is
/// not arbitrary: a person who came to a page called «تصدير البيانات» came to
/// GET a file. Sending it on is what happens to some of them afterwards.
///
/// The screen used to have one button and it shared, which meant the commonest
/// intention — keep this — was reached by opening a sheet full of contacts and
/// finding «حفظ في الملفات» among them. Two buttons, two intentions, and
/// neither pretends to be the other.
class _RunButton extends StatelessWidget {
  const _RunButton({required this.state});
  final ExportState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final running = state.status == ExportStatus.running;

    void run(ExportDelivery delivery) => context.read<ExportCubit>().run(
      l: l,
      languageCode: Localizations.localeOf(context).languageCode,
      subtitle: l.exportGeneratedBy,
      pageLabel: l.exportPage,
      delivery: delivery,
    );

    final spinner = running
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : null;

    return Row(
      children: [
        if (isSaveToDeviceSupported) ...[
          Expanded(
            child: FilledButton.icon(
              onPressed: state.canRun ? () => run(ExportDelivery.save) : null,
              icon: spinner ?? const Icon(AppIcons.download),
              label: Text(running ? l.exportRunning : l.exportSave),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: isSaveToDeviceSupported
              ? OutlinedButton.icon(
                  onPressed: state.canRun
                      ? () => run(ExportDelivery.share)
                      : null,
                  icon: const Icon(AppIcons.send),
                  label: Text(l.exportShare),
                )
              // The browser has no save dialog this app can trust — see
              // [isSaveToDeviceSupported] — so there it stays one button, and
              // the one it keeps is the one that still works.
              : FilledButton.icon(
                  onPressed: state.canRun
                      ? () => run(ExportDelivery.share)
                      : null,
                  icon: spinner ?? const Icon(AppIcons.upload),
                  label: Text(running ? l.exportRunning : l.exportShare),
                ),
        ),
      ],
    );
  }
}
