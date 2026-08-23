/*
 * Author: Sanjevan Rajasegar
 * Last Updated: 22 August 2026
 * Description:
 *   Shared Journey route map preview and expanded map screen for social
 *   activity surfaces, using only persisted activity route fields.
 */

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../theme/app_surfaces.dart';
import '../../journeys/domain/transport_mode.dart';
import '../../map/data/journey_map_snapshot_service.dart';
import '../../map/data/visited_region_service.dart';
import '../../map/domain/map_styles.dart';
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
      aspectRatio: widget._isDetail ? 4 / 3 : 16 / 9,
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
  });

  final ActivityRoute route;
  final bool interactive;
  final Set<Polygon> polygons;
  final JourneyMapSnapshotOverlay? snapshotOverlay;
  final TransportMode? transportMode;
  final bool showEndpoints;
  final RouteEndpointMarkerIcons? endpointMarkerIcons;
  final ValueChanged<LatLngBounds>? onViewportReady;

  @override
  State<_ActivityRouteGoogleMap> createState() =>
      _ActivityRouteGoogleMapState();
}

class _ActivityRouteGoogleMapState extends State<_ActivityRouteGoogleMap> {
  GoogleMapController? _controller;
  Size? _lastLaidOutSize;
  LatLngBounds? _visibleBounds;
  BitmapDescriptor? _startFlagIcon;
  BitmapDescriptor? _finishFlagIcon;

  @override
  void initState() {
    super.initState();
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
  void didUpdateWidget(covariant _ActivityRouteGoogleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route != widget.route) {
      _visibleBounds = null;
      _lastLaidOutSize = null;
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
      unawaited(_refreshVisibleBounds());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final route = widget.route;
    final polygons = _mapPolygons(route);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_lastLaidOutSize != size) {
          _lastLaidOutSize = size;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_fitRoute());
          });
        }

        return GoogleMap(
          initialCameraPosition: CameraPosition(target: route.center, zoom: 14),
          style: MapStyles.forBrightness(brightness),
          polygons: polygons,
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
          compassEnabled: widget.interactive,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
          myLocationEnabled: false,
          rotateGesturesEnabled: widget.interactive,
          scrollGesturesEnabled: widget.interactive,
          tiltGesturesEnabled: widget.interactive,
          zoomControlsEnabled: false,
          zoomGesturesEnabled: widget.interactive,
          liteModeEnabled: !widget.interactive,
          gestureRecognizers: widget.interactive
              ? <Factory<OneSequenceGestureRecognizer>>{
                  const Factory<EagerGestureRecognizer>(
                    EagerGestureRecognizer.new,
                  ),
                }
              : const <Factory<OneSequenceGestureRecognizer>>{},
        );
      },
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

  Set<Polygon> _mapPolygons(ActivityRoute route) {
    final snapshotOverlay = widget.snapshotOverlay;
    if (snapshotOverlay == null) return widget.polygons;

    return snapshotOverlay.polygonsForVisibleBounds(
      _visibleBounds ?? route.bounds,
    );
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
  }

  Future<void> _refreshVisibleBounds() async {
    final controller = _controller;
    if (controller == null || widget.snapshotOverlay == null) return;

    try {
      final bounds = await controller.getVisibleRegion();
      if (!mounted) return;
      setState(() => _visibleBounds = bounds);
      widget.onViewportReady?.call(bounds);
    } catch (_) {
      // Widget tests and early native map layout can fail this call. The route
      // bounds fallback still keeps the preview fogged until the map reports.
    }
  }
}
