import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/modules/application/module_editor_cubit.dart';
import 'package:sdhu_operations_project/features/modules/domain/operational_module.dart';

/// A فندق stands in one برج, and a تكتل is tied to one برج. The database says
/// so with two partial unique indexes; the picker says so by leaving the taken
/// ones out, so nobody is offered a choice that will be refused.
///
/// The `except` argument is what makes EDITING work: a node being edited must
/// still be offered the entry it already holds, or reopening a tower would show
/// its own hotel missing from the list.
void main() {
  ModuleNode node(
    String id, {
    required String levelId,
    String? entry,
    String? tied,
  }) => ModuleNode(
    id: id,
    moduleId: 'm',
    levelId: levelId,
    referenceItemId: entry,
    secondaryReferenceItemId: tied,
  );

  final state = ModuleEditorState(
    nodes: [
      node('n1', levelId: 'tower', entry: 'hotel-a', tied: 'cluster-a'),
      node('n2', levelId: 'tower', entry: 'hotel-b', tied: 'cluster-b'),
      // Another level entirely — its entries are none of the tower's business.
      node('n3', levelId: 'sector', entry: 'other'),
    ],
  );

  test('both lists are taken per level', () {
    expect(state.takenEntries('tower'), {'hotel-a', 'hotel-b'});
    expect(state.takenSecondaryEntries('tower'), {'cluster-a', 'cluster-b'});
  });

  test('a node being edited does not block its own entries', () {
    expect(state.takenEntries('tower', except: 'n1'), {'hotel-b'});
    expect(state.takenSecondaryEntries('tower', except: 'n1'), {'cluster-b'});
  });

  test('another level is not consulted', () {
    expect(state.takenEntries('sector'), {'other'});
    expect(state.takenSecondaryEntries('sector'), isEmpty);
  });

  test('a node that is tied to nothing contributes nothing', () {
    final loose = ModuleEditorState(
      nodes: [node('n1', levelId: 'tower', entry: 'hotel-a')],
    );

    expect(loose.takenEntries('tower'), {'hotel-a'});
    expect(loose.takenSecondaryEntries('tower'), isEmpty);
  });
}
