import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/router/app_router.dart';
import '../../../core/settings/settings_cubit.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/blocking_progress.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/info_section.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/responsive.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/saved_account.dart';
import '../../auth/presentation/widgets/saved_accounts_list.dart';
import '../../prayer_times/presentation/widgets/prayer_alerts_section.dart';

/// Everything about this device rather than about the mission: who is signed in
/// to it, which language it speaks, how it looks, whether it makes a noise, and
/// the way out.
///
/// The page is read in three movements, and the order is the claim it makes
/// about what a person came here for:
///
///  1. **You.** Whose device this is right now, and the way to another account.
///     A settings page that opens on a language picker makes you scroll to find
///     out whether you are even logged in as the right person, which is the
///     first question in a shared handset — and this mission's handsets are
///     shared.
///  2. **هذا الجهاز.** The language, the look, and whether the phone is allowed
///     to make a sound. Three preferences that are about the screen in this
///     man's hand rather than about who he is — which is exactly why they are
///     stored per device, and now says so out loud.
///  3. **مواقيت الصلاة.** What the notification shade announces, and when —
///     under its own heading, so a reader wanting the times off finds them in
///     one place.
///
/// The groups are what makes this a page rather than a pile. Before them it was
/// seven glass panes of equal weight in two grids, and nothing on it said which
/// of them belonged together.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final settings = context.watch<SettingsCubit>();
    final state = settings.state;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: Text(l.commonSettings)),
      body: PrayerAlertsScope(
        child: Builder(
          builder: (context) => ResponsivePage(
            builder: (context, size) => SinglePaneLayout(
              gutter: size.gutter,
              children: staggered([
                // No group label over this row, and that is what marks it as
                // the page's header rather than as its first section: the three
                // rows below are answers to «ماذا أضبط؟», and this one is the
                // answer to «من أنا؟».
                const _AccountSection(),
                const SizedBox(height: AppSpacing.xl),

                _GroupLabel(l.settingsGroupDevice),
                // Three independent settings, none of which needs to be read
                // before another — so on a wide window they stand side by side
                // rather than in a queue the length of the screen.
                AdaptiveGrid(
                  children: [
                    InfoSection(
                      title: l.settingsLanguage,
                      icon: AppIcons.language,
                      children: [
                        _Options<String?>(
                          value: state.locale?.languageCode,
                          onChanged: (code) => settings.setLocale(
                            code == null ? null : Locale(code),
                          ),
                          options: [
                            ('ar', l.languageArabic),
                            ('en', l.languageEnglish),
                            (null, l.settingsLanguageSystem),
                          ],
                        ),
                      ],
                    ),
                    InfoSection(
                      title: l.settingsTheme,
                      icon: AppIcons.theme,
                      children: [
                        _Options<ThemeMode>(
                          value: state.themeMode,
                          onChanged: settings.setThemeMode,
                          options: [
                            (ThemeMode.system, l.themeSystem),
                            (ThemeMode.light, l.themeLight),
                            (ThemeMode.dark, l.themeDark),
                          ],
                        ),
                        // Under the three, not beside them: it is not a fourth
                        // theme. It applies to whichever of the three is
                        // chosen — a man on a night shift under floodlights
                        // wants the glass gone as much as one at noon does,
                        // and a slow handset wants it gone at every hour.
                        _SettingSwitch(
                          title: l.settingsSolidSurfaces,
                          hint: l.settingsSolidSurfacesHint,
                          value: state.solidSurfaces,
                          onChanged: settings.setSolidSurfaces,
                        ),
                      ],
                    ),
                    InfoSection(
                      title: l.navNotifications,
                      icon: AppIcons.notifications,
                      children: [
                        _SettingSwitch(
                          title: l.settingsNotifications,
                          hint: l.settingsNotificationsHint,
                          value: state.notificationsEnabled,
                          onChanged: settings.setNotificationsEnabled,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // The whole group is dropped on a platform that cannot
                // announce anything — a heading over an empty row is a
                // question with no answers under it.
                if (PrayerAlertsSection.available) ...[
                  _GroupLabel(l.prayerTimesTitle),
                  // In the same grid as the rows above, so the pane lines up
                  // in the same columns.
                  const AdaptiveGrid(children: [PrayerAlertsSection()]),
                  const SizedBox(height: AppSpacing.xl),
                ],

                const _SignOutCard(),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The heading over a set of panes: a short word, set small and wide, with a
/// rule running out from it to the edge of the page.
///
/// It is the cheapest thing on the page and does the most. Seven glass panes of
/// identical weight is a pile; the same seven under three of these is a page
/// with a table of contents you can read without moving your eyes off it. The
/// rule rather than a box, because a group is not a container here — the panes
/// already have their own edges, and a second frame around them would be two
/// borders saying one thing.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppSpacing.md,
        left: AppSpacing.xs,
        right: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// A closed set of answers, laid out as chips on one line instead of a column
/// of radio rows.
///
/// Language and theme are three short words each. As rows they cost six lines
/// and roughly 290 vertical pixels — on a phone, the whole first screenful of a
/// settings page spent on two questions whose answers are already known to the
/// person asking. As chips they cost two lines, every answer stays visible, and
/// the chosen one still reads as chosen from across a room.
///
/// [ChoiceChip] rather than [SegmentedButton], and the reason is on this same
/// page: the prayer pane picks its warning time with exactly this control. A
/// segmented button would also have to survive «حسب النظام» and «English» in a
/// 300-pixel pane on a narrow window, which it does by squeezing rather than by
/// wrapping.
class _Options<T> extends StatelessWidget {
  const _Options({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          for (final (option, label) in options)
            ChoiceChip(
              label: Text(label),
              selected: option == value,
              visualDensity: VisualDensity.compact,
              // A group that takes one answer must never be emptied by
              // re-tapping the answer it already holds: there is no such thing
              // here as "no language". Pressing the chosen chip does nothing.
              onSelected: (_) => onChanged(option),
            ),
        ],
      ),
    );
  }
}

/// Who is signed in, and the way across to somebody else.
///
/// It stands at the TOP of the page now, where it used to be a pane in the
/// second row under three appearance settings. The handsets this app runs on
/// are shared and passed around, and «من أنا الآن؟» is a question a person
/// answers before any other — a settings page that opens on a language picker
/// makes them scroll to find out whether they are even looking at their own
/// account.
///
/// Switching is not signing out and back in: no session is ended, which is the
/// whole point — Supabase revokes a session the moment it is signed out, and a
/// revoked session cannot be reopened. The account being left keeps its own,
/// and comes back with a tap.
class _AccountSection extends StatefulWidget {
  const _AccountSection();

  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  String? _switching;

  Future<void> _switchTo(SavedAccount account) async {
    final l = context.l10n;
    final auth = context.read<AuthRepository>();

    setState(() => _switching = account.userId);
    try {
      await auth.switchTo(account);
      // Home, and explicitly. This page was pushed onto the session that has
      // just been left, and go_router does not re-decide a pushed route when
      // the session changes beneath it — without this, an account that is
      // pending approval would land on the settings page of an app it is not
      // yet allowed into. From `/` the ordinary redirect takes over and puts
      // them wherever their account belongs.
      if (mounted) context.go(Routes.home);
    } on AuthFailure {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.accountsExpired)));
    } finally {
      if (mounted) setState(() => _switching = null);
    }
  }

  Future<void> _confirmForget(SavedAccount account) async {
    final l = context.l10n;
    final auth = context.read<AuthRepository>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.accountsRemove),
        content: Text(l.accountsRemoveConfirm(account.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await auth.forgetAccount(account.userId);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final auth = context.read<AuthRepository>();
    final currentUserId = auth.currentUser?.id;
    if (currentUserId == null) return const SizedBox.shrink();

    return ValueListenableBuilder<List<SavedAccount>>(
      valueListenable: auth.accounts,
      builder: (context, accounts, _) {
        final current = accounts
            .where((a) => a.userId == currentUserId)
            .firstOrNull;
        // The switcher lists only the accounts you are NOT on.
        //
        // [SavedAccountsList] keeps the current one on the login screen on
        // purpose — a switcher that leaves out where you are makes you count to
        // work out where you are. Here that question is already answered, in
        // larger type, by the block directly above; showing the same face and
        // the same address again a centimetre below it is a page repeating
        // itself, not a page reassuring you.
        final others = accounts
            .where((a) => a.userId != currentUserId)
            .toList();

        // Two panes rather than one wide one, measured by the same grid as
        // every other row on the page.
        //
        // A single pane spanning the page was the obvious first answer and the
        // wrong one: an account row is a face, a name and one icon, and at 1600
        // wide the name and the icon end up in different postcodes. Split, each
        // half lands in a grid cell of the same width as a settings pane, and
        // the row is ragged in exactly the way the prayer row below it is when
        // a platform cannot offer all three.
        return AdaptiveGrid(
          children: [
            InfoSection(
              title: l.navMyProfile,
              icon: AppIcons.accounts,
              maxColumns: 1,
              separated: false,
              children: [
                _Identity(
                  account: current,
                  email: current?.email ?? auth.currentUser?.email ?? '',
                  locked: _switching != null,
                ),
              ],
            ),
            InfoSection(
              title: l.accountsTitle,
              icon: AppIcons.switchAccount,
              // One column, no rules. These are rows and not fields — a card
              // carries a face, a name and an address — and the pane's children
              // are not peers either: a caption belongs to the list under it,
              // and a button is an action on that list rather than another
              // entry in it. Ruled off, the pane drew hairlines through one
              // continuous block.
              maxColumns: 1,
              separated: false,
              children: [
                if (others.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _FieldLabel(l.settingsSwitchAccount),
                  const SizedBox(height: AppSpacing.sm),
                  SavedAccountsList(
                    accounts: others,
                    currentUserId: currentUserId,
                    busyUserId: _switching,
                    onSelect: _switchTo,
                    onForget: _confirmForget,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  // The current session is deliberately left running: the
                  // sign-in screen replaces it when the second account
                  // arrives, and until then backing out costs nothing.
                  onPressed: _switching != null
                      ? null
                      : () =>
                            context.push('${Routes.login}?add=$currentUserId'),
                  icon: const Icon(AppIcons.addUser),
                  label: Text(l.accountsAdd),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Whose device this is: a face, a name, an address, and the way into the
/// profile behind them.
///
/// Tappable, and that is not decoration. A person who arrives at الإعدادات
/// looking for their own record is looking for the one screen this block is a
/// summary of; sending them back to the menu to find it is a step the page can
/// simply absorb.
class _Identity extends StatelessWidget {
  const _Identity({
    required this.account,
    required this.email,
    required this.locked,
  });

  /// Null in the moment between signing in and the profile arriving, when the
  /// address is all this device knows about the person holding it.
  final SavedAccount? account;
  final String email;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = account?.label ?? email;
    // Where the name IS the address there is nothing for the second line to
    // say, and printing it twice reads as a rendering fault rather than as a
    // profile that has not been filled in yet.
    final second = name == email ? l.navMyProfile : email;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: locked ? null : () => context.push(Routes.myProfile),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            ProfileAvatar(
              photoUrl: account?.photoUrl,
              name: account?.name,
              radius: 26,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    second,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const NavChevron(),
          ],
        ),
      ),
    );
  }
}

/// The way out, drawn as a pane rather than as a button.
///
/// It used to be a bare [OutlinedButton] wrapped in an [IntrinsicWidth] and a
/// 200-pixel floor, three widgets deep, all of it spent undoing one line of the
/// app's own theme: the button style's `minimumSize` is a `Size.fromHeight`,
/// which is an infinite minimum WIDTH, so every button in this app claims its
/// parent's full width unless it is stopped. A capped box could not stop it —
/// the button simply grew to meet the cap.
///
/// A card has no such argument with the theme: it is as wide as it is given,
/// and it is given [CardWidth.list] — the same width as one cell of the grids
/// above, so the page's last element lines up with its columns instead of
/// floating loose beneath them. Washed in the error colour, which is what says
/// this one is not like the settings above it before any word is read.
class _SignOutCard extends StatelessWidget {
  const _SignOutCard();

  Future<void> _confirm(BuildContext context) async {
    final l = context.l10n;
    final auth = context.read<AuthRepository>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.commonLogout),
        content: Text(l.settingsLogoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.commonLogout),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await runBlocking(context, auth.signOut, message: l.commonLoggingOut);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final error = Theme.of(context).colorScheme.error;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: CardWidth.list),
        child: GlassCard(
          tint: error,
          onTap: () => _confirm(context),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(AppIcons.logout, size: 19, color: error),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  l.commonLogout,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: error,
                    fontWeight: FontWeight.w600,
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

/// A titled switch with a line of explanation, written as a plain row rather
/// than as a [SwitchListTile].
///
/// A ListTile measures its title and subtitle at the tile's FULL width and then
/// lays them out at the width the trailing switch leaves over — so the hint
/// wraps to one more line than the measurement allowed for. Inside the settings
/// grid, where the panes in a row are given a shared height taken from exactly
/// that measurement, the pane then overflows by those few pixels. Here the
/// switch is an inflexible child of the row, so both passes see the same text
/// width.
///
/// Every switch on this screen needs the same thing said about it: what it does
/// is not obvious from the title alone. Push still ARRIVES when it is off — the
/// phone simply stays quiet — and solid surfaces is not a taste, it is what to
/// press when the screen is unreadable in the sun.
class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.title,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 3),
                  Text(
                    hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// The small caption over a control inside a pane — the same one the prayer
/// pane sets over its rows of chips, so the two panes label their contents in
/// one voice.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.3,
      ),
    );
  }
}
