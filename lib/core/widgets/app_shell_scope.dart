import 'package:flutter/material.dart';

/// What the standing shell offers to every page inside it.
///
/// It exists for one thing that cannot be passed down any other way: on a
/// window too narrow to stand the rail open, the rail becomes a drawer — and a
/// drawer needs a button, on the bar of whatever page happens to be open. That
/// bar belongs to the page's own [Scaffold], several levels below the shell's,
/// so `Scaffold.of` finds the wrong one and `hasDrawer` is false.
///
/// So the shell publishes the handle instead. [GlassAppBar] asks for it, and
/// draws the menu button when there is a drawer to open and nothing to go back
/// to — which is exactly when a page reached from the rail needs one.
///
/// Absent above the login and splash screens, and absent under the grid
/// arrangement: `maybeOf` returning null means "there is no shell here", and
/// every bar behaves as it always did.
class AppShellScope extends InheritedWidget {
  const AppShellScope({
    super.key,
    required this.openDrawer,
    required super.child,
  });

  /// Opens the rail's drawer. Null where the rail is standing open already and
  /// there is nothing to open.
  final VoidCallback? openDrawer;

  static AppShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppShellScope>();

  @override
  bool updateShouldNotify(AppShellScope oldWidget) =>
      oldWidget.openDrawer != openDrawer;
}
