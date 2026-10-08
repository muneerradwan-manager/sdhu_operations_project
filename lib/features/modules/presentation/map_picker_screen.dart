import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../domain/map_location.dart';

/// Drop a pin on a map, or jump to where you are standing. Pops the chosen
/// [MapLocation], or null if the admin backed out.
///
/// Tiles come from OpenStreetMap: no API key, no billing account, and no build
/// configuration for whoever sets this project up next.
class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, this.initial});

  final MapLocation? initial;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  /// Falls back to the Holy Mosque — the centre of gravity of every hotel in
  /// this system, so an admin with no pin yet starts somewhere useful.
  static const _fallback = LatLng(21.422510, 39.826168);

  final _controller = MapController();
  late LatLng? _picked = widget.initial == null
      ? null
      : LatLng(widget.initial!.latitude, widget.initial!.longitude);

  bool _locating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _useCurrentLocation() async {
    final l = context.l10n;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) _say(l.locationServiceDisabled);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) _say(l.locationPermissionDenied);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() => _picked = point);
      _controller.move(point, 17);
    } catch (_) {
      if (mounted) _say(l.locationFailed);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _confirm() {
    final picked = _picked;
    if (picked == null) return;
    Navigator.of(context).pop(
      MapLocation(latitude: picked.latitude, longitude: picked.longitude),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: Text(l.locationPickerTitle)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _picked ?? _fallback,
              initialZoom: _picked == null ? 12 : 17,
              onTap: (_, point) => setState(() => _picked = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                // OpenStreetMap's tile policy asks for an identifying agent.
                userAgentPackageName: 'com.shud.hajjoperations',
                maxZoom: 19,
              ),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 44,
                      height: 44,
                      // Anchored so the pin's tip sits on the coordinate.
                      alignment: Alignment.topCenter,
                      child: Icon(
                        Icons.location_on,
                        size: 44,
                        color: scheme.primary,
                        shadows: const [
                          Shadow(blurRadius: 6, color: Colors.black45),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + kToolbarHeight + AppSpacing.sm,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: GlassSurface(
              strong: true,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Text(
                _picked == null
                    ? l.locationTapToPlace
                    : '${_picked!.latitude.toStringAsFixed(5)}, '
                          '${_picked!.longitude.toStringAsFixed(5)}',
                textAlign: TextAlign.center,
                // A negative coordinate starts with a neutral '-', which bidi
                // would throw to the far end of an Arabic line.
                textDirection: _picked == null ? null : TextDirection.ltr,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          // Directional: like every floating action in the app, it sits on the
          // trailing edge — which is the left one in Arabic.
          PositionedDirectional(
            bottom: AppSpacing.xxl * 3,
            end: AppSpacing.lg,
            child: GlassIconButton(
              icon: _locating ? AppIcons.pending : AppIcons.myLocation,
              tooltip: l.locationUseCurrent,
              onPressed: _locating ? null : _useCurrentLocation,
            ),
          ),
        ],
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
              onPressed: _picked == null ? null : _confirm,
              icon: const Icon(AppIcons.location),
              label: Text(l.locationConfirm),
            ),
          ),
        ),
      ),
    );
  }
}
