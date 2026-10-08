import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/complaints/domain/complaint.dart';
import 'package:sdhu_operations_project/l10n/app_localizations.dart';
import 'package:sdhu_operations_project/features/complaints/presentation/widgets/complaint_labels.dart';

/// The seven things a complaint may be about, and the two places their names
/// have to agree.
///
/// `ComplaintTarget.name` is not decoration: the repository sends it to the
/// server as `p_target_type`, where it is cast to the `complaint_target_type`
/// enum, and for hotels/clusters/groups it also picks the reference set by
/// pluralising it. Rename a value here and both break — the first with a cast
/// error, the second silently, by filtering for a set that does not exist.
void main() {
  group('the wire names', () {
    test('are exactly the enum the database declares', () {
      expect(
        ComplaintTarget.values.map((t) => t.name).toSet(),
        {'employee', 'module', 'report', 'hotel', 'cluster', 'group', 'other'},
        reason: 'these strings are cast to complaint_target_type by 0079; '
            'a rename here is a runtime cast error there',
      );
    });

    test('round-trip through the parser', () {
      for (final target in ComplaintTarget.values) {
        expect(
          ComplaintTarget.fromDb(target.name),
          target,
          reason: '${target.name} did not survive the round trip',
        );
      }
    });

    test('an unknown value falls back to `other` rather than throwing', () {
      // A value added by a future migration must not crash a client that has
      // not been updated; it reads as "something else", which it is.
      expect(ComplaintTarget.fromDb('vehicle'), ComplaintTarget.other);
      expect(ComplaintTarget.fromDb(null), ComplaintTarget.other);
    });
  });

  group('what needs a target picked', () {
    test('everything but `other`', () {
      for (final target in ComplaintTarget.values) {
        expect(
          target.needsTarget,
          target != ComplaintTarget.other,
          reason: '${target.name} disagreed about needing a target',
        );
      }
    });

    test('the three that are reference items are exactly the three', () {
      expect(
        ComplaintTarget.values.where((t) => t.isReferenceItem).toSet(),
        {ComplaintTarget.hotel, ComplaintTarget.cluster, ComplaintTarget.group},
        reason: 'these three are rows of reference_items and are told apart by '
            'their set code; the repository derives that code from the enum '
            "value's own name",
      );
    });
  });

  group('roles', () {
    test('parse from what the server stamps on each bubble', () {
      expect(ComplaintRole.fromDb('accused'), ComplaintRole.accused);
      expect(ComplaintRole.fromDb('manager'), ComplaintRole.manager);
      expect(ComplaintRole.fromDb('complainant'), ComplaintRole.complainant);
    });

    test('an unrecognised role is not silently promoted to manager', () {
      // Whatever the fallback is, it must be the least powerful reading —
      // `manager` is the one that unlocks actions in the UI.
      expect(ComplaintRole.fromDb(null), isNot(ComplaintRole.manager));
      expect(ComplaintRole.fromDb('something-new'), isNot(ComplaintRole.manager));
    });
  });

  group('the standing that decides a suspension', () {
    test('three different people is the line, not three complaints', () {
      expect(ComplaintStanding.threshold, 3);
    });

    test('one short is announced, so a manager is not surprised by it', () {
      const near = ComplaintStanding(
        distinctComplainants: 2,
        openComplaints: 5,
      );
      expect(near.isOneShortOfSuspension, isTrue);
    });

    test('not announced once the rule has already fired', () {
      const fired = ComplaintStanding(
        distinctComplainants: 3,
        openComplaints: 3,
        isAutoSuspended: true,
      );
      expect(fired.isOneShortOfSuspension, isFalse);
    });

    test('not announced for complainants already forgiven by hand', () {
      // A manager lifted a suspension at three; two of those three are not a
      // warning that the fourth is coming.
      const forgiven = ComplaintStanding(
        distinctComplainants: 2,
        openComplaints: 4,
        forgivenCount: 3,
      );
      expect(
        forgiven.isOneShortOfSuspension,
        isFalse,
        reason: 'the rule cannot fire below the forgiven count, so warning '
            'about it would be a warning about nothing',
      );
    });
  });

  group('every kind has a name in both languages', () {
    test('and none of them falls through to a raw code', () async {
      for (final locale in AppLocalizations.supportedLocales) {
        final l = await AppLocalizations.delegate.load(locale);
        for (final target in ComplaintTarget.values) {
          final label = complaintTargetLabel(l, target);
          expect(label, isNotEmpty, reason: '${target.name} in $locale');
          expect(
            label,
            isNot(target.name),
            reason: '${target.name} in $locale showed its wire name to a '
                'reader, which is what a missing translation looks like',
          );
        }
        for (final role in ComplaintRole.values) {
          expect(complaintRoleLabel(l, role), isNotEmpty);
        }
      }
    });
  });
}
