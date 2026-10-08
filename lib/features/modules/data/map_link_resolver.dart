import 'package:http/http.dart' as http;

import '../../../core/logging/app_logger.dart';
import '../domain/map_location.dart';

/// Turns a shortened share link into the position it stands for.
///
/// The most natural thing an administrator can do is press Share in Google Maps
/// and paste what he gets. What he gets is `maps.app.goo.gl/XXXX` — a name for a
/// place that does not carry the place. Pasted into this app it read as an empty
/// field, silently, and the camp never appeared on any map.
///
/// The coordinates are one redirect away, so the app follows it. What comes back
/// is `…/maps/search/21.424128,+39.896510?entry=…`, which [MapLocation.parse]
/// now understands — and what is STORED is the app's own canonical `?q=lat,lng`,
/// never Google's URL. Two reasons for that, and the second is the important
/// one: the stored value stops depending on a URL format Google may change, and
/// the database can read the position without following anything, which is what
/// `node_location()` needs to draw the season map.
class MapLinkResolver {
  // Named without the underscore because a private initializing formal would
  // put `_client:` at every call site.
  // ignore: prefer_initializing_formals
  const MapLinkResolver({http.Client? client}) : _client = client;

  /// Injected only by tests. Left null the app opens and closes its own, so a
  /// screen does not have to own a client for one redirect.
  final http.Client? _client;

  /// Follows [url] and returns what it points at, or null.
  ///
  /// Never throws. A resolver that failed loudly would block an administrator
  /// from saving a link he can perfectly well fix by hand, on a network that
  /// may simply be having a bad minute.
  Future<MapLocation?> resolve(String url) async {
    final direct = MapLocation.parse(url);
    if (direct != null) return direct;
    if (!MapLocation.isShortLink(url)) return null;

    final client = _client ?? http.Client();
    try {
      // HEAD rather than GET: the answer is in the redirect chain, and the page
      // behind it is half a megabyte of map application nobody here reads.
      final response = await client
          .head(Uri.parse(url.trim()))
          .timeout(const Duration(seconds: 12));

      // `http` follows redirects itself and reports where it ended up. Some
      // shorteners answer HEAD with a 405 and still send the Location header,
      // so that is read too rather than trusted to one path.
      final landed =
          response.request?.url.toString() ?? response.headers['location'];
      return MapLocation.parse(landed);
    } catch (error) {
      AppLogger.info('map', 'could not resolve $url — $error');
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }
}
