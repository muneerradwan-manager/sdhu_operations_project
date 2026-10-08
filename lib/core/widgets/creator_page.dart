import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/glass_tokens.dart';
import 'glass.dart';
import 'responsive.dart';

/// Adding something is one gesture and one shape, on every list in this app.
///
/// It was three. A task was written in a bottom sheet stacked over its list; a
/// complaint was written on a page pushed above it; an arrival was filed on a
/// screen that was not above the record at all — it was the record's SIBLING,
/// reached from the home page, so the man who scanned a code was returned to
/// the home page and never saw the line he had just written. Three ways to add,
/// three ways back, and only one of them ended where the reader was looking.
///
/// The page won, and not by taste. A sheet cannot hold the arrival: that form
/// opens a camera over the whole screen and waits on a position fix. A sheet
/// holds the complaint badly: a target picker, a dropdown, six lines of prose
/// and a column of attachments come to a sheet that is a page in all but the
/// handle at the top of it. So the page is the only shape all three can take,
/// and a rule that only two thirds of a thing can follow is not a rule.
///
/// Which leaves the sheet a job of its own, and a clearer one: OPENING a row
/// that already exists — the task sheet, where a state is moved and a note
/// added — is a detail drawn over its list, and reads as one. Writing a new
/// record is a place you GO.
///
///   * [CreateFab] is the way in — one button, one position, on every list.
///   * [CreatorPage] is what it opens — one chrome, with the commit at the
///     bottom of the screen where the thumb is, not at the bottom of a scroll.
///   * Both ends pop `true` when something was written, and the list that
///     pushed them reloads. Back always lands on the list. There is no third
///     destination.
class CreateFab extends StatelessWidget {
  const CreateFab({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = AppIcons.add,
  });

  final String label;

  /// Null greys it out — for a list that cannot be added to yet, which is a
  /// different sentence from a list with no button.
  final VoidCallback? onPressed;

  /// Overridden only where the verb is genuinely not "add": scanning a code is
  /// the one such case, and the barcode says what pressing it will do.
  final IconData icon;

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
  );
}

/// The one chrome every "write a new record" page wears.
///
/// The commit sits in a bar pinned to the bottom of the WINDOW rather than at
/// the foot of the form. On a phone with the keyboard up, a button at the foot
/// of a scrolling column is a button nobody can find without dismissing the
/// keyboard first — and the bar is also what tells a reader, before they have
/// read a field, that this screen ends in one decision.
class CreatorPage extends StatelessWidget {
  const CreatorPage({
    super.key,
    required this.title,
    required this.children,
    required this.submitLabel,
    required this.onSubmit,
    this.submitIcon = AppIcons.approve,
    this.busy = false,
    this.width = PageWidth.form,
  });

  final String title;
  final List<Widget> children;
  final String submitLabel;

  /// Null disables the button — nothing is filled in yet, or it is saving.
  final VoidCallback? onSubmit;

  final IconData submitIcon;

  /// Swaps the icon for a spinner and seals the button, so a second press
  /// cannot file the same thing twice.
  final bool busy;

  /// What kind of page this is. A creator is a form by default — one column of
  /// fields and one decision at the foot of it — and the two that are not say
  /// so: a record with a dozen fields is a [PageWidth.editor].
  final PageWidth width;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: GlassAppBar(title: Text(title)),
    body: SafeArea(
      child: ResponsivePage(
        width: width,
        builder: (context, size) => SinglePaneLayout(
          gutter: size.gutter,
          // The keyboard closes when the form is dragged, because a person
          // scrolling is a person reading, not typing.
          keyboardDismiss: ScrollViewKeyboardDismissBehavior.onDrag,
          children: children,
        ),
      ),
    ),
    bottomNavigationBar: GlassSurface(
      radius: 0,
      strong: true,
      shadow: false,
      bordered: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FilledButton.icon(
            onPressed: busy ? null : onSubmit,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Icon(submitIcon),
            label: Text(submitLabel),
          ),
        ),
      ),
    ),
  );
}
