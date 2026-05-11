import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tincars/core/services/maps_service.dart';
import 'package:tincars/core/utils/map_styles.dart';
import 'package:flutter/services.dart';

class MapSelectionScreen extends StatefulWidget {
  final LatLng initialPosition;
  final String title;

  const MapSelectionScreen({
    super.key,
    required this.initialPosition,
    this.title = "Selecciona en el mapa",
  });

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  late GoogleMapController _mapController;
  late LatLng _currentCenter;
  String _currentAddress = "Cargando dirección...";
  bool _isReverseGeocoding = false;
  final MapsService _mapsService = MapsService();

  @override
  void initState() {
    super.initState();
    _currentCenter = widget.initialPosition;
    _performReverseGeocode(_currentCenter);
  }

  Future<void> _performReverseGeocode(LatLng location) async {
    setState(() {
      _isReverseGeocoding = true;
    });

    try {
      final address = await _mapsService.getAddressFromLatLng(location);
      if (mounted) {
        setState(() {
          _currentAddress = address;
          _isReverseGeocoding = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress = "Dirección no encontrada";
          _isReverseGeocoding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialPosition,
              zoom: 17,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _mapController.setMapStyle(MapStyles.silverStyle);
            },
            onCameraMove: (position) {
              _currentCenter = position.target;
            },
            onCameraIdle: () {
              _performReverseGeocode(_currentCenter);
              HapticFeedback.selectionClick();
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Center Pin Marker
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 35),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "¿RECOGER AQUÍ?",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.location_on, size: 45, color: Colors.black),
                ],
              ),
            ),
          ),

          // Bottom Info Card
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                // My Location Button
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: () async {
                        final pos = await Geolocator.getCurrentPosition();
                        _mapController.animateCamera(
                          CameraUpdate.newLatLng(
                            LatLng(pos.latitude, pos.longitude),
                          ),
                        );
                      },
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.my_location, color: Colors.black),
                    ),
                  ),
                ),

                // Address & Confirm Button
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.place,
                            color: Colors.blueAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isReverseGeocoding
                                  ? "Ubicando..."
                                  : _currentAddress,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed:
                            _isReverseGeocoding ||
                                _currentAddress == "Dirección no encontrada"
                            ? null
                            : () {
                                Navigator.pop(context, {
                                  'location': _currentCenter,
                                  'address': _currentAddress,
                                });
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "CONFIRMAR PUNTO",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
