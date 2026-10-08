import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/l10n/localized_name.dart';
import 'package:sdhu_operations_project/features/modules/application/module_editor_cubit.dart';
import 'package:sdhu_operations_project/features/modules/domain/module_type.dart';

/// The editor used to count its steps — two for a roster, three for a tree —
/// which held only for as long as a file was one thing or the other. تشكيل فرق
/// المشاعر is both: divided into قطاعات like the towers file, stopping there
/// rather than going on to hotels, and carrying two teams on the file itself.
/// Counting sent every step past the first of a tree type to the towers screen,
/// so its teams had nowhere to be filled in.
///
/// The steps are named now, and each appears when the TYPE has something to put
/// in it. What these tests hold is that the two shapes which already worked
/// still come out byte for byte the same.
void main() {
  LocalizedName n(String s) => LocalizedName(ar: s, en: s);

  ModuleRole role(String code, {String? levelId}) =>
      ModuleRole(id: 'role-$code', code: code, name: n(code), levelId: levelId);

  ModuleLevel level(String code, int depth, {List<ModuleRole> roles = const []}) =>
      ModuleLevel(
        id: 'level-$code',
        code: code,
        name: n(code),
        depth: depth,
        // A hotel is drawn from a list; a sector is named by hand. Only the
        // depth matters to the step model, but keep the shape honest.
        referenceSetId: code == 'tower' ? 'set-hotels' : null,
        roles: roles,
      );

  ModuleEditorState stateOf(ModuleType type) =>
      ModuleEditorState(status: EditorStatus.ready, type: type);

  ModuleType typeOf({
    List<ModuleRole> roles = const [],
    List<ModuleLevel> levels = const [],
  }) => ModuleType(
    id: 't',
    code: 'c',
    name: n('t'),
    roles: roles,
    levels: levels,
  );

  test('a flat roster is the file and its team', () {
    final state = stateOf(typeOf(roles: [role('supervisor'), role('member')]));

    expect(state.stepKinds, [EditorStep.info, EditorStep.teams]);
    expect(state.lastStep, 1);
  });

  test('sectors and towers is unchanged — file, sectors, towers', () {
    final state = stateOf(
      typeOf(
        levels: [
          level('sector', 1, roles: [role('sector_supervisor', levelId: 'level-sector')]),
          level('tower', 2, roles: [role('tower_supervisor', levelId: 'level-tower')]),
        ],
      ),
    );

    expect(state.stepKinds, [
      EditorStep.info,
      EditorStep.sectors,
      EditorStep.towers,
    ]);
    expect(state.lastStep, 2);
  });

  test('sectors with no level inside them get no towers step', () {
    final state = stateOf(
      typeOf(
        roles: [role('coasters_manager'), role('catering_monitor')],
        levels: [
          level('sector', 1, roles: [role('sector_supervisor', levelId: 'level-sector')]),
        ],
      ),
    );

    expect(state.stepKinds, [
      EditorStep.info,
      EditorStep.sectors,
      EditorStep.teams,
    ]);
    expect(state.lastStep, 2);
    // The step that used to swallow this one: at index 2 the old code returned
    // the towers screen for any tree type, and this file has no towers.
    expect(state.currentStep, EditorStep.info);
  });

  test('a tree of two rungs AND a team takes all four steps', () {
    // مخيمات منى: مراكز, the مخيمات inside them, and فريق الكوسترات, which
    // belongs to no مركز because the buses move between all of them.
    final state = stateOf(
      typeOf(
        roles: [role('coasters_supervisor'), role('coasters_member')],
        levels: [
          level('center', 1, roles: [role('center_supervisor', levelId: 'level-center')]),
          level('camp', 2, roles: [role('camp_member', levelId: 'level-camp')]),
        ],
      ),
    );

    expect(state.stepKinds, [
      EditorStep.info,
      EditorStep.sectors,
      EditorStep.towers,
      EditorStep.teams,
    ]);
    expect(state.lastStep, 3);
  });

  test('the step in force follows the index, and never runs off the end', () {
    final type = typeOf(
      roles: [role('coasters_manager')],
      levels: [level('sector', 1)],
    );

    expect(stateOf(type).copyWith(step: 1).currentStep, EditorStep.sectors);
    expect(stateOf(type).copyWith(step: 2).currentStep, EditorStep.teams);
    // A step index outlives a reload; the type arrives after the first frame.
    expect(stateOf(type).copyWith(step: 9).currentStep, EditorStep.teams);
  });

  test('before the type is known the wizard is just its first step', () {
    const state = ModuleEditorState();

    expect(state.stepKinds, [EditorStep.info]);
    expect(state.currentStep, EditorStep.info);
  });
}
