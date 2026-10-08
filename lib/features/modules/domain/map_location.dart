/// A point on the ground, kept as the map URL that names it.
///
/// The stored value stays a plain URL string — that is what the admin pastes
/// when they already have a link, what "open location" launches, and what was
/// already in the column before pins and GPS existed. Coordinates are read back
/// out of the URL when it carries them, so reopening the picker lands on the
/// pin the admin last dropped instead of on a default city.
class MapLocation {
  const MapLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  /// The `?q=lat,lng` form: understood by Google Maps, and by every other maps
  /// app that registers for map links.
  String get url =>
      'https://www.google.com/maps?q=${_trim(latitude)},${_trim(longitude)}';

  /// Six decimals is roughly 10 cm — far past what a dropped pin means.
  static String _trim(double value) =>
      value.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

  /// Pulls coordinates out of a map URL.
  ///
  /// Three shapes, and the third was missing for a long time in a way nobody
  /// could see:
  ///
  ///   * `?q=lat,lng` — what this app writes, and what most maps apps take.
  ///   * `@lat,lng` — the form in a Google URL copied from the address bar.
  ///   * `/maps/search/lat,+lng` — **what a shortened share link actually
  ///     resolves to**. It is in the PATH rather than a parameter, and it puts
  ///     a `+` after the comma. Neither of the two above matches it, so every
  ///     link an administrator produced with Google's own share button read as
  ///     "no position" — silently, since a null here is indistinguishable from
  ///     a field nobody filled in.
  ///
  /// Returns null for a link that names a place without saying where it is. A
  /// `maps.app.goo.gl` link is exactly that and CANNOT be read offline: the
  /// coordinates are on the other side of a redirect. [isShortLink] recognises
  /// one so a caller can resolve it rather than treat it as empty.
  static MapLocation? parse(String? url) {
    if (url == null || url.isEmpty) return null;

    const pair = r'(-?\d{1,3}(?:\.\d+)?)\s*,\s*\+?\s*(-?\d{1,3}(?:\.\d+)?)';
    final match =
        RegExp('[?&](?:q|query|ll|center)=$pair').firstMatch(url) ??
        RegExp('@$pair').firstMatch(url) ??
        RegExp('/(?:maps/)?(?:search|place|dir)/$pair').firstMatch(url);
    if (match == null) return null;

    final lat = double.tryParse(match.group(1)!);
    final lng = double.tryParse(match.group(2)!);
    if (lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return MapLocation(latitude: lat, longitude: lng);
  }

  /// Whether this is a shortened share link — a name for a place that does not
  /// carry the place.
  ///
  /// Worth telling apart from "no link at all", because the two want opposite
  /// things from the app: nothing to do about an empty field, and one redirect
  /// to follow for this.
  static bool isShortLink(String? url) {
    if (url == null) return false;
    final text = url.trim().toLowerCase();
    return text.contains('maps.app.goo.gl') || text.contains('goo.gl/maps');
  }
}
