import 'package:equatable/equatable.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../../core/share/save_to_device.dart';
import '../../../core/share/shareable.dart';
import '../../../l10n/app_localizations.dart';
import '../data/export_catalog.dart';
import '../data/export_runner.dart';
import '../domain/export_dataset.dart';

enum ExportStatus { choosing, preparing, running, error }

/// Where a finished export goes.
///
/// Two intentions, not two buttons for one: [share] hands the file to somebody
/// else, [save] puts it where its author can find it again. Which one is in
/// flight is a parameter rather than state, because it is decided at the moment
/// of pressing and is finished by the time anything is emitted.
enum ExportDelivery { share, save }

class ExportState extends Equatable {
  const ExportState({
    this.datasets = const [],
    this.dataset,
    this.choices = const {},
    this.options = const {},
    this.columns = const [],
    this.selected = const {},
    this.format = ExportFormat.csv,
    this.status = ExportStatus.choosing,
    this.error,
    this.lastRowCount,
    this.lastRecordCount,
    this.savedPath,
  });

  final List<ExportDataset> datasets;
  final ExportDataset? dataset;

  /// The answers each option offers, once fetched.
  final Map<String, List<ExportChoice>> choices;

  /// What has been answered.
  final Map<String, String> options;

  /// The dataset's own columns, plus any that only exist once an option was
  /// chosen.
  final List<ExportColumn> columns;
  final Set<String> selected;

  final ExportFormat format;
  final ExportStatus status;
  final String? error;

  /// How many rows the last export carried. Shown afterwards, because a file
  /// with no rows and a file with four hundred look the same in a folder, and
  /// the empty one usually means an option was left on the wrong answer.
  final int? lastRowCount;

  /// Where the last export landed, when it was SAVED rather than shared.
  ///
  /// Its own field rather than a flag beside [lastRowCount], because the two
  /// answer different questions and the screen prints both: how many rows went
  /// into the file, and where the file went. Null after a share — there is no
  /// answer to give, the sheet took it from here — and null on Android even
  /// after a save, which hands back a document URI rather than a path.
  final String? savedPath;

  /// How many whole records the last export carried, for the datasets that
  /// carry records. Null after an ordinary one — see [ExportFile.recordCount].
  final int? lastRecordCount;

  /// The ticked columns that are worth a word of warning, if any.
  ///
  /// Read off the ticking rather than remembered, so that unticking the column
  /// takes the notice away with it — a warning that outlived what caused it is
  /// a warning people learn to ignore.
  List<ExportColumn> get sensitiveColumns => [
    for (final column in columns)
      if (column.isSensitive && selected.contains(column.key)) column,
  ];

  /// Whether there is anything to export yet: a dataset, at least one column,
  /// and an answer to every option that insists on one.
  ///
  /// "At least one column" only where there ARE columns. A record dataset has
  /// none by construction — it hands over the whole record — and a ticking rule
  /// applied to it would leave its export button permanently dead.
  bool get canRun {
    final target = dataset;
    if (target == null) return false;
    if (columns.isNotEmpty && selected.isEmpty) return false;
    for (final option in target.options) {
      if (option.required && (options[option.key] ?? '').isEmpty) return false;
    }
    return status != ExportStatus.running && status != ExportStatus.preparing;
  }

  ExportState copyWith({
    List<ExportDataset>? datasets,
    ExportDataset? dataset,
    Map<String, List<ExportChoice>>? choices,
    Map<String, String>? options,
    List<ExportColumn>? columns,
    Set<String>? selected,
    ExportFormat? format,
    ExportStatus? status,
    String? error,
    bool clearError = false,
    int? lastRowCount,
    int? lastRecordCount,
    bool clearRowCount = false,
    String? savedPath,
    bool clearSavedPath = false,
  }) => ExportState(
    datasets: datasets ?? this.datasets,
    dataset: dataset ?? this.dataset,
    choices: choices ?? this.choices,
    options: options ?? this.options,
    columns: columns ?? this.columns,
    selected: selected ?? this.selected,
    format: format ?? this.format,
    status: status ?? this.status,
    error: clearError ? null : (error ?? this.error),
    lastRowCount: clearRowCount ? null : (lastRowCount ?? this.lastRowCount),
    lastRecordCount: clearRowCount
        ? null
        : (lastRecordCount ?? this.lastRecordCount),
    savedPath: clearSavedPath ? null : (savedPath ?? this.savedPath),
  );

  @override
  List<Object?> get props => [
    datasets,
    dataset?.id,
    choices,
    options,
    [for (final column in columns) column.key],
    selected,
    format,
    status,
    error,
    lastRowCount,
    lastRecordCount,
    savedPath,
  ];
}

/// Drives the export screen: what can be exported, what of it, and in what.
class ExportCubit extends SafeCubit<ExportState> {
  ExportCubit({required bool isAdmin, required Set<String> permissions})
    : viewer = ExportViewer(isAdmin: isAdmin, permissions: permissions),
      super(
        ExportState(
          datasets: ExportCatalog.visibleTo(
            isAdmin: isAdmin,
            permissions: permissions,
          ),
        ),
      );

  /// Who is asking. Held rather than re-derived: it decides which HALF of a
  /// merged dataset is offered — the permanent staff or the season's
  /// participants — so the options need it while the form is being answered,
  /// not only when the file is built.
  final ExportViewer viewer;

  Future<void> selectDataset(ExportDataset dataset) async {
    emit(
      ExportState(
        datasets: state.datasets,
        dataset: dataset,
        columns: dataset.columns,
        selected: dataset.defaultColumns,
        format: state.format,
        status: ExportStatus.preparing,
      ),
    );

    await _resolve(dataset, const {}, dataset.defaultColumns);
  }

  Future<void> setOption(String key, String value) async {
    final dataset = state.dataset;
    if (dataset == null) return;

    emit(state.copyWith(status: ExportStatus.preparing));
    await _resolve(dataset, {...state.options, key: value}, state.selected);
  }

  /// Works out what the form now offers, and what of it is still answered.
  ///
  /// One method for opening a dataset and for changing an answer, because the
  /// two do the same work: an option's list may DEPEND on the answers above it
  /// — the operational files offered are the chosen season's, the decisions
  /// offered are the chosen scope's — so a list resolved once when the screen
  /// opened would go on offering last question's answers.
  ///
  /// Which is why the options are walked in order and each is resolved against
  /// what has been settled ABOVE it, sequentially. They cannot go out together.
  ///
  /// An answer that is no longer among its option's choices falls back to that
  /// option's opening answer rather than being cleared: choosing 1448هـ under a
  /// file that belonged to 1447 should land on «الكل» for 1448, not on an empty
  /// dropdown with the export button dead and nothing saying why.
  Future<void> _resolve(
    ExportDataset dataset,
    Map<String, String> answers,
    Set<String> selected,
  ) async {
    try {
      final choices = <String, List<ExportChoice>>{};
      final settled = <String, String>{};

      for (final option in dataset.options) {
        final list = await option.choices(settled, viewer);
        choices[option.key] = list;

        bool offered(String? id) =>
            id != null && list.any((choice) => choice.id == id);

        final wanted = answers[option.key];
        if (offered(wanted)) {
          settled[option.key] = wanted!;
        } else if (offered(option.initial)) {
          settled[option.key] = option.initial!;
        } else if (option.required && list.isNotEmpty) {
          // A question that INSISTS on an answer gets the first one on offer
          // rather than none. This is the case where a reader holds only
          // `seasons.participants_view`: «الملاك الدائم» is the opening answer
          // of «من يُصدَّر» and is not among his choices at all, and leaving it
          // unanswered would kill the export button with nothing saying why.
          settled[option.key] = list.first.id;
        }
      }

      // The extra columns depend on the answers, so they are re-resolved rather
      // than added to: changing the chosen list from the hotels to the camps
      // must take the hotels' own fields away with it, or the sheet offers
      // columns that no row has anything for.
      final extra = await dataset.extraColumns(settled);
      final columns = [...dataset.columns, ...extra];
      final live = {for (final column in columns) column.key};

      emit(
        state.copyWith(
          choices: choices,
          options: settled,
          columns: columns,
          selected: selected.where(live.contains).toSet(),
          status: ExportStatus.choosing,
          clearRowCount: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: ExportStatus.error, error: e.toString()));
    }
  }

  void toggleColumn(String key) {
    final selected = {...state.selected};
    if (!selected.remove(key)) selected.add(key);
    emit(state.copyWith(selected: selected, clearRowCount: true));
  }

  void selectAllColumns() => emit(
    state.copyWith(
      selected: {for (final column in state.columns) column.key},
      clearRowCount: true,
    ),
  );

  void selectDefaultColumns() => emit(
    state.copyWith(
      selected: state.dataset?.defaultColumns ?? const {},
      clearRowCount: true,
    ),
  );

  void setFormat(ExportFormat format) =>
      emit(state.copyWith(format: format, clearRowCount: true));

  /// The file in the shape the share sheet wants it.
  ///
  /// A real file on disk where there is a disk: that is what every native share
  /// sheet takes, and a temporary directory is exactly the right home for
  /// something whose whole life is the next few seconds.
  ///
  /// The web has no such directory — `path_provider` has no implementation
  /// there — so the bytes are handed over as they are, and the browser's own
  /// share or download takes them from memory. Written as a fallback on the
  /// failure rather than as a check on `kIsWeb`, because the thing that matters
  /// is whether a directory can be had, not which platform is asking.
  /// Moved to `core/share/shareable.dart` when the place-code card needed the
  /// same fallback; kept here as one line so the call sites below read as they
  /// did.
  Future<XFile> _asShareable(ExportFile file) => asShareable(
    file.bytes,
    name: file.name,
    mimeType: file.format.mimeType,
  );

  /// Builds the file and delivers it the way [delivery] says.
  ///
  /// One method rather than two, because everything before the last step is
  /// identical and expensive: the query, the columns, the writer. What differs
  /// is four lines at the end.
  ///
  /// The two deliveries are two different INTENTIONS and that is why both are
  /// offered. Sharing sends the file to somebody — email, WhatsApp, a drive —
  /// and saving puts it where the person can find it again. This screen used to
  /// offer only the first, on the argument that a share sheet contains «حفظ في
  /// الملفات» anywhere the platform has one. True, and still the wrong shape:
  /// it made the one act that involves nobody go through a sheet full of
  /// contacts.
  Future<void> run({
    required AppLocalizations l,
    required String languageCode,
    required String subtitle,
    required String pageLabel,
    ExportDelivery delivery = ExportDelivery.share,
  }) async {
    final dataset = state.dataset;
    if (dataset == null || !state.canRun) return;

    emit(
      state.copyWith(
        status: ExportStatus.running,
        clearError: true,
        clearRowCount: true,
        clearSavedPath: true,
      ),
    );

    try {
      final file = await ExportRunner.run(
        dataset: dataset,
        request: ExportRequest(
          columnKeys: state.selected,
          options: state.options,
          l: l,
          languageCode: languageCode,
          viewer: viewer,
        ),
        format: state.format,
        columns: state.columns,
        subtitle: subtitle,
        pageLabel: pageLabel,
      );

      if (delivery == ExportDelivery.save) {
        final result = await saveToDevice(
          file.bytes,
          suggestedName: file.name,
          label: state.format.name.toUpperCase(),
          extension: state.format.extension,
          mimeType: state.format.mimeType,
        );

        // Closing the picker is an answer, not an event. The screen goes back
        // to what it was showing and says nothing — a snack bar reporting that
        // somebody did not do the thing they decided not to do is noise.
        if (result.outcome == SaveOutcome.cancelled) {
          emit(state.copyWith(status: ExportStatus.choosing));
          return;
        }
        if (result.outcome == SaveOutcome.failed) {
          emit(
            state.copyWith(
              status: ExportStatus.error,
              error: 'export_save_failed',
            ),
          );
          return;
        }

        emit(
          state.copyWith(
            status: ExportStatus.choosing,
            lastRowCount: file.rowCount,
            lastRecordCount: file.recordCount,
            // Null on Android, which answers with a document URI rather than a
            // path anybody would recognise. The message that reads this says
            // "saved" without a where in that case, which is the truth.
            savedPath: result.path,
          ),
        );
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [await _asShareable(file)],
          title: state.dataset?.name.inLanguage(languageCode),
        ),
      );

      emit(
        state.copyWith(
          status: ExportStatus.choosing,
          lastRowCount: file.rowCount,
          lastRecordCount: file.recordCount,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: ExportStatus.error, error: e.toString()));
    }
  }
}
