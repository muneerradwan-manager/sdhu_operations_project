import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/application/session_cubit.dart';
import '../../prayer_times/application/prayer_times_cubit.dart';
import '../../prayer_times/data/prayer_times_repository.dart';
import 'home_sidebar_view.dart';

/// The home page.
///
/// It had two shapes and a setting to choose between them: a page of tiles, and
/// a standing rail with the season's roadmap where the tiles had been. The
/// choice is gone and the rail is what remains — living with both showed that
/// the tiles answered "what is there?" only once, on a person's first morning,
/// and after that spent a whole screen restating a menu that is one tap away
/// from every page in the app. The rail says the same thing in 280 pixels and
/// keeps saying it while the reader is somewhere else.
///
/// What is left in this file is what neither the page nor the rail can own: the
/// prayer cubit, which the pull-to-refresh gesture has to reach from above
/// anything the card could provide. See [HomeSidebarView] for the page, and
/// `AppShell` for the rail — which is built ABOVE the router's navigator, so it
/// outlives every page rather than being rebuilt on the way back to this one.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Owned by the screen rather than created inside the card, so that the
  /// pull-to-refresh gesture — which is handled up here, above anything the
  /// card could provide — can reach it.
  late final _prayer = PrayerTimesCubit(PrayerTimesRepository());

  // No season is fetched here. This screen used to ask the server for the
  // current season on every open and every pull, to print one Hijri year on a
  // badge; the badge now shows today's date, which the device knows, and the
  // request went with it.

  @override
  void dispose() {
    _prayer.close();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([
      // A permission granted a minute ago arrives with this, and a door appears
      // in the column and a section in the guide without the app being closed
      // and opened again.
      context.read<SessionCubit>().reload(),
      // Never prompts. A drag on a list is a request for newer numbers, not a
      // gesture anybody would expect to raise a permission dialog.
      _prayer.refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionCubit>().state;

    // Provided here rather than inside the card, so that `_refresh` — which
    // lives above anything the card could provide — can reach the same cubit.
    return BlocProvider.value(
      value: _prayer,
      child: HomeSidebarView(session: session, onRefresh: _refresh),
    );
  }
}
