import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Pass-through. Once faded + slid its child in on first build; now renders it
/// directly.
///
/// The entry animation was wrong for the place it ended up being used most: a
/// list builds its rows lazily, as they scroll into view, so "on first build"
/// meant every row animated in *under the user's thumb* rather than once when
/// the screen arrived. Scrolling read as the list assembling itself item by
/// item instead of moving with the finger.
///
/// Kept as a no-op widget rather than deleted so the ~30 call sites that lean
/// on it — including `const` ones — keep compiling; the parameters are retained
/// and ignored for the same reason.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 450),
    this.offset = const Offset(0, 0.08),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  @override
  Widget build(BuildContext context) => child;
}

/// Pass-through. Once wrapped [children] with an incrementally increasing entry
/// delay; now returns them untouched — see [FadeSlideIn] for why.
List<Widget> staggered(
  List<Widget> children, {
  Duration step = const Duration(milliseconds: 70),
  Duration start = Duration.zero,
  int maxSteps = 8,
}) => children;

const _transitionDuration = Duration(milliseconds: 400);
const _reverseTransitionDuration = Duration(milliseconds: 300);

/// Material fade-through: the outgoing page finishes fading out *before* the
/// incoming one starts fading in.
///
/// The sequencing matters here — every scaffold in this app is transparent so
/// the aurora shows through, and an overlapping cross-fade would briefly show
/// both pages' content stacked on top of each other.
Widget _fadeThroughTransition(
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final fadeIn = CurvedAnimation(
    parent: animation,
    curve: const Interval(0.35, 1, curve: Curves.easeOut),
  );
  final fadeOut = CurvedAnimation(
    parent: secondaryAnimation,
    curve: const Interval(0, 0.35, curve: Curves.easeIn),
  );
  final scale = Tween<double>(begin: 0.97, end: 1).animate(fadeIn);

  return AnimatedBuilder(
    animation: Listenable.merge([fadeIn, fadeOut]),
    builder: (context, child) => Opacity(
      opacity: (fadeIn.value * (1 - fadeOut.value)).clamp(0.0, 1.0),
      child: Transform.scale(scale: scale.value, child: child),
    ),
    child: child,
  );
}

/// Shared fade-through page transition for go_router routes.
///
/// [opaque] is the same door [fadeThroughRoute] has, and it is needed for the
/// same reason: leaving a page transparent only works while the thing BELOW it
/// fades itself out, which is true of one of these pages and of nothing else.
///
/// A route that can be pushed **over the shell** is the case that breaks it.
/// `ShellRoute` is declared with `builder`, not `pageBuilder`, so go_router
/// wraps it in its own default page — which has no secondary animation and
/// simply keeps painting. Over that, a transparent scaffold is the page you
/// left showing straight through the page you opened.
///
/// Marking such a route opaque stops the navigator painting anything below it
/// once it settles. The aurora is mounted in `MaterialApp.builder`, OUTSIDE the
/// navigator, so it still shows through the transparent scaffold and the page
/// looks exactly as it always did.
CustomTransitionPage<T> fadeThroughPage<T>({
  required Widget child,
  required LocalKey key,
  bool opaque = false,
}) {
  return CustomTransitionPage<T>(
    key: key,
    transitionDuration: _transitionDuration,
    reverseTransitionDuration: _reverseTransitionDuration,
    opaque: opaque,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) =>
        _fadeThroughTransition(animation, secondary, child),
  );
}

/// The imperative counterpart, for `Navigator.push` inside a feature.
///
/// Use this instead of [MaterialPageRoute]: the default Material route slides
/// the incoming page across while the outgoing one stays put, which reveals
/// both through the transparent scaffolds.
///
/// [opaque] is what to reach for when the route underneath is not one of these.
/// A page pushed over another page is fine left transparent — the one below
/// fades itself out on its secondary animation, and staying transparent lets
/// the aurora through unbroken. A page pushed over a MODAL BOTTOM SHEET is not:
/// the sheet has no such animation, so it simply stays there, showing through
/// the new page along with its barrier. Marking the route opaque stops the
/// navigator painting anything below it once it settles; the aurora is mounted
/// outside the navigator and still shows through the transparent scaffold.
Route<T> fadeThroughRoute<T>(WidgetBuilder builder, {bool opaque = false}) {
  return PageRouteBuilder<T>(
    transitionDuration: _transitionDuration,
    reverseTransitionDuration: _reverseTransitionDuration,
    opaque: opaque,
    pageBuilder: (context, animation, secondary) => builder(context),
    transitionsBuilder: (context, animation, secondary, child) =>
        _fadeThroughTransition(animation, secondary, child),
  );
}
