import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/modules/presentation/module_detail_screen.dart';

/// A file is reached down two corridors. Under إدارة الملفات it is the season's
/// paperwork and the point is to run it; under عام it is a man's own posting,
/// the same file every other member of it sees, and the point is to read it.
///
/// The permission alone answered the wrong question. A manager who is also
/// assigned to a tower held `modules.manage`, so Edit, Deactivate and Delete
/// appeared on his own posting too — three ways to alter the season's paperwork
/// from a list that never claimed to be about managing it, one of them a tap
/// from destroying it.
void main() {
  test('a file opens read-only unless it was opened from the office', () {
    // The default, which is what every caller that does not think about this
    // gets: the employee page opening somebody's assignment, and any route
    // added later.
    expect(const ModuleDetailScreen(moduleId: 'x').fromOffice, isFalse);

    // Reading another employee's assignment from their page — a viewer, however
    // senior, is looking at what THAT person is responsible for.
    expect(
      const ModuleDetailScreen(moduleId: 'x', viewAsProfileId: 'y').fromOffice,
      isFalse,
    );

    // Only إدارة الملفات says otherwise, and it has to say so out loud.
    expect(
      const ModuleDetailScreen(moduleId: 'x', fromOffice: true).fromOffice,
      isTrue,
    );
  });

  group('which corridor a control belongs to', () {
    // The flag stopped being only about DESTROYING things the moment the file
    // page grew controls for a season and controls for a person side by side.
    //
    // Under عام a file is a man's own posting and everything on it should be
    // about his part in it: where he is, what he owes. Under الإدارة it is the
    // season's paperwork and everything is about running it: who is in place,
    // what the codes are, who may be added.
    //
    // These are written out because the mistake is invisible in review. A
    // control added to the page without a corridor named simply appears on
    // both, and looks perfectly reasonable in both — "who is in place" sat on
    // a member's own tower for a while and read as a feature rather than a
    // leak.

    /// What the page shows a member looking at his own posting.
    const forTheMember = {'check in'};

    /// What it shows the office running the season.
    const forTheOffice = {
      'presence',
      'place codes',
      'edit',
      'delete',
      'activate',
      'members',
    };

    test('the two sets do not overlap', () {
      expect(
        forTheMember.intersection(forTheOffice),
        isEmpty,
        reason: 'a control on both corridors is a control that has not been '
            'decided about',
      );
    });

    test('checking in is the member\'s, and only his', () {
      // The one act on this page a person takes about HIMSELF. Whoever runs a
      // file may well be standing in one of its towers — and does that on his
      // own posting, down the other corridor.
      expect(forTheMember, contains('check in'));
      expect(forTheOffice, isNot(contains('check in')));
    });

    test('the roll of who is in place is the office\'s', () {
      // It used to be on both, on the argument that presence is "about the
      // file itself". The trust is right and the corridor was wrong: it is a
      // supervisor's question, and it was sitting beside a member's answer.
      expect(forTheOffice, contains('presence'));
      expect(forTheMember, isNot(contains('presence')));
    });
  });
}
