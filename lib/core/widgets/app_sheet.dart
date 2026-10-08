import 'package:flutter/material.dart';

/// A modal bottom sheet that clears both things that can sit under it: the
/// keyboard, and the system navigation bar.
///
/// The app draws edge to edge — see `bootstrap.dart`, which asks for
/// [SystemUiMode.edgeToEdge] — so the window extends behind the navigation bar
/// and it is every surface's own job to keep its content off it. Android 15
/// made that non-negotiable: from API 35 the system no longer offers to letter-
/// box an app out of the gesture area, so a sheet that never accounted for the
/// bar simply has its last row drawn underneath it. On a form, the last row is
/// the save button.
///
/// TWO insets, and they are not the same one:
///
///   * [MediaQueryData.viewInsets] is what the KEYBOARD covers. It grows as the
///     keyboard opens and is what lifts the sheet clear of it.
///   * [MediaQueryData.padding] is what the SYSTEM BARS cover — the navigation
///     bar here — and it is what [SafeArea] spends.
///
/// Every sheet in this app already had the first. None of the ones using this
/// helper had the second, which is the whole bug: with the keyboard closed the
/// padding went to zero and the content sat on the bar.
///
/// [SafeArea] rather than `MediaQuery.viewPaddingOf`, which the scrolling pages
/// use through `context.scrollPadding`. The difference only shows when the
/// keyboard is open: `padding` is `viewPadding` minus `viewInsets`, so it falls
/// to zero exactly when the keyboard has already taken that space, while
/// `viewPadding` keeps reporting the bar that is no longer visible. Use the
/// latter here and every sheet with a text field opens a navigation bar's worth
/// of empty space above the keyboard. A page has no such moment, which is why
/// the other convention is right where it is.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showDragHandle = true,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    // The WHOLE window, not the column beside the rail.
    //
    // Under the sidebar arrangement every page lives on the shell's own
    // navigator, and a modal raised on that navigator is bounded by the pane it
    // is in: the scrim stops at the rail, which stays lit and stays tappable. A
    // stray press on a destination then navigates the page out from under an
    // open sheet and leaves it floating over a screen it has nothing to do
    // with. Asking for the root navigator puts the scrim over everything, which
    // is what a modal means.
    //
    // Every other `showModalBottomSheet` in this app says the same thing, and
    // points here for the reason. `showDialog` already defaults to it.
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      // top: false — the sheet is anchored to the bottom of the screen and
      // never reaches the status bar; asking for that inset would push a short
      // sheet's own content down inside it for nothing. Left and right are left
      // on for the phone held sideways, where the bar and the cutout move to
      // the side the sheet does span.
      child: SafeArea(top: false, child: builder(sheetContext)),
    ),
  );
}
