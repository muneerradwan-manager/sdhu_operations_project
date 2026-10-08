/// Turns a file name into something storage will accept as an object key.
///
/// Supabase rejects a key with non-ASCII characters in it — `InvalidKey`, 400,
/// nothing uploaded — and in this app almost every file picked off a phone is
/// named in Arabic. So the key is stripped down to what is safe, and the name
/// the person's device gave it is kept beside it in the row (or in
/// `modules.data`) and is what gets shown and downloaded. The key is plumbing;
/// nobody reads it.
///
/// The extension survives, because storage serves a file by what its key ends
/// in. [fallback] names the file when nothing usable is left — an Arabic name
/// strips to nothing — and should be something unique in the folder, so two
/// such files do not land on one key.
String storageKey(String fileName, {String fallback = 'file'}) {
  final dot = fileName.lastIndexOf('.');
  final hasExtension = dot > 0 && dot < fileName.length - 1;
  final base = hasExtension ? fileName.substring(0, dot) : fileName;
  final extension = hasExtension ? _safe(fileName.substring(dot + 1)) : '';

  var safeBase = _safe(base);
  // What is left of "منير عبدالله رضوان" is nothing at all, and an empty key is
  // as invalid as an Arabic one.
  if (safeBase.replaceAll('_', '').isEmpty) safeBase = _safe(fallback);
  if (safeBase.isEmpty) safeBase = 'file';

  // Long names come off scanners and WhatsApp; the key does not need all of it.
  if (safeBase.length > 60) safeBase = safeBase.substring(0, 60);

  return extension.isEmpty ? safeBase : '$safeBase.$extension';
}

/// ASCII letters, digits and the three separators storage is happy with.
/// Everything else becomes an underscore, runs of them collapse, and a key does
/// not start or end on one — "تقرير-2026.jpg" should read "2026.jpg", not
/// "_-2026.jpg".
String _safe(String value) => value
    .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
    .replaceAll(RegExp(r'_+'), '_')
    .replaceAll(RegExp(r'^[_.\-]+|[_\-]+$'), '');
