import 'package:flutter/material.dart';
import 'package:roam_io/features/mapfeature/MapController.dart';
import 'package:roam_io/features/mapfeature/MapRender.dart';

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
    _mapController.initialise();
  }

  void _onMapStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
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
            myLocationEnabled: _mapController.myLocationEnabled,
            onMapCreated: _mapController.onMapCreated,
            onCameraIdle: _mapController.loadViewportRegions,
          ),

        ],
      ),
    );
  }
}