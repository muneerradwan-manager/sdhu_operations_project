import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/states.dart';
import '../../../l10n/app_localizations.dart';
import '../../incidents/data/incidents_repository.dart';
import '../../incidents/domain/incident.dart';
import '../application/season_map_cubit.dart';
import '../data/season_map_repository.dart';
import '../domain/map_place.dart';

/// The colour a place is drawn in, and the words for it.
///
/// Held here rather than inside the pin, because the pin, the legend under the
/// map and the sheet that opens on a tap must agree exactly. They are the same
/// claim said three ways — a dot, a key, and a sentence — and a reader who
/// found the legend saying one thing and the sheet another would be right to
/// stop trusting the colours, which are the whole reason to draw the season
/// rather than list it.
Color _conditionColour(ColorScheme scheme, PlaceCondition condition) =>
    switch (condition) {
      PlaceCondition.incident => scheme.error,
      PlaceCondition.unmanned => scheme.tertiary,
      PlaceCondition.manned => scheme.primary,
      // The muted outline colour, because it is nobody's fault: the place is on
      // the season's list and no file has staffed it.
      PlaceCondition.empty => scheme.outline,
    };

String _conditionLabel(AppLocalizations l, PlaceCondition condition) =>
    switch (condition) {
      PlaceCondition.incident => l.seasonMapIncident,
      PlaceCondition.unmanned => l.seasonMapUnmanned,
      PlaceCondition.manned => l.seasonMapManned,
      PlaceCondition.empty => l.seasonMapEmpty,
    };

/// The season on one map.
///
/// Every fact in this app has been tied to a place since the beginning — a برج
/// is a hotel with an address, a مخيم has coordinates somebody pinned, an
/// arrival records where the phone was — and none of it has ever been drawn
/// together. The map library has been in the project since 0021 and had only
/// ever been used to pick one point at a time.
///
/// What the operations room asks during the five days is a question about a
/// picture: where are our places, who is in them, and where is something wrong.
/// Asked of three lists on three screens, it is a question nobody finishes.
class SeasonMapScreen extends StatelessWidget {
  const SeasonMapScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => SeasonMapCubit(SeasonMapRepository(), IncidentsRepository()),
    child: const _MapView(),
  );
}

class _MapView extends StatefulWidget {
  const _MapView();

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  final _controller = MapController();

  /// Where the map opens when the season has nothing pinned yet — the Haram.
  /// The same fallback the location picker uses, for the same reason: a map
  /// centred on the null island is a map that looks broken.
  static const _fallback = LatLng(21.422510, 39.826168);

  /// Set once the first fit has been done, so that a refresh does not yank the
  /// view back while somebody is reading a corner of it.
  bool _framed = false;

  /// Whether the backdrop could not be fetched.
  ///
  /// Worth saying out loud. A map with no tiles looks exactly like a map that
  /// is broken, and the difference matters to whoever is standing in front of
  /// it: the pins ARE right, the positions ARE right, and it is the pictures
  /// of the streets underneath them that did not arrive.
  bool _tilesFailed = false;

  void _frame(SeasonMapState state) {
    if (_framed || state.status != SeasonMapStatus.ready) return;
    final bounds = MapBounds.around([
      for (final place in state.places) place.position,
      for (final incident in state.incidents)
        LatLng(incident.latitude!, incident.longitude!),
    ]);
    if (bounds == null) return;
    _framed = true;

    // After the frame, not during it: the map has no size until it is laid out,
    // and fitting to a box of zero puts the camera somewhere arbitrary.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(bounds.southWest, bounds.northEast),
          padding: const EdgeInsets.all(AppSpacing.xl),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: Text(l.seasonMapTitle)),
      body: BlocConsumer<SeasonMapCubit, SeasonMapState>(
        listener: (context, state) => _frame(state),
        builder: (context, state) {
          if (state.status == SeasonMapStatus.loading) {
            return const Center(child: AppLoader());
          }
          if (state.status == SeasonMapStatus.error) {
            return EmptyState(
              icon: AppIcons.warning,
              title: friendlyError(context, state.error),
            );
          }
          // A blank map is indistinguishable from a broken one. Said in words
          // instead, with the reason: a place appears here when somebody pins
          // it on the file, and until then there is nothing to draw.
          if (state.places.isEmpty && state.incidents.isEmpty) {
            return EmptyState(
              icon: AppIcons.checkIn,
              title: l.seasonMapEmptyState,
              message: l.seasonMapEmptyStateHint,
            );
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _controller,
                options: const MapOptions(
                  initialCenter: _fallback,
                  initialZoom: 11,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    // OpenStreetMap's tile policy asks for an identifying agent.
                    userAgentPackageName: 'com.shud.hajjoperations',
                    maxZoom: 19,
                    // Tiles that will not come are not a failure of this
                    // screen. The pins are drawn over whatever backdrop there
                    // is — including none — so the map still answers the
                    // question it was opened for: where the places are
                    // relative to each other, and which of them wants
                    // attention. A blank canvas with the right pins on it
                    // beats an error page.
                    errorTileCallback: (_, _, _) {
                      if (_tilesFailed) return;
                      // One rebuild, not one per tile: a screenful is a
                      // hundred of these inside a second.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _tilesFailed = true);
                      });
                    },
                  ),
                  MarkerLayer(
                    markers: [
                      for (final place in state.drawnPlaces)
                        Marker(
                          point: place.position,
                          width: 40,
                          height: 40,
                          child: _PlacePin(
                            place: place,
                            onTap: () => _openPlace(place),
                          ),
                        ),
                      // Drawn AFTER the places, so an emergency is never
                      // underneath the camp it happened next to.
                      for (final incident in state.drawnIncidents)
                        Marker(
                          point: LatLng(
                            incident.latitude!,
                            incident.longitude!,
                          ),
                          width: 40,
                          height: 40,
                          child: _IncidentPin(
                            incident: incident,
                            onTap: () => _openIncident(incident),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (_tilesFailed)
                Positioned(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  top: AppSpacing.lg,
                  child: SafeArea(
                    child: _MapPanel(
                      child: Row(
                        children: [
                          const Icon(AppIcons.warning, size: 16),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              l.seasonMapNoTiles,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: SafeArea(child: _Legend(state: state)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// What the pin knows about itself.
  ///
  /// It used to open the operational file. That was the wrong answer to the
  /// gesture: a man tapping a camp on a map is asking about the CAMP — is
  /// anybody in it, is anything wrong there, where exactly is it — and what
  /// arrived was a roster and a form, several screens deep, with the map lost
  /// behind it. He then had to find his way back to carry on reading the
  /// picture, which is the one thing a map is for.
  ///
  /// So the pin answers about the place, in a sheet over the map that is
  /// dismissed with a thumb. The file is NAMED here, because knowing which file
  /// a camp belongs to is part of knowing what it is — but it is text, not a
  /// door.
  void _openPlace(MapPlace place) {
    showModalBottomSheet<void>(
      context: context,
      // Over the rail as well as the page — see [showAppSheet].
      useRootNavigator: true,
      showDragHandle: true,
      // On a desk monitor an unconstrained sheet runs the full width and leaves
      // a title alone at one end and a button at the other.
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) => _PlaceSheet(place: place),
    );
  }

  void _openIncident(Incident incident) {
    showModalBottomSheet<void>(
      context: context,
      // Over the rail as well as the page — see [showAppSheet].
      useRootNavigator: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl + MediaQuery.viewPaddingOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              incident.body,
              style: Theme.of(sheetContext).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              incident.reporterName,
              style: Theme.of(sheetContext).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// A panel that sits ON the map, and is legible whatever is under it.
///
/// Deliberately not a [GlassCard]. Glass is a content pane: it takes its
/// character from the page behind it, which everywhere else in this app is a
/// known backdrop in a known theme. Here what is behind it is a photograph of
/// Mina at some zoom — pale roads, dark hillside, a white sheet where the tiles
/// did not arrive — and a translucent panel over that reads as nothing at all,
/// which is exactly what happened.
///
/// So it is opaque, and it carries its own border and shadow rather than
/// borrowing contrast from a background it cannot predict.
class _MapPanel extends StatelessWidget {
  const _MapPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      // A surface from the theme rather than a fixed colour, so it stays
      // right in both the light theme and the dark one this app defaults to.
      color: scheme.surfaceContainerHighest,
      elevation: 6,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: scheme.outlineVariant),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    );
  }
}

/// What one pin knows about itself.
///
/// Everything here is already in hand when the map draws: [MapPlace] carries
/// the counts, the condition and the position, so opening this costs no query
/// and cannot fail. That matters more than it looks — the room taps a pin to
/// settle a question in the middle of a conversation, and a spinner is an
/// answer arriving after the question has moved on.
class _PlaceSheet extends StatelessWidget {
  const _PlaceSheet({required this.place});

  final MapPlace place;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        // The sheet ends above the gesture bar rather than under it. Android 15
        // draws edge to edge and will happily put the navigation pill on top of
        // the last row otherwise.
        AppSpacing.xl + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The same dot that is on the map, so the eye carries the colour
              // it just tapped straight into the sentence explaining it.
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: _conditionColour(scheme, place.condition),
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.placeName, style: theme.textTheme.titleMedium),
                    Text(
                      place.groupName.of(context),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _conditionLabel(l, place.condition),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _conditionColour(scheme, place.condition),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Count(
                value: place.posted,
                label: l.seasonMapPosted,
              ),
              _Count(
                value: place.present,
                label: l.seasonMapPresent,
              ),
              _Count(
                value: place.openIncidents,
                label: l.seasonMapOpenIncidents,
                // Zero open incidents is the good news, so it is not coloured
                // like a warning; any at all is.
                colour: place.openIncidents > 0 ? scheme.error : null,
              ),
            ],
          ),
          // No «ضمن الملف التشغيلي» line. A place is not in a file — it stopped
          // being one in 0095 — and the sheet used to answer a tap on a camp in
          // منى with «توزيع أعضاء مكاتب البعثة على مخيمات منى», which was the
          // name of a file that happens to post people here. What IS true of
          // the place is the three counts above.
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${place.position.latitude.toStringAsFixed(6)}, '
                  '${place.position.longitude.toStringAsFixed(6)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              // The one thing a man standing in Mina actually wants off a pin:
              // the numbers, in a form he can paste into whatever will drive
              // him there. Copying rather than launching, because which app
              // that is differs by phone and by whose SIM is in it.
              TextButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(
                    ClipboardData(
                      text: '${place.position.latitude},'
                          '${place.position.longitude}',
                    ),
                  );
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(content: Text(l.seasonMapCoordinatesCopied)),
                    );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(l.seasonMapCopyCoordinates),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One figure and what it counts.
class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label, this.colour});

  final int value;
  final String label;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: theme.textTheme.headlineSmall?.copyWith(color: colour),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One place, coloured by what is true of it.
///
/// Colour before words: the whole reason to draw the season rather than list it
/// is that a reader takes the shape of it in before he has read anything.
class _PlacePin extends StatelessWidget {
  const _PlacePin({required this.place, required this.onTap});

  final MapPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour = _conditionColour(scheme, place.condition);

    return Tooltip(
      // The name alone. A pin is a hotel or a camp, and pointing at one asks
      // which — the file it is organised under, its counts and its condition
      // are what the sheet answers on a tap, and crowding them into a hover
      // makes the one thing being asked for harder to read.
      message: place.placeName,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: colour,
            shape: BoxShape.circle,
            // A white ring, so a pin stays legible over a dark satellite roof
            // or a pale road — the tiles are somebody else's and we do not get
            // to choose what is underneath.
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(blurRadius: 4, color: Colors.black38),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            // The number of people reported present, which is the one figure
            // worth carrying on the pin itself.
            '${place.present}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _IncidentPin extends StatelessWidget {
  const _IncidentPin({required this.incident, required this.onTap});

  final Incident incident;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: incident.body,
      child: GestureDetector(
        onTap: onTap,
        child: Icon(
          AppIcons.warning,
          color: scheme.error,
          size: 32,
          shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
        ),
      ),
    );
  }
}

/// What the colours mean, and the two switches that thin the map out.
class _Legend extends StatelessWidget {
  const _Legend({required this.state});

  final SeasonMapState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final cubit = context.read<SeasonMapCubit>();

    return _MapPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The groups first, because narrowing the map is what a reader came
          // to do — "just the camps of Mina" — and the colour key is what he
          // reads afterwards to interpret what is left.
          if (state.groups.length > 1) ...[
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final group in state.groups)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.xs,
                      ),
                      child: FilterChip(
                        selected: !state.hiddenGroups.contains(group.key),
                        label: Text(
                          '${group.name.of(context)} · ${group.count}',
                        ),
                        onSelected: (_) => cubit.toggleGroup(group.key),
                        // A long press is the shortcut for the gesture the
                        // filter exists for: switching the other four off one
                        // at a time is the work the map was meant to save.
                        tooltip: l.seasonMapOnlyThis,
                      ),
                    ),
                  if (state.hiddenGroups.isNotEmpty)
                    TextButton(
                      onPressed: cubit.showAllGroups,
                      child: Text(l.seasonMapShowAll),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              // Listed calmest-first, which is the reverse of the enum's own
              // order: the enum ranks by what somebody must DO about it, and a
              // key is read left to right by somebody not yet worried.
              for (final condition in const [
                PlaceCondition.manned,
                PlaceCondition.unmanned,
                PlaceCondition.incident,
                PlaceCondition.empty,
              ])
                _Key(
                  colour: _conditionColour(scheme, condition),
                  label: _conditionLabel(l, condition),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.seasonMapCounts(state.places.length, state.incidents.length),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              _Toggle(
                label: l.seasonMapPlaces,
                value: state.showPlaces,
                onChanged: cubit.setShowPlaces,
              ),
              _Toggle(
                label: l.seasonMapIncidents,
                value: state.showIncidents,
                onChanged: cubit.setShowIncidents,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.colour, required this.label});

  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(
        color: colour, shape: BoxShape.circle)),
      const SizedBox(width: AppSpacing.xs),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      Switch(
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ],
  );
}
