import 'package:flutter/material.dart';

import '../l10n/l10n_extension.dart';
import '../theme/glass_tokens.dart';
import 'glass.dart';

/// Runs [action] behind a barrier that takes every touch and gives none back.
///
/// For the operations that end the screen you are standing on — signing out
/// above all. Awaiting one of those with the interface still live means the
/// seconds between the tap and the server's answer are seconds in which
/// somebody can open a file, send a notification, or press the button again;
/// and then the session goes out from under whatever they started. What looked
/// like a slow button was really an unattended app.
///
/// The barrier is a route, so the system back button cannot get behind it
/// either, and it is removed by identity in a `finally` — never by popping
/// "whatever is on top", which by then may be something else entirely.
Future<T> runBlocking<T>(
  BuildContext context,
  Future<T> Function() action, {
  String? message,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) => PopScope(
      canPop: false,
      child: Center(child: _BlockingCard(message: message)),
    ),
  );

  navigator.push(route);
  try {
    return await action();
  } finally {
    if (route.isActive) navigator.removeRoute(route);
  }
}

class _BlockingCard extends StatelessWidget {
  const _BlockingCard({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final label = message ?? context.l10n.commonLoading;

    return GlassSurface(
      strong: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
