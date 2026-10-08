import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

/// One picture, full screen and zoomable.
///
/// Deliberately not glass and not themed: a photograph is judged against
/// nothing, so the page around it goes black and stays out of the way. It is
/// the same treatment the attachment gallery gives an image, and the one a
/// person coming from any other photo app already expects.
class PhotoViewer extends StatelessWidget {
  const PhotoViewer({super.key, required this.title, required this.url});

  final String title;
  final String url;

  /// Opens [url] on its own page.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String url,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoViewer(title: title, url: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (_, _) =>
                const CircularProgressIndicator(color: Colors.white),
            errorWidget: (_, _, _) => const Icon(
              AppIcons.brokenImage,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
