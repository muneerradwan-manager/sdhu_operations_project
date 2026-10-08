import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../auth/application/session_cubit.dart';

/// Shown while the session is being resolved at startup: the brand mark rises
/// into place over the aurora, with an indeterminate bar rather than a spinner
/// so the wait reads as progress.
///
/// If resolving fails — no network, server unreachable — the bar gives way to
/// a retry button. Without it a dead connection at launch left this screen up
/// forever with nothing to tap.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = context.select<SessionCubit, bool>(
      (c) => c.state.loadFailed,
    );

    return Scaffold(
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 18),
              child: Transform.scale(scale: 0.88 + 0.12 * t, child: child),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 44,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: const AppLogo(size: 140),
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (failed) ...[
                Text(
                  context.l10n.commonConnectionErrorTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  context.l10n.commonConnectionErrorBody,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                // Same fight as EmptyState's action: the theme hands buttons
                // an infinite minimum width, and with nothing between this
                // column and the window edge, "retry" would span the monitor.
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 200),
                  child: IntrinsicWidth(
                    child: FilledButton.icon(
                      onPressed: () => context.read<SessionCubit>().reload(),
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.commonRetry),
                    ),
                  ),
                ),
              ] else
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: scheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
