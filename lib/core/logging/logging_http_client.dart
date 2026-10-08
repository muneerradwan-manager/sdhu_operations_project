import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_logger.dart';

/// An HTTP client that prints what went out and what came back.
///
/// Handed to `Supabase.initialize`, so every PostgREST query, auth call,
/// storage upload and Edge Function invocation passes through it — one place
/// rather than a log line written at each call site and forgotten at the next.
///
/// Realtime is NOT covered: it is a WebSocket and never touches this. Neither
/// are images fetched by `cached_network_image`, which brings its own client.
class LoggingHttpClient extends http.BaseClient {
  LoggingHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  static const _tag = 'http';

  /// Headers whose values are never printed. An access token in a console log
  /// is an access token in a screen recording.
  static const _redacted = {
    'authorization',
    'apikey',
    'x-client-info',
    'cookie',
    'set-cookie',
  };

  /// Bodies of these content types are not printed — a JPEG rendered as text is
  /// several thousand lines of noise.
  static bool _isPrintable(String? contentType) {
    if (contentType == null) return true;
    final type = contentType.toLowerCase();
    return type.contains('json') ||
        type.contains('text') ||
        type.contains('xml') ||
        type.contains('x-www-form-urlencoded');
  }

  /// Auth traffic's bodies are never printed, in either direction. The header
  /// redaction above was guarding tokens while the password login's request
  /// body (email + password) and its response (access and refresh tokens) went
  /// to the console verbatim — the very credentials it existed to keep out of
  /// a screen recording.
  static bool _isAuthTraffic(Uri url) => url.path.contains('/auth/v1/');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!AppLogger.enabled) return _inner.send(request);

    final started = DateTime.now();
    AppLogger.info(_tag, '→ ${request.method} ${request.url}');
    _logHeaders('→', request.headers);

    if (request is http.Request && request.body.isNotEmpty) {
      if (_isAuthTraffic(request.url)) {
        AppLogger.debug(_tag, '→ body <auth, redacted>');
      } else if (_isPrintable(request.headers['content-type'])) {
        AppLogger.debug(_tag, '→ body ${AppLogger.truncate(request.body)}');
      } else {
        AppLogger.debug(
          _tag,
          '→ body <${request.headers['content-type']}, '
          '${request.contentLength} bytes>',
        );
      }
    } else if (request is http.MultipartRequest) {
      AppLogger.debug(
        _tag,
        '→ multipart: fields ${request.fields.keys.toList()}, '
        'files ${request.files.map((f) => '${f.filename} (${f.length}B)').toList()}',
      );
    }

    http.StreamedResponse response;
    try {
      response = await _inner.send(request);
    } catch (e, stack) {
      // The request never landed — no DNS, no network, connection refused.
      // Worth its own line: it looks nothing like a 4xx and is fixed nowhere
      // near the same place.
      AppLogger.error(
        _tag,
        '✗ ${request.method} ${request.url} failed after '
        '${DateTime.now().difference(started).inMilliseconds}ms',
        e,
        stack,
      );
      rethrow;
    }

    final ms = DateTime.now().difference(started).inMilliseconds;
    final ok = response.statusCode < 400;
    final line =
        '← ${response.statusCode} ${request.method} ${request.url} (${ms}ms)';
    if (ok) {
      AppLogger.info(_tag, line);
    } else {
      AppLogger.error(_tag, line);
    }

    // The body is a single-subscription stream: reading it here would leave
    // nothing for the caller. So it is buffered and handed on as a fresh
    // stream — the cost of seeing what came back.
    final contentType = response.headers['content-type'];
    if (_isAuthTraffic(request.url)) {
      AppLogger.debug(_tag, '← body <auth, redacted>');
      return response;
    }
    if (!_isPrintable(contentType)) {
      AppLogger.debug(
        _tag,
        '← body <$contentType, ${response.contentLength ?? 0} bytes>',
      );
      return response;
    }

    final bytes = await response.stream.toBytes();
    if (bytes.isNotEmpty) {
      String body;
      try {
        body = utf8.decode(bytes);
      } catch (_) {
        body = '<${bytes.length} bytes, not valid UTF-8>';
      }
      // A failure gets the whole body it is allowed: the message explaining
      // which constraint was violated is the point of reading it at all.
      if (ok) {
        AppLogger.debug(_tag, '← body ${AppLogger.truncate(body)}');
      } else {
        AppLogger.error(_tag, '← body ${AppLogger.truncate(body)}');
      }
    }

    return http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      contentLength: bytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  void _logHeaders(String arrow, Map<String, String> headers) {
    if (headers.isEmpty) return;
    final shown = {
      for (final entry in headers.entries)
        entry.key: _redacted.contains(entry.key.toLowerCase())
            ? '<redacted>'
            : entry.value,
    };
    AppLogger.debug(_tag, '$arrow headers $shown');
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
