/// What became of a write, in the three ways it can now end.
///
/// Before the outbox there were two — it worked, or here is the error — and the
/// screens were written around that. There is a third now, and it is neither of
/// them: the work was ACCEPTED and is not yet sent. Telling a person that as
/// success would be a small lie he finds out about later; telling it as failure
/// would be a large one, and would make him do it again.
class SaveOutcome {
  const SaveOutcome.sent() : error = null, queued = false;

  /// Kept on the device. The person's part is finished.
  const SaveOutcome.queued() : error = null, queued = true;

  const SaveOutcome.failed(String this.error) : queued = false;

  /// Null when nothing went wrong. Raw exception text — the screens put it
  /// through `friendlyError` as they always have.
  final String? error;

  final bool queued;

  bool get ok => error == null;
}
