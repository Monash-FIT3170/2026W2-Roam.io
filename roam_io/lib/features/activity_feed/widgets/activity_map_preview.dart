/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026
 * Description:
 *   Shared Journey route map preview and expanded map screen for social
 *   activity surfaces, using only persisted activity route fields.
 */

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../theme/app_surfaces.dart';
import '../../journeys/domain/transport_mode.dart';
import '../../map/data/journey_map_snapshot_service.dart';
import '../../map/data/visited_region_service.dart';
import '../../map/domain/map_styles.dart';
import '../../map/fog/fog_atlas.dart';
import '../../map/fog/fog_atlas_cache.dart';
import '../../map/fog/static_fog.dart';
import '../data/activity_map_image.dart';
import '../domain/activity_route.dart';
import '../models/activity_feed_item.dart';
import 'route_marker_icons.dart';

enum ActivityMapPreviewVariant { compact, detail }

/// Passive route preview for activity cards and a tappable detail variant.
class ActivityMapPreview extends StatefulWidget {
  const ActivityMapPreview({
    super.key,
    required this.route,
    this.variant = ActivityMapPreviewVariant.compact,
    this.polygons = const {},
    this.snapshotOverlay,
    this.snapshotProfileId,
    this.visitedRegionIds,
    this.currentRegionId,
    this.mapSnapshotService,
    this.visitedRegionService,
    this.transportMode,
    this.showEndpoints = false,
    this.endpointMarkerIcons,
    this.mapIdentity,
    this.onTap,
    this.onSnapshotCaptured,
  });

  factory ActivityMapPreview.fromActivity({
    Key? key,
    required ActivityFeedItem activity,
    ActivityMapPreviewVariant variant = ActivityMapPreviewVariant.compact,
    JourneyMapSnapshotService? mapSnapshotService,
    VisitedRegionService? visitedRegionService,
    RouteEndpointMarkerIcons? endpointMarkerIcons,
    VoidCallback? onTap,
  }) {
    final route = activity.showMapPreview
        ? ActivityRoute.tryCreate(
            encodedRoute: activity.encodedRoute,
            persistedBounds: activity.routeBounds,
          )
        : null;
    final transportMode = TransportMode.tryFromString(activity.transportMode);

    return ActivityMapPreview(
      key: key,
      route: route,
      variant: variant,
      snapshotProfileId: activity.ownerId,
      mapSnapshotService: mapSnapshotService,
      visitedRegionService: visitedRegionService,
      transportMode: transportMode,
      showEndpoints: true,
      endpointMarkerIcons: endpointMarkerIcons,
      mapIdentity: activity.id,
      onTap: onTap,
    );
  }

  final ActivityRoute? route;
  final ActivityMapPreviewVariant variant;
  final Set<Polygon> polygons;
  final JourneyMapSnapshotOverlay? snapshotOverlay;
  final String? snapshotProfileId;
  final Set<String>? visitedRegionIds;
  final String? currentRegionId;
  final JourneyMapSnapshotService? mapSnapshotService;
  final VisitedRegionService? visitedRegionService;
  final TransportMode? transportMode;
  final bool showEndpoints;
  final RouteEndpointMarkerIcons? endpointMarkerIcons;
  final String? mapIdentity;
  final VoidCallback? onTap;

  /// Receives the whole fogged route as a bitmap once the map has settled, so
  /// it can be stored and shown instead of rebuilding this map every time.
  final ValueChanged<Uint8List>? onSnapshotCaptured;

  bool get _isDetail => variant == ActivityMapPreviewVariant.detail;

  @override
  State<ActivityMapPreview> createState() => _ActivityMapPreviewState();
}

class _ActivityMapPreviewState extends State<ActivityMapPreview> {
  JourneyMapSnapshotOverlay? _loadedSnapshotOverlay;
  Object? _snapshotLoadKey;
  Set<String>? _loadedVisitedRegionIds;
  String? _loadedCurrentRegionId;
  bool _isSnapshotLoading = false;

  @override
  void initState() {
    super.initState();
    _prepareSnapshotOverlay();
  }

  @override
  void didUpdateWidget(covariant ActivityMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route != widget.route ||
        oldWidget.snapshotOverlay != widget.snapshotOverlay ||
        oldWidget.snapshotProfileId != widget.snapshotProfileId ||
        oldWidget.visitedRegionIds != widget.visitedRegionIds ||
        oldWidget.currentRegionId != widget.currentRegionId ||
        oldWidget.mapSnapshotService != widget.mapSnapshotService ||
        oldWidget.visitedRegionService != widget.visitedRegionService) {
      _prepareSnapshotOverlay();
    }
  }

  void _prepareSnapshotOverlay() {
    final route = widget.route;
    final suppliedOverlay = widget.snapshotOverlay;
    if (suppliedOverlay != null) {
      _loadedSnapshotOverlay = suppliedOverlay;
      _snapshotLoadKey = null;
      _loadedVisitedRegionIds = null;
      _loadedCurrentRegionId = null;
      _isSnapshotLoading = false;
      return;
    }

    if (route == null) {
      _loadedSnapshotOverlay = null;
      _snapshotLoadKey = null;
      _loadedVisitedRegionIds = null;
      _loadedCurrentRegionId = null;
      _isSnapshotLoading = false;
      return;
    }

    final explicitVisitedIds = widget.visitedRegionIds;
    if (explicitVisitedIds != null) {
      final loadKey = Object();
      _snapshotLoadKey = loadKey;
      _loadedSnapshotOverlay = null;
      _isSnapshotLoading = true;
      unawaited(
        _loadSnapshotOverlay(
          route: route,
          visitedRegionIds: explicitVisitedIds,
          currentRegionId: widget.currentRegionId,
          viewportBounds: null,
          loadKey: loadKey,
        ),
      );
      return;
    }

    final profileId = widget.snapshotProfileId;
    if (profileId == null || profileId.isEmpty) {
      _loadedSnapshotOverlay = null;
      _snapshotLoadKey = null;
      _loadedVisitedRegionIds = null;
      _loadedCurrentRegionId = null;
      _isSnapshotLoading = false;
      return;
    }

    final loadKey = Object();
    _snapshotLoadKey = loadKey;
    _loadedSnapshotOverlay = null;
    _isSnapshotLoading = true;
    unawaited(_loadProfileSnapshotOverlay(route, profileId, loadKey));
  }

  Future<void> _loadProfileSnapshotOverlay(
    ActivityRoute route,
    String profileId,
    Object loadKey,
  ) async {
    try {
      final visitedRegionIds =
          await (widget.visitedRegionService ?? VisitedRegionService())
              .loadVisitedRegionIdsForProfile(profileId);
      if (!mounted || _snapshotLoadKey != loadKey) return;
      await _loadSnapshotOverlay(
        route: route,
        visitedRegionIds: visitedRegionIds,
        currentRegionId: null,
        viewportBounds: null,
        loadKey: loadKey,
      );
    } catch (_) {
      if (!mounted || _snapshotLoadKey != loadKey) return;
      setState(() {
        _loadedSnapshotOverlay = JourneyMapSnapshotOverlay.empty;
        _isSnapshotLoading = false;
      });
    }
  }

  Future<void> _loadSnapshotOverlay({
    required ActivityRoute route,
    required Set<String> visitedRegionIds,
    required String? currentRegionId,
    required LatLngBounds? viewportBounds,
    required Object loadKey,
  }) async {
    try {
      final overlay =
          await (widget.mapSnapshotService ?? JourneyMapSnapshotService())
              .loadRouteSnapshotOverlay(
                route: route,
                visitedRegionIds: visitedRegionIds,
                currentRegionId: currentRegionId,
                viewportBounds: viewportBounds,
              );
      if (!mounted || _snapshotLoadKey != loadKey) return;
      setState(() {
        _loadedSnapshotOverlay = overlay;
        _loadedVisitedRegionIds = visitedRegionIds;
        _loadedCurrentRegionId = currentRegionId;
        _isSnapshotLoading = false;
      });
    } catch (_) {
      if (!mounted || _snapshotLoadKey != loadKey) return;
      setState(() {
        _loadedSnapshotOverlay = JourneyMapSnapshotOverlay.empty;
        _isSnapshotLoading = false;
      });
    }
  }

  void _handleViewportReady(LatLngBounds bounds) {
    final route = widget.route;
    final suppliedOverlay = widget.snapshotOverlay;
    if (route == null || suppliedOverlay != null || _isSnapshotLoading) {
      return;
    }

    final overlay = _loadedSnapshotOverlay;
    if (overlay != null && overlay.covers(bounds)) return;

    final visitedRegionIds = _loadedVisitedRegionIds ?? widget.visitedRegionIds;
    if (visitedRegionIds == null) return;

    final loadKey = Object();
    _snapshotLoadKey = loadKey;
    setState(() => _isSnapshotLoading = true);
    unawaited(
      _loadSnapshotOverlay(
        route: route,
        visitedRegionIds: visitedRegionIds,
        currentRegionId: _loadedCurrentRegionId ?? widget.currentRegionId,
        viewportBounds: bounds,
        loadKey: loadKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preparedRoute = widget.route;
    if (preparedRoute == null) return const SizedBox.shrink();
    final overlay = _loadedSnapshotOverlay;
    final isLoading = _isSnapshotLoading && overlay == null;

    final preview = AspectRatio(
      // The shape the capture is stored in, so what a journey is saved as
      // matches what every surface then shows it in. Load-bearing here: the
      // journey summary sheet lays this widget out standalone, and the stored
      // picture is whatever size that lays out at.
      aspectRatio: ActivityMapImage.aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppSurfaces.softCard(context),
          borderRadius: BorderRadius.circular(widget._isDetail ? 18 : 16),
          border: Border.all(color: AppSurfaces.border(context)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget._isDetail ? 18 : 16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AbsorbPointer(
                child: _ActivityRouteGoogleMap(
                  key: ValueKey(
                    '${widget._isDetail ? 'detail' : 'compact'}-'
                    '${widget.mapIdentity ?? _routeIdentity(preparedRoute)}',
                  ),
                  route: preparedRoute,
                  interactive: false,
                  polygons: widget.polygons,
                  snapshotOverlay: overlay,
                  transportMode: widget.transportMode,
                  showEndpoints: widget.showEndpoints,
                  endpointMarkerIcons: widget.endpointMarkerIcons,
                  onViewportReady: _handleViewportReady,
                  onSnapshotCaptured: widget.onSnapshotCaptured,
                ),
              ),
              if (isLoading) const _ActivityMapLoadingSkeleton(),
              if (widget.onTap != null)
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const ValueKey('activity_route_map_open'),
                      onTap: widget.onTap,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return preview;
  }
}

String _routeIdentity(ActivityRoute route) {
  return '${route.start.latitude},${route.start.longitude}-'
      '${route.finish.latitude},${route.finish.longitude}-'
      '${route.points.length}';
}

/// The map picture stored with an activity, shown in place of a live map.
///
/// Nothing here loads regions or stands up a platform view, so a feed full of
/// journeys costs the same whether each one covers one tile or a hundred.
class ActivityMapSnapshotImage extends StatelessWidget {
  const ActivityMapSnapshotImage({
    super.key,
    required this.url,
    this.variant = ActivityMapPreviewVariant.compact,
    this.onTap,
  });

  final String url;
  final ActivityMapPreviewVariant variant;
  final VoidCallback? onTap;

  bool get _isDetail => variant == ActivityMapPreviewVariant.detail;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_isDetail ? 18 : 16);

    return AspectRatio(
      aspectRatio: ActivityMapImage.aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppSurfaces.softCard(context),
          borderRadius: radius,
          border: Border.all(color: AppSurfaces.border(context)),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _ActivityMapImageUnavailable(),
              ),
              if (onTap != null)
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const ValueKey('activity_route_map_open'),
                      onTap: onTap,
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

/// Shown when the stored picture cannot be fetched.
///
/// Deliberately static: falling back to a live map here would reintroduce the
/// per-card map this picture replaced.
class _ActivityMapImageUnavailable extends StatelessWidget {
  const _ActivityMapImageUnavailable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: AppSurfaces.softCard(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            color: AppSurfaces.textMuted(context),
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(
            'Map preview unavailable',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppSurfaces.textMuted(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityMapLoadingSkeleton extends StatelessWidget {
  const _ActivityMapLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppSurfaces.softCard(context),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Full-screen interactive Journey route map opened from activity details.
class ActivityRouteMapScreen extends StatelessWidget {
  const ActivityRouteMapScreen({
    super.key,
    required this.route,
    required this.title,
    this.transportMode,
    this.endpointMarkerIcons,
  });

  final ActivityRoute route;
  final String title;
  final TransportMode? transportMode;
  final RouteEndpointMarkerIcons? endpointMarkerIcons;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSurfaces.pageBackground(context),
      appBar: AppBar(
        backgroundColor: AppSurfaces.pageBackground(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: _ActivityRouteGoogleMap(
          key: const ValueKey('activity_route_map_expanded'),
          route: route,
          interactive: true,
          polygons: const {},
          snapshotOverlay: null,
          transportMode: transportMode,
          showEndpoints: true,
          endpointMarkerIcons: endpointMarkerIcons,
          onViewportReady: null,
        ),
      ),
    );
  }
}

class _ActivityRouteGoogleMap extends StatefulWidget {
  const _ActivityRouteGoogleMap({
    super.key,
    required this.route,
    required this.interactive,
    required this.polygons,
    required this.snapshotOverlay,
    required this.transportMode,
    required this.showEndpoints,
    required this.endpointMarkerIcons,
    required this.onViewportReady,
    this.onSnapshotCaptured,
  });

  final ActivityRoute route;
  final bool interactive;
  final Set<Polygon> polygons;
  final JourneyMapSnapshotOverlay? snapshotOverlay;
  final TransportMode? transportMode;
  final bool showEndpoints;
  final RouteEndpointMarkerIcons? endpointMarkerIcons;
  final ValueChanged<LatLngBounds>? onViewportReady;
  final ValueChanged<Uint8List>? onSnapshotCaptured;

  @override
  State<_ActivityRouteGoogleMap> createState() =>
      _ActivityRouteGoogleMapState();
}

class _ActivityRouteGoogleMapState extends State<_ActivityRouteGoogleMap> {
  /// Time given to the map to draw its tiles before each capture attempt.
  static const _tileSettleDelay = Duration(milliseconds: 900);

  /// Map tiles stream in over the network, so a first capture can come back
  /// empty on a slow connection.
  static const _maxCaptureAttempts = 3;

  GoogleMapController? _controller;
  Size? _lastLaidOutSize;
  BitmapDescriptor? _startFlagIcon;
  BitmapDescriptor? _finishFlagIcon;
  bool _isCapturing = false;
  bool _isCovered = false;
  Timer? _captureDelayTimer;
  Completer<bool>? _captureDelay;

  /// Where the map settled, for the fog to align its clouds to.
  ///
  /// Held apart from [setState] because it changes on every frame of a gesture,
  /// and rebuilding the map, its markers and its polylines that often is what
  /// the fog overlay exists to avoid.
  final ValueNotifier<CameraPosition?> _fogCamera =
      ValueNotifier<CameraPosition?>(null);

  StaticFog? _fog;
  FogAtlas? _atlas;

  /// Brightness the held atlas was baked for, and the release key for it.
  /// Null while this map holds no atlas at all.
  Brightness? _atlasBrightness;

  @override
  void initState() {
    super.initState();
    _syncFog();
    final injectedIcons = widget.endpointMarkerIcons;
    if (injectedIcons != null) {
      _startFlagIcon = injectedIcons.start;
      _finishFlagIcon = injectedIcons.finish;
      return;
    }
    if (widget.showEndpoints) {
      unawaited(_loadEndpointIcons());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAtlas();
    _syncCovered();
  }

  @override
  void didUpdateWidget(covariant _ActivityRouteGoogleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route != widget.route) {
      _fogCamera.value = null;
      _lastLaidOutSize = null;
      // The fog is anchored on the route it frames, so it is rebuilt rather
      // than left pointing at the previous journey.
      _syncFog();
      unawaited(_fitRoute());
    }
    if (!oldWidget.showEndpoints && widget.showEndpoints) {
      unawaited(_loadEndpointIcons());
    }
    if (oldWidget.endpointMarkerIcons != widget.endpointMarkerIcons) {
      final injectedIcons = widget.endpointMarkerIcons;
      if (injectedIcons != null) {
        _startFlagIcon = injectedIcons.start;
        _finishFlagIcon = injectedIcons.finish;
      }
    }
    if (oldWidget.snapshotOverlay != widget.snapshotOverlay) {
      _syncFog();
      _syncAtlas();
      unawaited(_refreshVisibleBounds());
      _captureWhenFogged();
    }
  }

  @override
  void dispose() {
    _captureDelayTimer?.cancel();
    final pendingDelay = _captureDelay;
    if (pendingDelay != null && !pendingDelay.isCompleted) {
      pendingDelay.complete(false);
    }
    final heldAtlas = _atlasBrightness;
    if (heldAtlas != null) unawaited(FogAtlasCache.release(heldAtlas));
    _fogCamera.dispose();
    _controller?.dispose();
    super.dispose();
  }

  /// Rebuilds the fog for the regions this preview's overlay cleared.
  ///
  /// An overlay that never loaded leaves the map bare rather than fogged: with
  /// no holes to cut, drawing it would bury the whole journey in cloud.
  void _syncFog() {
    final overlay = widget.snapshotOverlay;
    _fog = overlay == null || overlay.loadedBounds == null
        ? null
        : StaticFog(
            anchor: widget.route.center,
            clearedRegions: overlay.clearedRegions,
          );
  }

  /// Takes or drops this map's share of the baked cloud atlas.
  ///
  /// Safe to call whenever the fog or the theme changes; it only acts when the
  /// atlas it wants differs from the one it holds.
  void _syncAtlas() {
    final wanted = _fog == null ? null : Theme.of(context).brightness;
    if (wanted == _atlasBrightness) return;

    final held = _atlasBrightness;
    _atlasBrightness = wanted;
    _atlas = null;
    if (held != null) unawaited(FogAtlasCache.release(held));
    if (wanted != null) unawaited(_loadAtlas(wanted));
  }

  /// Tracks whether a sheet or a route has been opened over this map.
  ///
  /// Read here rather than in [build] so that depending on the route's
  /// `isCurrent` both rebuilds this map as the thing above it comes and goes,
  /// and gives a capture that was cut short a chance to notice it is back.
  void _syncCovered() {
    final isCovered = ModalRoute.isCurrentOf(context) == false;
    if (isCovered == _isCovered) return;
    _isCovered = isCovered;
    // A hidden map cannot be snapshotted, so one that was covered mid-capture
    // is owed another go now that it is drawing again.
    if (!isCovered) _captureWhenFogged();
  }

  Future<void> _loadAtlas(Brightness brightness) async {
    final atlas = await FogAtlasCache.acquire(brightness);
    if (!mounted || _atlasBrightness != brightness) return;

    setState(() => _atlas = atlas);
    // A capture that arrived before the artwork did was skipped rather than
    // stored fogless, so it is owed another go now.
    _captureWhenFogged();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final route = widget.route;
    final fog = _fog;
    final atlas = _atlas;

    // A Google Map is a native view, and on iOS it composites above everything
    // Flutter draws after it — so a preview left painting shows through any
    // sheet or route opened on top of the one it sits on. It is hidden rather
    // than unmounted so the map, and the tiles it has already fetched, survive
    // being covered and come straight back.
    return Visibility(
      visible: !_isCovered,
      maintainState: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (_lastLaidOutSize != size) {
            _lastLaidOutSize = size;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) unawaited(_fitRoute());
            });
          }

          final map = GoogleMap(
            initialCameraPosition: CameraPosition(
              target: route.center,
              zoom: 14,
            ),
            style: MapStyles.forBrightness(brightness),
            polygons: widget.polygons,
            polylines: {
              Polyline(
                polylineId: const PolylineId('activity-route'),
                points: route.points,
                color:
                    widget.transportMode?.routeColor ??
                    TransportMode.routeColorForWireValue(null),
                width: widget.interactive ? 7 : 5,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                jointType: JointType.round,
                zIndex: 20,
              ),
            },
            markers: widget.showEndpoints ? _endpointMarkers(route) : const {},
            onMapCreated: (controller) {
              _controller = controller;
              unawaited(_fitRoute());
            },
            onCameraIdle: widget.onViewportReady == null
                ? null
                : () => unawaited(_refreshVisibleBounds()),
            // Only a map that can be dragged has camera moves worth following.
            // A preview's camera is set once, programmatically, and is read back
            // off the map instead — see [_readFogCamera].
            onCameraMove: widget.interactive
                ? (position) => _fogCamera.value = position
                : null,
            compassEnabled: widget.interactive,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            myLocationEnabled: false,
            rotateGesturesEnabled: widget.interactive,
            scrollGesturesEnabled: widget.interactive,
            // The fog reproduces the map's projection in Dart to place its
            // clouds, and a tilted map is a perspective projection whose field of
            // view the plugin does not expose, so tilting would slide the map out
            // from under its own fog.
            tiltGesturesEnabled: false,
            zoomControlsEnabled: false,
            zoomGesturesEnabled: widget.interactive,
            // Lite mode renders a static map that cannot be snapshotted, so a
            // preview that owes a capture has to run the full map.
            liteModeEnabled:
                !widget.interactive && widget.onSnapshotCaptured == null,
            gestureRecognizers: widget.interactive
                ? <Factory<OneSequenceGestureRecognizer>>{
                    const Factory<EagerGestureRecognizer>(
                      EagerGestureRecognizer.new,
                    ),
                  }
                : const <Factory<OneSequenceGestureRecognizer>>{},
          );

          if (fog == null) return map;

          return Stack(
            fit: StackFit.expand,
            children: [
              map,
              StaticFogOverlay(
                fog: fog,
                atlas: atlas,
                camera: _fogCamera,
                isNight: brightness == Brightness.dark,
              ),
            ],
          );
        },
      ),
    );
  }

  Set<Marker> _endpointMarkers(ActivityRoute route) {
    final startIcon = _startFlagIcon;
    final finishIcon = _finishFlagIcon;
    if (startIcon == null || finishIcon == null) return const {};

    return {
      Marker(
        markerId: const MarkerId('route-start'),
        position: route.start,
        infoWindow: const InfoWindow(title: 'Start'),
        icon: startIcon,
        anchor: RouteMarkerIcons.flagAnchor,
        zIndexInt: 30,
      ),
      Marker(
        markerId: const MarkerId('route-finish'),
        position: route.finish,
        infoWindow: const InfoWindow(title: 'Finish'),
        icon: finishIcon,
        anchor: RouteMarkerIcons.flagAnchor,
        zIndexInt: 30,
      ),
    };
  }

  Future<void> _loadEndpointIcons() async {
    if (widget.endpointMarkerIcons != null) return;

    final icons = await RouteMarkerIcons.endpoints();
    if (!mounted) return;
    setState(() {
      _startFlagIcon = icons.start;
      _finishFlagIcon = icons.finish;
    });
  }

  Future<void> _fitRoute() async {
    final controller = _controller;
    final size = _lastLaidOutSize;
    if (controller == null ||
        size == null ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }

    final shortestSide = size.shortestSide;
    final padding = shortestSide < 260
        ? shortestSide * 0.14
        : shortestSide * 0.11;

    try {
      await controller.moveCamera(
        CameraUpdate.newLatLngBounds(widget.route.bounds, padding),
      );
    } catch (_) {
      await controller.moveCamera(
        CameraUpdate.newLatLngZoom(widget.route.center, 14),
      );
    }

    await _refreshVisibleBounds();
    _captureWhenFogged();
  }

  /// Snapshots the framed route once its fog is ready to draw.
  ///
  /// Capturing earlier would store a bare basemap, which is exactly the state
  /// this picture exists to replace, so a preview whose overlay never loaded —
  /// or whose cloud artwork has not finished baking — is left for the next
  /// rebuild to retry.
  void _captureWhenFogged() {
    if (widget.onSnapshotCaptured == null || _isCapturing) return;
    if (_controller == null) return;
    if (_fog == null || _atlas == null || _fogCamera.value == null) return;

    _isCapturing = true;
    unawaited(_captureWhenSettled());
  }

  Future<void> _captureWhenSettled() async {
    for (var attempt = 0; attempt < _maxCaptureAttempts; attempt++) {
      if (!await _waitForTilesToDraw()) return;

      try {
        final bytes = await _controller?.takeSnapshot();
        if (!mounted) return;
        if (bytes != null && bytes.isNotEmpty) {
          widget.onSnapshotCaptured?.call(await _fogged(bytes));
          return;
        }
      } catch (error) {
        debugPrint('[ActivityMapPreview] map capture failed error=$error');
      }
    }

    // Give up for now; a later rebuild of this card can try again.
    _isCapturing = false;
  }

  /// Draws this preview's clouds onto a captured map picture.
  ///
  /// The map snapshot comes from the native view, which knows nothing about the
  /// fog drawn above it in Flutter, so the two are composited here. Everything
  /// downstream — feed cards, the detail screen, the share card — shows this
  /// picture rather than a live map, and a picture without its fog would show
  /// ground the traveller never explored.
  Future<Uint8List> _fogged(Uint8List mapBytes) async {
    final fog = _fog;
    final atlas = _atlas;
    final camera = _fogCamera.value;
    final size = _lastLaidOutSize;
    if (fog == null ||
        atlas == null ||
        camera == null ||
        size == null ||
        size.isEmpty) {
      return mapBytes;
    }

    ui.Image? map;
    ui.Image? composited;
    try {
      map = await _decode(mapBytes);
      // The snapshot comes back in device pixels, so the fog is painted in the
      // logical pixels it was laid out in and scaled up to match.
      final scale = map.width / size.width;
      if (!scale.isFinite || scale <= 0) return mapBytes;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..drawImage(map, Offset.zero, Paint())
        ..scale(scale);
      fog
          .painterFor(
            camera: camera,
            atlas: atlas,
            isNight: _atlasBrightness == Brightness.dark,
          )
          .paint(canvas, Size(map.width / scale, map.height / scale));

      final picture = recorder.endRecording();
      composited = await picture.toImage(map.width, map.height);
      picture.dispose();

      final png = await composited.toByteData(format: ui.ImageByteFormat.png);
      return png?.buffer.asUint8List() ?? mapBytes;
    } catch (error) {
      // A picture of the plain map is still worth storing.
      debugPrint('[ActivityMapPreview] fog composite failed error=$error');
      return mapBytes;
    } finally {
      map?.dispose();
      composited?.dispose();
    }
  }

  static Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  /// Waits for the map to draw, reporting false if the widget went away first.
  Future<bool> _waitForTilesToDraw() {
    final delay = Completer<bool>();
    _captureDelay = delay;
    _captureDelayTimer = Timer(_tileSettleDelay, () {
      if (!delay.isCompleted) delay.complete(mounted);
    });
    return delay.future;
  }

  Future<void> _refreshVisibleBounds() async {
    final controller = _controller;
    if (controller == null || widget.snapshotOverlay == null) return;

    try {
      final bounds = await controller.getVisibleRegion();
      if (!mounted) return;
      // Reported before the camera is read, so a map that cannot answer for its
      // zoom still gets its overlay widened to the frame it settled on.
      widget.onViewportReady?.call(bounds);
      await _readFogCamera(controller, bounds);
      _captureWhenFogged();
    } catch (_) {
      // Widget tests and early native map layout can fail this call. Without a
      // viewport the preview keeps the frame it was given and stays unfogged
      // rather than clouding the wrong ground.
    }
  }

  /// Reads back the camera the map actually settled on, for the fog to align
  /// its clouds and its cleared ground to.
  ///
  /// Deliberately read rather than waited for. `onCameraMove` covers gestures
  /// and animations, but iOS does not report an instantaneous programmatic move
  /// through it — and framing a route is exactly that — so a preview that only
  /// listened kept drawing against the camera the map was built with: clouds
  /// sized for the wrong zoom, and explored regions punched out at a fraction
  /// of their size, which reads as fog over ground the traveller had cleared. A
  /// map does always idle after an explicit camera change, and answers for its
  /// own viewport and zoom on demand, so this takes the settled values from it.
  Future<void> _readFogCamera(
    GoogleMapController controller,
    LatLngBounds bounds,
  ) async {
    final fog = _fog;
    if (fog == null) return;

    final zoom = await controller.getZoomLevel();
    if (!mounted) return;
    _fogCamera.value = CameraPosition(
      target: fog.centreOf(bounds),
      zoom: zoom,
      // A viewport cannot report rotation, so a bearing from a live gesture is
      // carried over rather than flattened out from under the fog.
      bearing: _fogCamera.value?.bearing ?? 0.0,
    );
  }
}
