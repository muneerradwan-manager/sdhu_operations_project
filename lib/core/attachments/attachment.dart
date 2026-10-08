import 'dart:io';

/// What an attachment is, decided when it is attached rather than guessed from
/// the file name afterwards. Mirrors the `attachment_kind` enum (0031).
enum AttachmentKind {
  image,
  video,
  audio,
  file;

  static AttachmentKind fromDb(String? value) => switch (value) {
    'image' => AttachmentKind.image,
    'video' => AttachmentKind.video,
    'audio' => AttachmentKind.audio,
    _ => AttachmentKind.file,
  };

  /// Whether the app can show this itself. An image it can; a video, a voice
  /// note and a document are handed to whatever the device plays them with.
  bool get isViewableInApp => this == AttachmentKind.image;
}

/// One file chosen on the device, before it has been uploaded anywhere.
class PendingAttachment {
  const PendingAttachment({
    required this.file,
    required this.name,
    required this.kind,
    this.mimeType,
  });

  final File file;
  final String name;
  final AttachmentKind kind;
  final String? mimeType;
}

/// A file that has been uploaded and has a row pointing at it.
///
/// Shared by everything in this app that carries attachments — a notification
/// and a module report keep them in different tables, but the columns are the
/// same and so is what the reader does with them. [path] points into a private
/// bucket; nothing is readable from it without a signed URL.
class StoredAttachment {
  const StoredAttachment({
    required this.id,
    required this.kind,
    required this.path,
    required this.name,
    this.mimeType,
    this.sizeBytes,
  });

  final String id;
  final AttachmentKind kind;
  final String path;
  final String name;
  final String? mimeType;
  final int? sizeBytes;

  /// "1.4 MB". Null when the size was not recorded, which reads better as
  /// nothing at all than as "0 B".
  String? get readableSize {
    final bytes = sizeBytes;
    if (bytes == null || bytes <= 0) return null;
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
  }

  /// The inverse of [fromMap], in the same column names.
  ///
  /// Wanted by the outbox, which has to write a taking-back of an attachment
  /// into a JSON file and read it again a day later, on the other side of the
  /// app having been closed.
  Map<String, dynamic> toMap() => {
    'id': id,
    'kind': kind.name,
    'path': path,
    'name': name,
    'mime_type': mimeType,
    'size_bytes': sizeBytes,
  };

  factory StoredAttachment.fromMap(Map<String, dynamic> map) =>
      StoredAttachment(
        id: map['id'] as String,
        kind: AttachmentKind.fromDb(map['kind'] as String?),
        path: map['path'] as String,
        name: map['name'] as String,
        mimeType: map['mime_type'] as String?,
        sizeBytes: (map['size_bytes'] as num?)?.toInt(),
      );
}
