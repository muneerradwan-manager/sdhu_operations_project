import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../domain/map_location.dart';

/// Somewhere to go, shown as a way of going there.
///
/// A place is stored as a map URL, and a map URL is not something anybody reads
/// — it is a hundred characters that mean "منى، مخيم ٣٤" to nobody. So it is
/// never printed. It is a button, and pressing it hands the link to whatever
/// the phone opens maps with.
///
/// [dense] is the form for a card that already has a name at the top of it — a
/// tower, a camp — where the place is one more fact about it rather than the
/// subject of the screen.
class LocationButton extends StatelessWidget {
  const LocationButton({
    super.key,
    required this.url,
    this.label,
    this.dense = false,
  });

  /// The stored value: a map URL, or a link an admin pasted.
  final String url;

  /// What the place is called here — "موقع المخيم". Falls back to the general
  /// "open on the map", which is what it does.
  final String? label;

  final bool dense;

  Future<void> _open(BuildContext context) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(url);
    final launched =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.referenceLinkFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = label ?? l.locationOpenMap;

    if (dense) {
      return TextButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(AppIcons.location, size: 16),
        label: Text(text),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          visualDensity: VisualDensity.compact,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _open(context),
      icon: const Icon(AppIcons.location, size: 18),
      label: Text(text),
    );
  }
}

/// Whether [value] is a place worth offering to open.
///
/// A location field holds a URL; an empty one holds nothing, and a value that
/// is not a link at all cannot be launched. Coordinates are NOT required — a
/// shortened `maps.app.goo.gl` link names a place without saying where it is,
/// and opening it still works.
bool isOpenableLocation(Object? value) {
  if (value is! String || value.trim().isEmpty) return false;
  final uri = Uri.tryParse(value.trim());
  return uri != null && uri.hasScheme;
}

/// The coordinates behind a stored place, when it carries them — for the rare
/// screen that wants to SAY where somewhere is rather than offer to go.
String? locationCoordinates(Object? value) {
  final point = MapLocation.parse(value is String ? value : null);
  if (point == null) return null;
  return '${point.latitude.toStringAsFixed(5)}, '
      '${point.longitude.toStringAsFixed(5)}';
}
