import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/settings/settings_cubit.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/app_shell_scope.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/responsive.dart';
import '../../auth/application/session_cubit.dart';
import 'widgets/app_sidebar.dart';

/// The frame every approved page is drawn inside.
///
/// It is the rail, and the rail OUTLIVES the page: it is built above the
/// shell's navigator, so opening الموظفون replaces what is beside it and leaves
/// the column itself untouched. No rebuild, no re-fold, no scroll position
/// lost.
///
/// There was a second arrangement — a page of tiles — and a setting to choose
/// between them; both are gone. This class used to hand its child straight back
/// under that setting, which is why the frame is still conditional below: not
/// on a preference any more, but on whether there is anybody to draw it for.
///
/// Two consequences follow from that, and both are the point rather than side
/// effects:
///
///   * **There is no back arrow on a page reached from the rail.** The rail
///     navigates with `go` rather than `push`, so those pages are not stacked
///     on top of one another — each one REPLACES the last, the way tabs do.
///     There is nothing to go back to, so nothing draws an arrow promising
///     there is. A page opened from INSIDE another one — an employee from the
///     directory, a file from the list — is still pushed, still keeps its
///     arrow, and now keeps the rail beside it too.
///   * **The system back button has to be answered.** With no stack under it,
///     Android's back gesture on a rail page would leave the app. So it is
///     caught here and spent on returning to the roadmap, which is the one
///     place in this arrangement that reads as "up". From the roadmap itself,
///     back leaves — which is what a person at the top of an app expects.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.location, required this.child});

  /// The path currently shown, for marking the rail's own entry as current.
  final String location;

  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// The scaffold that owns the drawer on a narrow window.
  ///
  /// A key rather than `Scaffold.of`, because the button that opens it lives on
  /// a bar several levels below — inside the page's own Scaffold, which is the
  /// one `Scaffold.of` would find. See [AppShellScope].
  final _shell = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;
    final session = context.watch<SessionCubit>().state;

    // No frame at all on the way in. The splash, the sign-in form and the three
    // "your account is not through yet" screens are whole pages in their own
    // right, and a navigation rail beside a login box is an offer of doors to
    // somebody who has not been let in the building.
    if (session.status != SessionStatus.approved) {
      return widget.child;
    }

    final window = context.windowSize;
    final standing = window.isAtLeast(WindowSize.medium);
    final atHome = widget.location == Routes.home;

    return PopScope(
      // At the roadmap, back means leave — which is what it means at the top of
      // any app. Anywhere else it means "up", and up from a rail page is the
      // page the rail was opened from.
      //
      // A page PUSHED inside the shell — the employee behind the directory — is
      // popped by the shell's own navigator before this is ever consulted, so
      // reading a man's file and pressing back still lands on the directory
      // rather than jumping to the roadmap.
      canPop: atHome,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted) return;
        context.go(Routes.home);
      },
      child: standing
          ? AppShellScope(
              // Nothing to open: it is already open, or folded to its icons and
              // one press from being open again.
              openDrawer: null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StandingRail(
                    session: session,
                    location: widget.location,
                    expanded: settings.sidebarExpanded,
                    onToggle: () => context
                        .read<SettingsCubit>()
                        .setSidebarExpanded(!settings.sidebarExpanded),
                    gutter: window.gutter,
                  ),
                  Expanded(child: widget.child),
                ],
              ),
            )
          : AppShellScope(
              openDrawer: () => _shell.currentState?.openDrawer(),
              child: Scaffold(
                key: _shell,
                // A scaffold with nothing on it but a drawer and the page. It
                // must not paint: every screen in this app is transparent so
                // the aurora shows through, and an opaque sheet here would put
                // a grey card between the backdrop and all forty-nine of them.
                backgroundColor: Colors.transparent,
                // The page inside is the one that has to move for a keyboard —
                // it owns the fields. Both resizing means the inset is taken
                // twice and a form ends up floating above its own footer.
                resizeToAvoidBottomInset: false,
                drawer: SidebarDrawer(
                  session: session,
                  location: widget.location,
                ),
                body: widget.child,
              ),
            ),
    );
  }
}

/// The rail as a drawer, for a window too narrow to stand one.
///
/// Always open — see [AppSidebar.onToggle]. A panel that is already overlaying
/// the page gains nothing by getting narrower, and offering to fold it there
/// would be offering to make the menu harder to read for no room back.
class SidebarDrawer extends StatelessWidget {
  const SidebarDrawer({
    super.key,
    required this.session,
    required this.location,
  });

  final SessionState session;
  final String location;

  @override
  Widget build(BuildContext context) {
    // The system bars' inset, taken OUTSIDE the glass rather than inside it.
    //
    // It was a [SafeArea] wrapped around the sidebar's content, and that kept
    // the tiles clear of the bars while letting the PANE run on underneath
    // them. On a handset with three-button navigation the bar is an opaque
    // strip fifty pixels tall, so the panel arrived at the bottom of the
    // screen, met it, and was cut off square — the rounded corner it is drawn
    // with nowhere on screen. Every other surface in this app ends in that
    // corner, so the one that did not read as broken rather than as deliberate.
    //
    // Insetting the pane instead means the glass stops where the bar starts and
    // finishes its own shape. That is what the standing form has always done —
    // see [StandingRail], where the padding is likewise outside the surface —
    // and the two now agree.
    //
    // `viewPadding`, not `padding`, for the reason given there too: the
    // scaffold that owns this drawer is `resizeToAvoidBottomInset: false`, so
    // the panel keeps its full height with a keyboard up and must keep its full
    // inset with it.
    final insets = MediaQuery.viewPaddingOf(context);

    return Drawer(
      // Material's own panel is taken out entirely and the app's glass put in
      // its place: an opaque grey sheet sliding over the aurora is the one
      // surface in this app that would not belong to it.
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      // The side inset is ADDED to the width rather than taken out of it, so
      // the glass keeps [kRailExpandedWidth] whatever the bars are doing. A
      // panel narrowed by a navigation bar starts ellipsising the longer names,
      // which is the one thing that width was chosen to avoid.
      //
      // Scaffold has already zeroed the padding on the side this drawer is not
      // touching, so this is the one edge against the screen and not both.
      width: kRailExpandedWidth + AppSpacing.lg + insets.horizontal,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          insets.left + AppSpacing.sm,
          insets.top + AppSpacing.sm,
          insets.right + AppSpacing.sm,
          insets.bottom + AppSpacing.sm,
        ),
        child: GlassSurface(
          radius: AppRadius.lg,
          // Blurred and dense, unlike the standing rail: this one is over the
          // page rather than beside it, and whatever it is covering has to stop
          // being readable through it.
          strong: true,
          child: AppSidebar(
            session: session,
            location: location,
            expanded: true,
            onNavigate: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}
