import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/complaints/domain/complaint.dart';

/// The anonymity is the server's to keep — this file guards the half the client
/// is still capable of ruining.
///
/// The redaction happens in `complaints_against_me` and `complaint_thread`
/// (migration 0079), which simply do not select an identity the reader may not
/// have. What could still go wrong up here is the app inventing one back: a
/// `fromMap` that defaults a null name to something, a widget that falls back to
/// an id when a name is missing, a model that carries a field the row never had.
///
/// So: a row with no author must parse to a message with no author, and the
/// model must SAY it is anonymous rather than leaving every call site to
/// re-derive that from three separate nulls.
void main() {
  group('a bubble the server did not sign', () {
    // Exactly what complaint_thread returns to the employee a complaint is
    // about: the words, the time, the side — and three nulls where the person
    // would be.
    Map<String, dynamic> redactedRow() => {
      'reply_id': null,
      'created_at': '2026-08-02T09:15:00.000Z',
      'body': 'ما حدث في الفندق',
      'author_id': null,
      'author_name': null,
      'author_photo_url': null,
      'author_role': 'complainant',
      'is_mine': false,
      'attachments': <Map<String, dynamic>>[],
    };

    test('parses with nobody in it, and knows that it has nobody in it', () {
      final message = ComplaintMessage.fromMap(redactedRow());

      expect(message.authorId, isNull, reason: 'an id was invented');
      expect(message.authorName, isNull, reason: 'a name was invented');
      expect(
        message.authorPhotoUrl,
        isNull,
        reason: 'a face was invented — which identifies a man more surely '
            'than a name does',
      );
      expect(
        message.isAnonymous,
        isTrue,
        reason: 'the model must say it plainly, or every widget that draws a '
            'bubble has to remember to check three fields and one of them '
            'eventually will not',
      );
    });

    test('still says which side it came from', () {
      final message = ComplaintMessage.fromMap(redactedRow());
      expect(
        message.role,
        ComplaintRole.complainant,
        reason: 'the role is what lets an unnamed bubble be labelled at all',
      );
    });

    test('the head of the thread is the complaint itself', () {
      expect(ComplaintMessage.fromMap(redactedRow()).isHead, isTrue);
      final reply = ComplaintMessage.fromMap(
        redactedRow()..['reply_id'] = 'a-reply-id',
      );
      expect(reply.isHead, isFalse);
    });

    test('an unsigned row is not mistaken for the reader own message', () {
      final message = ComplaintMessage.fromMap(redactedRow());
      expect(
        message.isMine,
        isFalse,
        reason: 'is_mine comes from the server; a missing author must never '
            'be read as "no author, so it must be me"',
      );
    });
  });

  group('a bubble the server did sign', () {
    test('keeps the name it was given', () {
      final message = ComplaintMessage.fromMap({
        'reply_id': 'r1',
        'created_at': '2026-08-02T10:00:00.000Z',
        'body': 'ردّي',
        'author_id': 'u1',
        'author_name': 'أحمد محمد الخطيب',
        'author_photo_url': 'https://example.invalid/a.jpg',
        'author_role': 'accused',
        'is_mine': true,
        'attachments': const <Map<String, dynamic>>[],
      });

      expect(message.isAnonymous, isFalse);
      expect(message.authorName, 'أحمد محمد الخطيب');
      expect(message.role, ComplaintRole.accused);
      expect(message.isMine, isTrue);
    });
  });

  group('the accused own list', () {
    test('carries no complainant, whatever else the row has on it', () {
      // complaints_against_me does not return an identity column at all. If a
      // future change to the RPC ever added one back, this row shape would
      // still ignore it — the model has nowhere to put it.
      final complaint = Complaint.fromAgainstMeRow({
        'id': 'c1',
        'created_at': '2026-08-02T09:15:00.000Z',
        'body': 'نص',
        'is_locked': false,
        'is_dismissed': false,
        'reply_count': 2,
        'attachments': const <Map<String, dynamic>>[],
        // Not part of the contract — here precisely to prove it is ignored.
        'complainant_id': 'leaked-id',
        'complainant_name': 'leaked name',
      });

      expect(complaint.complainantId, isNull);
      expect(complaint.complainantName, isNull);
      expect(complaint.isAnonymousToMe, isTrue);
      expect(complaint.myRole, ComplaintRole.accused);
      expect(complaint.replyCount, 2);
    });
  });

  group('timestamps', () {
    test('arrive as local time, like every other date in this app', () {
      final message = ComplaintMessage.fromMap({
        'reply_id': null,
        'created_at': '2026-08-02T09:15:00.000Z',
        'body': 'x',
        'author_role': 'manager',
        'is_mine': false,
        'attachments': const <Map<String, dynamic>>[],
      });
      expect(
        message.createdAt.isUtc,
        isFalse,
        reason: 'shown to a person, so it is their clock that matters',
      );
    });
  });
}
