import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Circular avatar that loads a network photo with a graceful initials fallback.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.photoUrl, this.name, this.radius = 26});

  final String? photoUrl;
  final String? name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = _initials(name);

    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        initials,
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
        ),
      ),
    );

    if (photoUrl == null || photoUrl!.isEmpty) return fallback;

    // Decoded at the size it will actually be drawn. A profile photo comes off
    // a phone camera at a few thousand pixels a side; held in memory whole,
    // that is megabytes per face for something painted into a circle a
    // centimetre wide — and a texture that large has to be sampled down again
    // on every frame it scrolls through.
    //
    // Width only, not both: giving `instantiateImageCodec` a target width AND
    // height stretches the source to fit them exactly, which would distort a
    // photo that is not square. Constraining the width keeps the aspect ratio
    // and is what caps the decode.
    final decodeWidth = (radius * 2 * MediaQuery.devicePixelRatioOf(context))
        .round();

    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.surfaceContainerHighest,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: photoUrl!,
          width: radius * 2,
          height: radius * 2,
          memCacheWidth: decodeWidth,
          fit: BoxFit.cover,
          placeholder: (_, _) => const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (_, _, _) => fallback,
        ),
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '؟';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1);
    return parts.first.substring(0, 1) + parts[1].substring(0, 1);
  }
}
