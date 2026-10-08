import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../utils/network_error.dart';
import 'l10n_extension.dart';

/// Turns a cubit's stored error string into something a person can read.
///
/// Cubits keep `e.toString()`; unfiltered, a dead connection surfaced as
/// `ClientException with SocketException: Failed host lookup…` — raw English
/// exception text as the headline of an Arabic screen. Anything that smells
/// like the network being down becomes the localized "couldn't reach the
/// server"; everything else passes through, because a real server message
/// ("this reference item is in use") is worth more than a generic apology.
String friendlyError(BuildContext context, String? raw) =>
    friendlyErrorL(context.l10n, raw);

/// Same, for call sites past an async gap: they capture [AppLocalizations]
/// before the await and hand it in, instead of touching the context after.
String friendlyErrorL(AppLocalizations l, String? raw) {
  if (raw == null || raw.trim().isEmpty) return l.commonGenericError;
  final s = raw.toLowerCase();
  // The same list the outbox decides retries by — see [looksLikeNetworkFailure].
  // Kept in one place because the two must agree: a failure this calls "the
  // connection" is exactly the failure that ought to be tried again.
  if (looksLikeNetworkFailure(raw)) return l.commonConnectionErrorTitle;
  // Codes the admin-set-email function answers with. They arrive wrapped in
  // exception text ("FunctionException(status: 400, details: {error:
  // email_taken}…)"), so this matches by substring like the smells above.
  // The six digits handed back at sign-up. Supabase says "Token has expired or
  // is invalid" — one sentence for two cases, and rightly, since the reader's
  // next move is the same either way: type it again, or ask for another.
  if (s.contains('otp_expired') ||
      (s.contains('token') &&
          (s.contains('expired') || s.contains('invalid')))) {
    return l.authVerifyWrongCode;
  }
  if (s.contains('email_taken')) return l.employeeEmailTaken;
  if (s.contains('cannot_set_admin_email')) return l.employeeEmailAdminBlocked;
  // The reports trigger (0078) refusing a second once-per-season report. The
  // editor blocks this before saving, so this is the belt behind the braces —
  // a stale list, or two people entering the same document at once.
  if (s.contains('report_once_per_season')) return l.reportOncePerSeason;
  // The complaints migration (0079). The form blocks the first three before
  // sending, so these are the belt behind the braces; `complaint_locked` is the
  // one that genuinely reaches a person, when somebody closed the thread while
  // they were typing into it.
  // The six refusals of 0098, in the order the server checks them — each one
  // the most actionable thing that could be said at that point.
  //
  // Two of them the app also raises itself, as bare codes rather than as
  // exceptions: `check_in_needs_a_position`, because a check-in with no fix
  // cannot succeed later and must not be queued, and `check_in_too_far`, which
  // the phone decides for itself when the network is gone. One sentence answers
  // both the local refusal and the server's, which is the point of naming them
  // the same thing.
  if (s.contains('check_in_needs_a_position')) return l.checkInNeedsAPosition;
  if (s.contains('check_in_too_far')) return l.checkInTooFar;
  if (s.contains('check_in_code_expired')) return l.checkInCodeExpired;
  if (s.contains('check_in_place_has_no_location')) {
    return l.checkInPlaceHasNoLocation;
  }
  if (s.contains('check_in_not_a_place')) return l.checkInNotAPlace;
  if (s.contains('check_in_not_approved')) return l.checkInNotApproved;
  if (s.contains('check_in_codes_denied')) return l.checkInCodesDenied;
  if (s.contains('check_in_rotate_denied')) return l.checkInRotateDenied;
  if (s.contains('complaint_locked')) return l.complaintLocked;
  if (s.contains('complaint_body_required')) return l.complaintBodyRequired;
  if (s.contains('complaint_target_missing') ||
      s.contains('complaint_target_wrong_set')) {
    return l.complaintTargetRequired;
  }
  if (s.contains('complaint_not_found')) return l.complaintMissing;
  // The evaluations migration (0084). The form and the fill screen block most
  // of these before sending, so these are the belt behind the braces — except
  // `evaluation_incomplete`, which the fill screen raises itself as a code so
  // that one sentence answers both the local refusal and the server's.
  if (s.contains('evaluation_incomplete')) return l.evaluationIncomplete;
  if (s.contains('evaluation_already_submitted')) {
    return l.evaluationAlreadySubmitted;
  }
  if (s.contains('evaluation_not_found') ||
      s.contains('evaluation_form_not_found')) {
    return l.evaluationMissing;
  }
  if (s.contains('evaluation_form_in_use')) return l.evaluationEditorForLocked;
  if (s.contains('evaluation_option_worth_more_than_question')) {
    return l.evaluationErrorOptionTooHigh;
  }
  if (s.contains('evaluation_written_question_takes_no_options')) {
    return l.evaluationErrorWrittenHasOptions;
  }
  return raw;
}
