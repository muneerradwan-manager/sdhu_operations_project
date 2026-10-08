import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/l10n/localized_name.dart';
import 'package:sdhu_operations_project/core/widgets/info_section.dart';
import 'package:sdhu_operations_project/features/modules/application/module_editor_cubit.dart';
import 'package:sdhu_operations_project/features/modules/data/modules_repository.dart';
import 'package:sdhu_operations_project/features/modules/domain/module_type.dart';
import 'package:sdhu_operations_project/features/modules/presentation/module_editor_screen.dart';
import 'package:sdhu_operations_project/l10n/app_localizations.dart';

/// The first step of the editor asks seven things, and for a long time it asked
/// them as one undivided column inside one card. Every one of the seven is
/// still asked; what changed is that they are grouped, that the two dates stand
/// beside each other where there is room, and that the two notes — prose,
/// optional, and empty on most files — are folded behind a line until somebody
/// wants them.
///
/// What has to hold: the folding never loses what is written, the order down a
/// phone keeps each note under the date it belongs to, and the panes reflow
/// into two columns on a window wide enough without the form controls in them
/// falling over. That last one is not idle — a pane puts its children in an
/// equal-height row, which measures each cell by asking it how tall it wants to
/// be, and a text field is not obliged to be able to answer.
class _FakeModules extends ModulesRepository {
  @override
  Future<ModuleType?> fetchModuleType(String id) async => null;

  @override
  Future<List<ModuleType>> fetchModuleTypes({bool activeOnly = true}) async =>
      const [];
}

void main() {
  LocalizedName n(String s) => LocalizedName(ar: s, en: s);

  ModuleType typeOf({List<ModuleField> fields = const []}) =>
      ModuleType(id: 't', code: 'c', name: n('قطاعات وأبراج'), fields: fields);

  final officialPdf = ModuleField(
    id: 'f',
    key: 'official_pdf',
    label: n('Official PDF'),
    kind: ModuleFieldKind.pdf,
  );

  /// The step, standing on its own with a cubit behind it. The state is handed
  /// in rather than loaded, so a test says what the file holds instead of
  /// waiting for one.
  Future<ModuleEditorCubit> pump(
    WidgetTester tester,
    ModuleEditorState state, {
    double width = 420,
  }) async {
    tester.view.physicalSize = Size(width, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final cubit = ModuleEditorCubit(
      _FakeModules(),
      moduleTypeId: 't',
      seasonId: 's',
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<ModuleEditorCubit>.value(
            value: cubit,
            child: ModuleInfoStep(state: state),
          ),
        ),
      ),
    );
    await tester.pump();
    return cubit;
  }

  ModuleEditorState ready({
    String? startNote,
    String? endNote,
    List<ModuleField> fields = const [],
  }) => ModuleEditorState(
    status: EditorStatus.ready,
    type: typeOf(fields: fields),
    startsOn: DateTime(2026, 5, 1),
    startNote: startNote,
    endNote: endNote,
  );

  final startsOn = find.byKey(const ValueKey('starts_on'));
  final endsOn = find.byKey(const ValueKey('ends_on'));
  final startNote = find.byKey(const ValueKey('start_note'));
  final endNote = find.byKey(const ValueKey('end_note'));

  group('the notes are folded away', () {
    testWidgets('a new file shows the dates and one line, not four boxes', (
      tester,
    ) async {
      await pump(tester, ready());

      expect(tester.takeException(), isNull);
      expect(startsOn, findsOneWidget);
      expect(endsOn, findsOneWidget);
      expect(startNote, findsNothing);
      expect(endNote, findsNothing);
      expect(find.text('Add a note to the start or the end'), findsOneWidget);
    });

    testWidgets('pressing the line opens both, and pressing it again closes', (
      tester,
    ) async {
      await pump(tester, ready());

      await tester.tap(find.text('Add a note to the start or the end'));
      await tester.pump();
      expect(startNote, findsOneWidget);
      expect(endNote, findsOneWidget);

      await tester.tap(find.text('Hide the notes'));
      await tester.pump();
      expect(startNote, findsNothing);
    });

    testWidgets('a file that already has a note opens showing it', (
      tester,
    ) async {
      // Coming back to a file and being shown a form that does not mention the
      // note on it is how that note gets overwritten by somebody who never knew
      // it was there.
      await pump(tester, ready(startNote: 'بدأ مع وصول الدفعة الأولى'));

      expect(startNote, findsOneWidget);
      expect(endNote, findsOneWidget);
      expect(find.text('بدأ مع وصول الدفعة الأولى'), findsOneWidget);
      expect(find.text('Hide the notes'), findsOneWidget);
    });
  });

  group('what is beside what', () {
    testWidgets('down a phone, each note follows its own date', (tester) async {
      await pump(tester, ready(startNote: 'a', endNote: 'b'));

      expect(tester.takeException(), isNull);
      double top(Finder f) => tester.getTopLeft(f).dy;
      // The order that reads: when it starts, what is said about that, when it
      // ends, what is said about that.
      expect(top(startsOn), lessThan(top(startNote)));
      expect(top(startNote), lessThan(top(endsOn)));
      expect(top(endsOn), lessThan(top(endNote)));
    });

    testWidgets('on a wide window the start stands beside the end', (
      tester,
    ) async {
      await pump(tester, ready(startNote: 'a', endNote: 'b'), width: 1200);

      expect(tester.takeException(), isNull);
      // Two columns: the two dates on one line, each note under its own date
      // rather than under the other one.
      expect(tester.getTopLeft(startsOn).dy, tester.getTopLeft(endsOn).dy);
      expect(tester.getTopLeft(startNote).dx, tester.getTopLeft(startsOn).dx);
      expect(tester.getTopLeft(endNote).dx, tester.getTopLeft(endsOn).dx);
      expect(tester.getTopLeft(endsOn).dx, greaterThan(
        tester.getTopLeft(startsOn).dx,
      ));
    });

    testWidgets('the text in a note survives the window being widened', (
      tester,
    ) async {
      // A pane reflows its children into a different number of columns as the
      // window changes; an unkeyed field carries whatever the field that used
      // to stand in its place was holding.
      final state = ready(startNote: 'بداية', endNote: 'نهاية');
      await pump(tester, state);
      await pump(tester, state, width: 1200);

      expect(find.text('بداية'), findsOneWidget);
      expect(find.text('نهاية'), findsOneWidget);
    });
  });

  group('the panes', () {
    testWidgets('the two that every file has are the same two', (tester) async {
      await pump(tester, ready());

      expect(find.text('Work period'), findsOneWidget);
      expect(find.text('Decision and reports'), findsOneWidget);
      // Both of the paperwork fields are in the second pane, not scattered.
      expect(find.text('Decision / file number'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
    });

    testWidgets('a type with no fields of its own gets no third pane', (
      tester,
    ) async {
      await pump(tester, ready());

      expect(find.byType(InfoSection), findsNWidgets(2));
      expect(find.text('Fields of this type'), findsNothing);
    });

    testWidgets('a type that declares one gets it, in its own pane', (
      tester,
    ) async {
      await pump(tester, ready(fields: [officialPdf]));

      expect(tester.takeException(), isNull);
      expect(find.byType(InfoSection), findsNWidgets(3));
      expect(find.text('Fields of this type'), findsOneWidget);
      expect(find.text('Official PDF'), findsOneWidget);
    });
  });
}
