import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/animations/animations.dart';
import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/blocking_progress.dart';
import '../../../../core/widgets/glass.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/widgets/settings_menu_button.dart';

/// Centred informational screen (pending / rejected / suspended): a pulsing
/// status medallion inside one glass pane, so the message reads as a single
/// calm statement rather than scattered text.
class StatusScaffold extends StatelessWidget {
  const StatusScaffold({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.detail,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        automaticallyImplyLeading: false,
        actions: const [SettingsMenuButton()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: staggered([
                  GlassCard(
                    radius: AppRadius.xl,
                    tint: iconColor,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xxl,
                      AppSpacing.xl,
                      AppSpacing.xl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PulseIcon(icon: icon, color: iconColor),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          title,
                          style: text.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          message,
                          style: text.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (detail != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: scheme.error.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: scheme.error.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              detail!,
                              style: text.bodyMedium?.copyWith(
                                color: scheme.error,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        if (action != null) ...[
                          const SizedBox(height: AppSpacing.xl),
                          SizedBox(width: double.infinity, child: action!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextButton.icon(
                    onPressed: () => runBlocking(
                      context,
                      context.read<AuthRepository>().signOut,
                      message: l.commonLoggingOut,
                    ),
                    icon: const Icon(AppIcons.logout, size: 18),
                    label: Text(l.commonLogout),
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Concentric halos that breathe outward from the status icon.
class _PulseIcon extends StatefulWidget {
  const _PulseIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Two rings offset by half a cycle give a continuous ripple.
              for (final offset in const [0.0, 0.5])
                _ring((_c.value + offset) % 1.0),
              child!,
            ],
          );
        },
        child: GlassSurface(
          radius: AppRadius.pill,
          width: 84,
          height: 84,
          child: Icon(widget.icon, size: 36, color: widget.color),
        ),
      ),
    );
  }

  Widget _ring(double t) {
    final eased = Curves.easeOut.transform(t);
    return Opacity(
      opacity: (1 - eased) * 0.5,
      child: Container(
        width: 84 + 48 * eased,
        height: 84 + 48 * eased,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.color.withValues(alpha: 0.6),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}
