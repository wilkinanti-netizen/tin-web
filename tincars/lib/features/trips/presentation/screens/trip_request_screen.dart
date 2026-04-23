import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tincars/l10n/app_localizations.dart';

import 'package:tincars/core/services/maps_service.dart';
import 'package:tincars/features/trips/presentation/screens/trip_planning_screen.dart';

class TripRequestScreen extends ConsumerStatefulWidget {
  const TripRequestScreen({super.key});

  @override
  ConsumerState<TripRequestScreen> createState() => _TripRequestScreenState();
}

class _TripRequestScreenState extends ConsumerState<TripRequestScreen> {
  late GoogleMapController mapController;
  static const LatLng _center = LatLng(4.6097, -74.0817); // Bogotá, Colombia

  // State
  LatLng? _pickupLocation;

  // Controllers
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  // Maps Service
  final MapsService _mapsService = MapsService();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null && mounted) {
        final lastLocation = LatLng(
          lastPosition.latitude,
          lastPosition.longitude,
        );
        setState(() {
          _pickupLocation = lastLocation;
        });
        _reverseGeocode(lastLocation);
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final location = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _pickupLocation = location;
        });
        mapController.animateCamera(CameraUpdate.newLatLngZoom(location, 16));
        _reverseGeocode(location);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _reverseGeocode(LatLng location) async {
    try {
      await _mapsService.getAddressFromLatLng(location);
      if (mounted) {
        // Obteniendo dirección
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _pickupLocation ?? _center,
              zoom: 15.0,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: const {}, // Quitamos los markers para un look más limpio
          ),

          // "Where to?" Floating Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TripPlanningScreen(
                      initialPickupLocation: _pickupLocation,
                      // We don't have _pickupAddress here anymore, TripPlanningScreen will reverse geocode or use empty if null
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 15),
                    Text(
                      localizations.whereTo,
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            Theme.of(
                              context,
                            ).textTheme.bodyLarge?.color?.withOpacity(0.7) ??
                            Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              onPressed: _getCurrentLocation,
              backgroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.my_location, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
