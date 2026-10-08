/// What a failure looks like when the cause was the network rather than the
/// request.
///
/// Matched on the text because that is the only thing the several layers below
/// agree on. A dead connection surfaces as a `SocketException` from `dart:io`,
/// a `ClientException` from `package:http`, a `TimeoutException` from
/// `dart:async`, and as any of those wrapped inside a `PostgrestException`, a
/// `StorageException` or a `FunctionException` depending on which Supabase call
/// was in flight. Catching the types would mean naming six of them and missing
/// the seventh.
///
/// Two callers, and they want it for different reasons: the error text a person
/// reads (a raw `Failed host lookup` is not an Arabic sentence), and the outbox,
/// which retries this and only this without counting it as a refusal.
const networkSmells = [
  'socketexception',
  'clientexception',
  'failed host lookup',
  'connection refused',
  'connection reset',
  'connection closed',
  'network is unreachable',
  'timeoutexception',
  'handshakeexception',
  'operation timed out',
];

/// Whether [error] — an exception, or the string a cubit kept of one — was the
/// network being unreachable.
bool looksLikeNetworkFailure(Object? error) {
  if (error == null) return false;
  final text = error.toString().toLowerCase();
  for (final smell in networkSmells) {
    if (text.contains(smell)) return true;
  }
  return false;
}
