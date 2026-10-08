import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
// `hide TextDirection`: intl ships a class of that name — its own two-value
// enum for laying out a formatted string — and it is not Flutter's. Imported
// plainly it shadows the one `Directionality.of` returns, and the rail's side
// inset below stops compiling for want of `.rtl`.
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/utils/hijri_utils.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../auth/application/session_cubit.dart';
import '../../domain/home_destinations.dart';
import 'home_pieces.dart';

/// The rail folded down to nothing but its icons.
///
/// 76 is not a round number chosen for looking right. A tile's hit target is
/// the 24-pixel glyph plus the padding around it, and the padding has to be
/// even on both sides or the icons sit off-centre in the column — which is the
/// one thing a reader notices instantly in a vertical strip. 76 = 8 (the tile's
/// own margin) + 18 + 24 + 18 + 8, and the 18 is what the tile's horizontal
/// padding animates TO when it closes.
const kRailCollapsedWidth = 76.0;

/// The rail standing open.
///
/// Wider than [kSidePanelWidth]'s 320 would be excessive and narrower than 260
/// starts ellipsising the longer names — "إدارة الملفات التشغيلية" and
/// "القرارات والتعميمات" are the two that decide this number, and both fit at
/// 288 with the compose button still on the line.
const kRailExpandedWidth = 288.0;

/// How long the fold takes, and the shape of it.
///
/// One duration and one curve for the width, the paddings and the labels'
/// opacity, because they are three implicit animations of the same gesture: run
/// them on different curves and the labels arrive after the column has stopped
/// moving, which reads as the rail stuttering rather than opening.
const _fold = Duration(milliseconds: 220);
const _curve = Curves.easeOutCubic;

/// The tile's inset when open and when closed — see [kRailCollapsedWidth] for
/// where the second number comes from.
///
/// Both are one pixel short of the round numbers they look like they should be,
/// and the missing pixel is [_border]. A tile draws its outline whether or not
/// it is the current one — transparent when it is not, so that becoming current
/// does not shift the label sideways by two pixels — and `Border.all` is one
/// pixel of real geometry on each side either way. Left out of the arithmetic,
/// the folded rail hands its 24-pixel glyph a 22-pixel box and paints a
/// yellow-and-black stripe down the whole column.
const _padOpen = 13.0;
const _padShut = 17.0;

/// The tile's own margin off the rail's edges.
const _tileMargin = AppSpacing.sm;

/// The tile's outline, drawn at every state — see [_padOpen].
const _border = 1.0;

/// What the label is laid out at, whatever the rail's current width.
///
/// Fixed, and that is the trick the whole fold rests on. The label lives in an
/// [OverflowBox] pinned to this width inside a [ClipRect]: the row never
/// re-flows, never re-wraps and never overflows — it is simply revealed, the
/// way a drawer reveals what is in it. Laid out at the live width instead, the
/// text would re-break on every frame of the animation and the last few frames
/// would be a `RenderFlex overflowed` stripe.
const _labelWidth =
    kRailExpandedWidth -
    _tileMargin * 2 -
    _border * 2 -
    _padOpen * 2 -
    _iconBox;

const _iconBox = 24.0;

/// The standing column of doors: everything the home page can open, in one
/// place, folded to icons or open with its labels.
///
/// It draws from the same catalogue the grid of tiles draws from — see
/// [homeDestinations] — so a permission that hides a tile hides a rail entry by
/// construction rather than by two people remembering to make the same edit.
///
/// It is built by [AppShell], ABOVE the navigator every page lives on, so
/// opening a section swaps what is beside the column and leaves the column
/// itself alone — no rebuild, no re-fold, no scroll position lost.
///
/// And it navigates by REPLACING rather than stacking. Its entries are peers:
/// going from الملفات to الموظفون is not going deeper, so nothing is left
/// underneath and nothing draws a back arrow promising there is. Details opened
/// from inside a page still push, still stack, and still keep their arrow —
/// which is exactly the line between a destination and a detail.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.session,
    required this.location,
    required this.expanded,
    this.onToggle,
    this.onNavigate,
  });

  final SessionState session;

  /// The path currently on screen beside this column.
  ///
  /// It is what makes the rail a rail rather than a menu: exactly one entry is
  /// drawn as current at any moment, and a reader who has been three pages deep
  /// can look left and see where he is without reading a title.
  final String location;

  /// Whether the labels are showing. Always true in the drawer — see
  /// [onToggle].
  final bool expanded;

  /// Folds and unfolds. Null inside the drawer on a narrow window: a panel that
  /// is already overlaying the page has nothing to gain by getting narrower,
  /// and a fold control there would offer to make the menu harder to read.
  final VoidCallback? onToggle;

  /// Called after a destination is chosen — how the drawer closes itself behind
  /// the reader. Null for the standing rail, which does not go anywhere.
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final profile = session.profile;
    final destinations = homeDestinations(session, l);
    final shelves = homeShelves(destinations);

    // `go`, not `push`, and this one line is what makes the whole arrangement
    // work. A rail's destinations are peers: opening الموظفون from الملفات is
    // not going deeper, it is going ELSEWHERE, and stacking them means a reader
    // who has looked at six sections has six pages under him and six presses of
    // back to get out. Replacing means there is nothing to go back to, which is
    // why no page reached from this column draws a back arrow.
    //
    // Anything opened from INSIDE a page still pushes — the employee behind the
    // directory, the file behind the list — and still keeps its arrow. The
    // difference is exactly the difference between a destination and a detail.
    void go(String route) {
      onNavigate?.call();
      context.go(route);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Whose app this is, what day it is, and the way to fold the column —
        // one block, on two lines.
        _RailHeader(expanded: expanded, onToggle: onToggle),
        // Who is signed in, and the way to their own page. Directly under the
        // header, because it answers the question a shared handset raises
        // before any other — whose account is this? — and because the face is
        // the one thing in this column that is still recognisable when the
        // labels are folded away.
        _RailProfile(
          photoUrl: profile?.photoUrl,
          name: profile?.firstName ?? l.navMyProfile,
          jobTitle: profile?.jobTitleName?.of(context) ?? l.navMyProfile,
          expanded: expanded,
          selected: location == Routes.myProfile,
          onTap: () => go(Routes.myProfile),
        ),
        const _RailDivider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            children: [
              // The way home. It heads the column rather than sitting with the
              // shelves because it is not one of them — the others are places
              // to go and this is the place they are all drawn on.
              _RailTile(
                leading: const Icon(AppIcons.roadmap, size: 20),
                label: l.roadmapTitle,
                tooltip: l.roadmapIntroTitle,
                color: scheme.primary,
                selected: location == Routes.home,
                expanded: expanded,
                onTap: () => go(Routes.home),
              ),
              for (final shelf in shelves) ...[
                _RailGroupLabel(
                  title: shelf.group.title(l),
                  color: shelf.group.accent.of(context),
                  expanded: expanded,
                ),
                for (final destination in shelf.destinations)
                  _RailTile(
                    leading: Icon(destination.icon, size: 20),
                    label: destination.title,
                    tooltip: destination.subtitle,
                    color: destination.colorOf(context),
                    expanded: expanded,
                    // Matched exactly, never by prefix — the same rule the
                    // route guards are written by. `/modules/manage` starts
                    // with `/modules`, and a prefix match would light both the
                    // office's entry and the member's whenever either was open.
                    selected: location == destination.route,
                    onTap: () => go(destination.route),
                    // The compose action, kept on the rail rather than dropped
                    // from it. "مهمة جديدة" is one of the three things anybody
                    // does most often in this app, and a menu that can open the
                    // list but not write on it sends the reader through two
                    // screens to reach what the grid gave them in one tap.
                    //
                    // It goes when the rail folds, and that is not a loss: the
                    // list it opens carries the same button, one tap further.
                    action: destination.action == null
                        ? null
                        : () => go(destination.action!),
                    actionLabel: destination.actionLabel,
                    actionIcon: destination.actionIcon ?? AppIcons.add,
                  ),
              ],
            ],
          ),
        ),
        const _RailDivider(),
        // The foot of the column: how this device behaves, and the way out of
        // it. Settings is the one door here that is about the app rather than
        // about the mission, which is why it stands apart from the shelves
        // instead of being given a shelf of its own.
        _RailTile(
          leading: const Icon(AppIcons.settings, size: 20),
          label: l.commonSettings,
          tooltip: l.commonSettings,
          expanded: expanded,
          selected: location == Routes.settings,
          onTap: () => go(Routes.settings),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

/// The rail, wrapped in its own pane and given the room the app bar is standing
/// in — the standing form, for a window wide enough to keep it open beside the
/// page.
class StandingRail extends StatelessWidget {
  const StandingRail({
    super.key,
    required this.session,
    required this.location,
    required this.expanded,
    required this.onToggle,
    required this.gutter,
  });

  final SessionState session;
  final String location;
  final bool expanded;
  final VoidCallback onToggle;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    // The window's own system bars, and nothing else. The rail stands OUTSIDE
    // the page's scaffold now — beside it rather than under its bar — so it
    // runs from the top of the glass to the bottom while each page's own bar
    // spans only the column it belongs to. That is the shape every desktop
    // application with a rail has: the navigation is the frame, and the header
    // belongs to what is framed.
    //
    // `viewPadding` on every side, never `padding`. The two are the same number
    // until a keyboard is up, and then `padding` reports ZERO at the bottom
    // because the keyboard is already covering that strip. This column does not
    // move for a keyboard — the page beside it owns the fields — so taking the
    // zero would drop its foot under the navigation bar for as long as somebody
    // is typing.
    final insets = MediaQuery.viewPaddingOf(context);
    final top = insets.top + AppSpacing.md;
    final bottom = insets.bottom + AppSpacing.md;

    // The system bar's SIDE inset, on whichever edge this column is standing.
    //
    // Android 15 draws its bars over the app and no longer offers to reserve
    // room, so in landscape — which is 600 pixels wide or more, and therefore
    // exactly where this standing form is used — the navigation bar is a
    // vertical strip pinned to one long edge. In Arabic the rail stands on the
    // right and so, on a handset rotated clockwise, does the strip. [gutter] is
    // 24 pixels against the 48 that strip takes: without this the fold button,
    // the mark and the whole column of glyphs sit underneath it.
    //
    // The rail is the Row's first child, so it is on the START side — the right
    // in Arabic, the left in English — which is why the inset taken is chosen
    // by direction rather than named.
    final side = Directionality.of(context) == TextDirection.rtl
        ? insets.right
        : insets.left;

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(gutter + side, top, 0, bottom),
      child: AnimatedContainer(
        duration: _fold,
        curve: _curve,
        width: expanded ? kRailExpandedWidth : kRailCollapsedWidth,
        child: GlassSurface(
          radius: AppRadius.lg,
          // No backdrop blur: nothing scrolls under this pane. The page beside
          // it has its own column and passes it by, so the save-layer would be
          // paid on every frame of every scroll for a picture identical to not
          // having asked. See [GlassCard.blur].
          blur: false,
          child: AppSidebar(
            session: session,
            location: location,
            expanded: expanded,
            onToggle: onToggle,
          ),
        ),
      ),
    );
  }
}

/// The head of the column: whose app this is, what day it is, and the control
/// that folds the whole thing away.
///
/// It replaces three separate things that used to be stacked here — a fold
/// button alone on a row of its own, the profile drawn as one more navigation
/// tile, and two full-size date badges one above the other. Together they spent
/// 178 pixels before a single destination appeared and read as three unrelated
/// fragments; nothing about the arrangement said "this is the top of a panel".
///
/// One block instead: the mark and the name on the first line, today's Hijri
/// date on the second, and the fold control at the far edge where every panel
/// in the world keeps it. The profile follows as a card of its own, which is
/// what it always was — a person, not a destination.
///
/// The Gregorian date is in the tooltip rather than on the strip. Both dates on
/// one line is 31 characters into 160 pixels, and the pair that survives an
/// ellipsis is the wrong one: the mission runs on the Hijri calendar and every
/// form outside it wants the other, so the one that is CONSULTED stays visible
/// and the one that is TRANSCRIBED is a hover away.
class _RailHeader extends StatelessWidget {
  const _RailHeader({required this.expanded, this.onToggle});

  final bool expanded;

  /// Null inside the drawer — see [AppSidebar.onToggle]. The header then has no
  /// control on it and the name takes the room the button would have stood in.
  final VoidCallback? onToggle;

  /// The width kept clear at the end of the strip for the fold button.
  ///
  /// The button is a [_RailFoldButton] with its own square target and is drawn
  /// OVER this row rather than inside it, because it has to be able to move to
  /// the centre of a 76-pixel column while the row it sits on fades out. A
  /// reserved gap is how the name knows not to run underneath it.
  static const _controlGap = 44.0;

  static const _height = 64.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // The language the reader chose, not the device's — the app carries its own
    // locale, and a phone set to English with the app set to Arabic must not
    // print half the pair in each.
    final language = Localizations.localeOf(context).languageCode;

    // Read at build time rather than held in state: a rail is rebuilt on every
    // session change and every theme flip, and a date captured once in
    // initState is, for a phone left running on a bedside table in Mina,
    // yesterday.
    final hijri = l.homeHijriDate(HijriUtils.todayInWords(language));
    final gregorian = l.homeGregorianDate(
      // `d MMMM y`, not the numeric form: the line above spells its month out,
      // and "ذو الحجة" against "2026-08-04" is two habits of writing in one
      // tooltip.
      DateFormat('d MMMM y', language).format(DateTime.now()),
    );

    final brand = Padding(
      // The same inset the tiles' glyphs stand at, so the mark heads the column
      // of icons under it rather than floating beside it.
      padding: const EdgeInsets.symmetric(
        horizontal: _tileMargin + _border + _padOpen,
      ),
      child: Row(
        children: [
          // A mark, not the lockup: [AppLogo] carries a wordmark that stops
          // being readable below 96 pixels and asserts as much, and a medallion
          // is what the rest of this app uses wherever something small has to
          // stand for something.
          IconMedallion(
            icon: AppIcons.organization,
            color: scheme.primary,
            size: 34,
            iconSize: 18,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.appTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hijri,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onToggle != null) const SizedBox(width: _controlGap),
        ],
      ),
    );

    return Tooltip(
      message: '$hijri\n$gregorian',
      child: SizedBox(
        height: _height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Laid out at the open width and revealed, never re-flowed — the
            // same trick every label in this rail rests on. See [_labelWidth].
            ClipRect(
              child: OverflowBox(
                alignment: AlignmentDirectional.centerStart,
                minWidth: kRailExpandedWidth,
                maxWidth: kRailExpandedWidth,
                child: AnimatedOpacity(
                  duration: _fold,
                  curve: _curve,
                  opacity: expanded ? 1 : 0,
                  // Nothing in the strip is pressable, and folded it is
                  // invisible — an `Opacity` of zero still takes taps, and a
                  // 76-pixel column whose header swallows presses aimed at the
                  // fold button is the one bug this arrangement could produce.
                  child: IgnorePointer(child: brand),
                ),
              ),
            ),
            if (onToggle case final toggle?)
              AnimatedAlign(
                duration: _fold,
                curve: _curve,
                // Hard against the far edge when open, dead centre when shut —
                // the second is the only position that works in a 76-pixel
                // column, and the first is where every panel in the world keeps
                // this control.
                alignment: expanded
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.center,
                child: Padding(
                  padding: expanded
                      ? const EdgeInsetsDirectional.only(end: AppSpacing.sm)
                      : EdgeInsets.zero,
                  child: _RailFoldButton(expanded: expanded, onToggle: toggle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The control that folds the rail, drawn as a switch ON the panel rather than
/// as an arrow pointing at it.
///
/// It used to be a chevron, and a chevron here was one arrow too many. The
/// account block sits sixty pixels under this button and ends in a
/// [NavChevron]; two arrows that close together in one narrow column read as
/// the same offer repeated, when they are not the same offer at all — one says
/// "this opens your page" and the other said "this shuts the panel". The
/// duplicate is the thing the eye catches, and after that neither one means
/// anything.
///
/// So this one no longer points. The glyph is [AppIcons.layoutSidebar] — the
/// mark this app already spends on the rail itself — and it is the SAME glyph
/// in both states; what moves is the wash behind it, pressed in while the panel
/// stands open and bare once it is folded, which is how a toggle has always
/// said which way it is thrown. That also settles an older oddity: the control was a
/// hamburger when shut and a chevron when open, two unrelated glyphs for one
/// button, so a reader who folded the rail was not looking at the same control
/// he had just pressed.
///
/// Side-neutral by construction, which matters more here than anywhere else in
/// the rail: [AppIcons.layoutSidebar] is a plain vertical split, so it neither
/// names an edge nor needs mirroring when the app turns around into Arabic.
class _RailFoldButton extends StatelessWidget {
  const _RailFoldButton({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  /// Forty, not the [IconButton] default of forty-eight: the strip reserves
  /// [_RailHeader._controlGap] for this control, and forty plus the end inset
  /// is the largest square that keeps the app's name clear of it while staying
  /// a comfortable target.
  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: expanded ? l.sidebarCollapse : l.sidebarExpand,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: () {
            HapticFeedback.selectionClick();
            onToggle();
          },
          child: AnimatedContainer(
            // The same 220ms the column itself folds in, so the button lights
            // and dims WITH the panel instead of snapping ahead of it.
            duration: _fold,
            curve: _curve,
            width: _size,
            height: _size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              // Ink, not the accent. In this column a primary wash means one
              // thing only — you are HERE — and it is spent on the current
              // destination and on nothing else; a fold button glowing in the
              // same colour would put a second candidate at the top of the
              // rail every time it stood open. A neutral wash still reads as
              // pressed-in without claiming to be a place.
              color: expanded
                  ? scheme.onSurface.withValues(alpha: 0.07)
                  : Colors.transparent,
            ),
            // The glyph's own colour, tweened alongside the wash rather than
            // swapped: the box above can animate its fill but not its child's
            // ink, and an icon that snaps on the first frame of a 220ms fold is
            // the one part of this that would still read as a switch thrown by
            // somebody else.
            child: TweenAnimationBuilder<Color?>(
              duration: _fold,
              curve: _curve,
              tween: ColorTween(
                end: expanded ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
              builder: (context, color, _) =>
                  Icon(AppIcons.layoutSidebar, size: 20, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// Who is signed in, drawn as a card rather than as one more entry in the list.
///
/// It used to be a [_RailTile] with an avatar where its glyph goes, which made
/// the person indistinguishable from a place to go: same height, same hover,
/// same wash when current — the first row of a menu happening to have a face on
/// it. A rail's own account block is a different KIND of thing from its
/// destinations, and on every panel that has one it is drawn as one.
///
/// It keeps the tiles' arithmetic exactly — [_padOpen], [_padShut] and
/// [_iconBox] — so the face lands on the same x as every glyph below it, open
/// or shut. What changes is the surface it stands on and the chevron at the
/// end, which is what says "this opens your own page" rather than "this is
/// where you are".
class _RailProfile extends StatelessWidget {
  const _RailProfile({
    required this.photoUrl,
    required this.name,
    required this.jobTitle,
    required this.expanded,
    required this.selected,
    required this.onTap,
  });

  final String? photoUrl;
  final String name;
  final String jobTitle;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Tooltip(
      message: expanded ? l.navMyProfile : '$name — ${l.navMyProfile}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _tileMargin,
          AppSpacing.sm,
          _tileMargin,
          AppSpacing.sm,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: AnimatedContainer(
              duration: _fold,
              curve: _curve,
              height: 60,
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? _padOpen : _padShut,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                // The wash is spent on BEING CURRENT and on nothing else, in
                // this block as in every tile below it. A resting fill here
                // would have made the account block the second-loudest thing in
                // the column at all times, and a reader glancing down for where
                // he is would find two candidates. What separates this from a
                // destination is its outline, its two lines and its chevron —
                // none of which move when the selection does.
                color: selected
                    ? scheme.primary.withValues(alpha: 0.16)
                    : Colors.transparent,
                border: Border.all(
                  width: _border,
                  color: selected
                      ? scheme.primary.withValues(alpha: 0.30)
                      : scheme.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              child: Row(
                children: [
                  // Radius 12, because [_iconBox] is 24: the face stands in the
                  // same box every glyph below it stands in, so the folded
                  // column is one straight run of marks rather than a face
                  // bulging out of the line.
                  SizedBox(
                    width: _iconBox,
                    height: _iconBox,
                    child: Center(
                      child: ProfileAvatar(
                        photoUrl: photoUrl,
                        name: name,
                        radius: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: AlignmentDirectional.centerStart,
                        minWidth: _labelWidth,
                        maxWidth: _labelWidth,
                        child: AnimatedOpacity(
                          duration: _fold,
                          curve: _curve,
                          opacity: expanded ? 1 : 0,
                          child: Row(
                            children: [
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.bodyMedium?.copyWith(
                                        color: scheme.onSurface,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      jobTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.labelSmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const NavChevron(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The name of one shelf inside the rail — or, folded, the hairline that stands
/// in for it.
///
/// Both are drawn at once and cross-faded rather than swapped, because the
/// swap has to happen DURING the fold: `expanded` flips on the first frame of
/// a 220ms animation, and a widget exchanged on that frame pops in at a width
/// that has not moved yet.
class _RailGroupLabel extends StatelessWidget {
  const _RailGroupLabel({
    required this.title,
    required this.color,
    required this.expanded,
  });

  final String title;
  final Color color;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Room for two lines of the name — see [ShelfHeader.compact]. A shelf in
      // a column cannot always say itself in one, and the sixty pixels this
      // costs across the whole rail buy back four headings that would otherwise
      // end in an ellipsis.
      height: 52,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AnimatedOpacity(
              duration: _fold,
              curve: _curve,
              opacity: expanded ? 0 : 1,
              child: Container(
                width: 22,
                height: 1,
                color: color.withValues(alpha: 0.4),
              ),
            ),
          ),
          ClipRect(
            child: OverflowBox(
              alignment: AlignmentDirectional.centerStart,
              minWidth: kRailExpandedWidth,
              maxWidth: kRailExpandedWidth,
              child: AnimatedOpacity(
                duration: _fold,
                curve: _curve,
                opacity: expanded ? 1 : 0,
                child: Padding(
                  // The same inset the tiles' glyphs stand at, so the shelf's
                  // coloured bar lines up with the column of icons under it.
                  padding: const EdgeInsets.symmetric(
                    horizontal: _tileMargin + _border + _padOpen,
                  ),
                  child: ShelfHeader(title: title, color: color, compact: true),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailDivider extends StatelessWidget {
  const _RailDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: AppSpacing.md,
      endIndent: AppSpacing.md,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.45),
    );
  }
}

/// One line of the rail: a mark that never moves, and a label that is revealed
/// beside it.
///
/// The icon is the anchor of the whole idea. It has to land on exactly the same
/// x as the icon above it and below it, open or shut, or the folded rail reads
/// as a ragged column rather than as one control — which is why the padding is
/// animated rather than the icon being centred inside a flexible box.
class _RailTile extends StatelessWidget {
  const _RailTile({
    required this.leading,
    required this.label,
    required this.expanded,
    required this.onTap,
    this.tooltip,
    this.color,
    this.selected = false,
    this.action,
    this.actionLabel,
    this.actionIcon,
  });

  final Widget leading;
  final String label;

  /// What a pointer is told, and what is read aloud. It carries the label
  /// itself when the rail is folded, because then there is nothing else to go
  /// on; open, it carries the one-line explanation the grid prints under the
  /// title and this column has no room for.
  final String? tooltip;

  final Color? color;
  final bool selected;

  /// Whether the label beside the mark is showing.
  final bool expanded;

  final VoidCallback onTap;

  final VoidCallback? action;
  final String? actionLabel;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tone = color ?? scheme.onSurfaceVariant;
    // One line, always. The two-line variant left with the profile, which is
    // now a card of its own — and a rail of two-line entries is a list, not a
    // rail.
    const height = 46.0;

    final body = Row(
      children: [
        SizedBox(
          width: _iconBox,
          height: _iconBox,
          child: Center(
            child: IconTheme.merge(
              data: IconThemeData(color: tone),
              child: leading,
            ),
          ),
        ),
        // The label, laid out at a width that never changes and clipped to
        // whatever the rail currently is — see [_labelWidth].
        Expanded(
          child: ClipRect(
            child: OverflowBox(
              alignment: AlignmentDirectional.centerStart,
              minWidth: _labelWidth,
              maxWidth: _labelWidth,
              child: AnimatedOpacity(
                duration: _fold,
                curve: _curve,
                opacity: expanded ? 1 : 0,
                child: Row(
                  children: [
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(
                          color: selected ? tone : scheme.onSurface,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (action case final act?)
                      IconButton(
                        tooltip: actionLabel,
                        onPressed: expanded ? act : null,
                        icon: Icon(actionIcon, size: 18),
                        color: tone,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 34,
                          height: 34,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _tileMargin, vertical: 2),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: _fold,
            curve: _curve,
            height: height,
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? _padOpen : _padShut,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              // Current is drawn as a wash in the entry's own colour rather
              // than as a bar down the edge: a bar has to pick a side, and this
              // rail stands on the right half the time.
              color: selected
                  ? tone.withValues(alpha: 0.16)
                  : Colors.transparent,
              // Drawn at every state, transparent when the tile is not the
              // current one: an outline that appears only on selection would
              // push the label two pixels sideways as the reader moves down the
              // column. Its width is spent in [_padOpen] and [_padShut].
              border: Border.all(
                width: _border,
                color: selected
                    ? tone.withValues(alpha: 0.30)
                    : Colors.transparent,
              ),
            ),
            child: body,
          ),
        ),
      ),
    );

    final message = expanded ? (tooltip ?? label) : label;
    return Tooltip(message: message, child: tile);
  }
}
