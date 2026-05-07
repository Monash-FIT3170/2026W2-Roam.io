import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:roam_io/features/auth/presentation/providers/auth_provider.dart';
import 'package:roam_io/features/mapfeature/MapController.dart';
import 'package:roam_io/features/mapfeature/MapRender.dart';
import 'package:roam_io/features/mapfeature/PlaceDetailsSheet.dart';
import 'package:roam_io/features/mapfeature/PlaceOfInterest.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();

    _mapController = MapController();
    _mapController.addListener(_onMapStateChanged);
    _mapController.onPlaceSelected = _showPlaceDetails;
    
    // Get user ID from auth provider and initialize
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      _mapController.initialise(userId: authProvider.currentUser?.uid);
    });
  }

  void _onMapStateChanged() {
    if (mounted) setState(() {});
  }

  void _showPlaceDetails(PlaceOfInterest place) {
    PlaceDetailsSheet.show(
      context: context,
      place: place,
      mapController: _mapController,
    );
  }

  @override
  void dispose() {
    _mapController.onPlaceSelected = null;
    _mapController.removeListener(_onMapStateChanged);
    _mapController.disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapRender(
            initialCenter: _mapController.center,
            polygons: _mapController.polygons,
            markers: _mapController.markers,
            myLocationEnabled: _mapController.myLocationEnabled,
            onMapCreated: _mapController.onMapCreated,
            onCameraIdle: _mapController.loadViewportRegions,
            onCameraMove: _mapController.onCameraMove,
          ),

        ],
      ),
    );
  }
}