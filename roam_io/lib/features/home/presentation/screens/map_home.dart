import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_io/sa2_overlay.dart';

class MapHome extends StatefulWidget {
  const MapHome({super.key});

  @override
  State<MapHome> createState() => _MapHomeState();
}

class _MapHomeState extends State<MapHome> {
  static const LatLng _fallbackCenter = LatLng(-37.8136, 144.9631);

  Set<Polygon> _sa2Polygons = <Polygon>{};
  bool _isLoadingSA2 = false;
  String? _tappedSA2Name;

  GoogleMapController? _mapController;
  LatLng _cameraTarget = _fallbackCenter;
  bool _isFetchingLocation = true;
  bool _hasLocationPermission = false;
  String? _locationMessage;

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // Single entry point — waits for location before loading polygons
  Future<void> _initMap() async {
    final LatLng location = await _centerMapOnUserLocation();
    await _loadSA2Overlay(location: location);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _moveCameraTo(_cameraTarget);
  }

  // Returns the resolved user location (or fallback)
  Future<LatLng> _centerMapOnUserLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setLocationState(
          hasPermission: false,
          isFetching: false,
          message: 'Turn on location services to open the map around you.',
        );
        return _fallbackCenter;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _setLocationState(
          hasPermission: false,
          isFetching: false,
          message: 'Location permission was denied, so the default map view is shown.',
        );
        return _fallbackCenter;
      }

      if (permission == LocationPermission.deniedForever) {
        _setLocationState(
          hasPermission: false,
          isFetching: false,
          message: 'Location permission is permanently denied. Enable it in settings to center the map on you.',
        );
        return _fallbackCenter;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final LatLng userTarget = LatLng(position.latitude, position.longitude);
      if (!mounted) return _fallbackCenter;

      setState(() {
        _cameraTarget = userTarget;
        _hasLocationPermission = true;
        _isFetchingLocation = false;
        _locationMessage = null;
      });

      _moveCameraTo(userTarget);
      return userTarget;
    } catch (_) {
      _setLocationState(
        hasPermission: false,
        isFetching: false,
        message: 'We could not determine your current location, so the default map view is shown.',
      );
      return _fallbackCenter;
    }
  }

  Future<void> _loadSA2Overlay({required LatLng location}) async {
    if (!mounted) return;
    setState(() => _isLoadingSA2 = true);

    final String filterState = _resolveStateFromTarget(location);
    debugPrint('Loading SA2 for: $filterState at $location');

    try {
      final Set<Polygon> polygons = await SA2Overlay.loadPolygons(
        strokeColor: Colors.red,
        fillColor: const Color(0x00000000),
        strokeWidth: 3.0,
        filterState: filterState,
        onTap: (String name) {
          if (!mounted) return;
          setState(() => _tappedSA2Name = name);
        },
      );

      if (!mounted) return;
      setState(() {
        _sa2Polygons = polygons;
        _isLoadingSA2 = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingSA2 = false);
      debugPrint('Failed to load SA2 overlay: $error');
    }
  }

  /// Maps a LatLng to an Australian state name for SA2 filtering.
  /// Checks more specific/smaller regions first to avoid bounding box overlaps.
  String _resolveStateFromTarget(LatLng target) {
    final double lat = target.latitude;
    final double lng = target.longitude;

    // ACT — check before NSW as it's entirely surrounded by it
    if (lat >= -35.9 && lat <= -35.1 && lng >= 148.7 && lng <= 149.4) {
      return 'Australian Capital Territory';
    }
    // Tasmania — isolated, check early
    if (lat >= -43.7 && lat <= -39.5 && lng >= 143.8 && lng <= 148.5) {
      return 'Tasmania';
    }
    // NSW — check before Victoria (overlapping bounding boxes in SE corner)
    if (lat >= -37.5 && lat <= -28.2 && lng >= 141.0 && lng <= 153.6) {
      return 'New South Wales';
    }
    // Victoria
    if (lat >= -39.2 && lat <= -33.9 && lng >= 140.9 && lng <= 150.0) {
      return 'Victoria';
    }
    // Queensland
    if (lat >= -29.2 && lat <= -10.0 && lng >= 137.9 && lng <= 153.6) {
      return 'Queensland';
    }
    // South Australia
    if (lat >= -38.1 && lat <= -25.9 && lng >= 129.0 && lng <= 141.0) {
      return 'South Australia';
    }
    // Western Australia
    if (lat >= -35.1 && lat <= -13.7 && lng >= 112.9 && lng <= 129.0) {
      return 'Western Australia';
    }
    // Northern Territory
    if (lat >= -26.0 && lat <= -10.9 && lng >= 129.0 && lng <= 138.0) {
      return 'Northern Territory';
    }

    return 'Victoria'; // fallback
  }

  void _setLocationState({
    required bool hasPermission,
    required bool isFetching,
    String? message,
  }) {
    if (!mounted) return;
    setState(() {
      _hasLocationPermission = hasPermission;
      _isFetchingLocation = isFetching;
      _locationMessage = message;
    });
  }

  Future<void> _moveCameraTo(LatLng target) async {
    final GoogleMapController? controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
  }

  @override
  Widget build(BuildContext context) {
    final String? locationBannerText = _isFetchingLocation
        ? 'Finding your location...'
        : _locationMessage;
    final bool showLocationBanner = locationBannerText != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roam Map'),
        elevation: 2,
      ),
      body: Stack(
        children: <Widget>[
          GoogleMap(
            onMapCreated: _onMapCreated,
            myLocationEnabled: _hasLocationPermission,
            myLocationButtonEnabled: _hasLocationPermission,
            polygons: _sa2Polygons,
            initialCameraPosition: CameraPosition(
              target: _cameraTarget,
              zoom: 11,
            ),
          ),
          if (_isLoadingSA2)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: _StatusBanner(
                icon: Icons.layers,
                message: 'Loading SA2 boundaries...',
                showSpinner: true,
              ),
            ),
          if (showLocationBanner)
            Positioned(
              top: _isLoadingSA2 ? 72 : 16,
              left: 0,
              right: 0,
              child: _StatusBanner(
                icon: _hasLocationPermission ? Icons.my_location : Icons.location_off,
                message: locationBannerText,
              ),
            ),
          if (_tappedSA2Name != null)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.location_on, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _tappedSA2Name!,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _tappedSA2Name = null),
                        child: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    this.icon,
    required this.message,
    this.showSpinner = false,
  });

  final IconData? icon;
  final String message;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              blurRadius: 6,
              color: Colors.black26,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (showSpinner)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (icon != null)
              Icon(icon, size: 18),
            const SizedBox(width: 8),
            Flexible(child: Text(message)),
          ],
        ),
      ),
    );
  }
}