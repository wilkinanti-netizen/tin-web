import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tincars/l10n/app_localizations.dart';

import 'package:tincars/core/services/maps_service.dart';
import 'package:tincars/features/trips/presentation/screens/vehicle_selection_screen.dart';

class TripPlanningScreen extends ConsumerStatefulWidget {
  final LatLng? initialPickupLocation;
  final String? initialPickupAddress;

  const TripPlanningScreen({
    super.key,
    this.initialPickupLocation,
    this.initialPickupAddress,
  });

  @override
  ConsumerState<TripPlanningScreen> createState() => _TripPlanningScreenState();
}

class _TripPlanningScreenState extends ConsumerState<TripPlanningScreen> {
  // State
  LatLng? _pickupLocation;
  String _pickupAddress = "";

  // Controllers
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _pickupFocus = FocusNode();
  final FocusNode _destinationFocus = FocusNode();

  // Search State
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  String _sessionToken = const Uuid().v4();
  bool _searchingPickup = false;
  bool _isLoading = false;

  // Recent Trips
  List<Map<String, dynamic>> _recentTrips = [];

  // Maps Service
  final MapsService _mapsService = MapsService();

  @override
  void initState() {
    super.initState();
    _pickupLocation = widget.initialPickupLocation;
    if (widget.initialPickupAddress != null) {
      _pickupAddress = widget.initialPickupAddress!;
      _pickupController.text = _pickupAddress;
    } else {
      _getCurrentLocation();
    }
    _loadRecentTrips();

    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus) {
        setState(() {
          _searchingPickup = true;
          _showSuggestions = _pickupController.text.isNotEmpty;
        });
        if (_pickupController.text.isNotEmpty) {
          _onSearchChanged(_pickupController.text, true);
        }
      }
    });

    _destinationFocus.addListener(() {
      if (_destinationFocus.hasFocus) {
        setState(() {
          _searchingPickup = false;
          _showSuggestions = _destinationController.text.isNotEmpty;
        });
        if (_destinationController.text.isNotEmpty) {
          _onSearchChanged(_destinationController.text, false);
        }
      }
    });
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _pickupFocus.dispose();
    _destinationFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRecentTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recentTripsJson = prefs.getString('recent_trips');
    if (recentTripsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(recentTripsJson);
        setState(() {
          _recentTrips = List<Map<String, dynamic>>.from(decoded);
        });
      } catch (e) {
        debugPrint('Error loading recent trips: $e');
      }
    }
  }

  Future<void> _saveRecentTrip(Map<String, dynamic> trip) async {
    // Avoid duplicates
    _recentTrips.removeWhere((t) => t['place_id'] == trip['place_id']);
    _recentTrips.insert(0, trip);

    // Keep only top 10 recent trips
    if (_recentTrips.length > 10) {
      _recentTrips = _recentTrips.sublist(0, 10);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recent_trips', jsonEncode(_recentTrips));

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final location = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _pickupLocation = location;
        });
        _reverseGeocode(location);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _reverseGeocode(LatLng location) async {
    try {
      final address = await _mapsService.getAddressFromLatLng(location);
      if (mounted) {
        setState(() {
          _pickupAddress = address;
          // Si el usuario no ha modificado este campo, lo actualizamos.
          if (!_pickupFocus.hasFocus && _pickupController.text.isEmpty) {
            _pickupController.text = address;
          }
        });
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    }
  }

  void _onSearchChanged(String val, bool isPickup) async {
    if (val.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    setState(() {
      _searchingPickup = isPickup;
    });

    try {
      final suggestions = await _mapsService.getAutocompleteSuggestions(
        val,
        _sessionToken,
      );
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _showSuggestions = true;
        });
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
    }
  }

  void _onLocationSelected(Map<String, dynamic> suggestion) async {
    final placeId = suggestion['place_id'];
    final address = suggestion['description'];

    if (_searchingPickup) {
      setState(() {
        _showSuggestions = false;
        _pickupController.text =
            suggestion['structured_formatting']['main_text'] ?? address;
        _pickupAddress = address;
      });

      try {
        final location = await _mapsService.getPlaceDetails(placeId);
        setState(() {
          _pickupLocation = location;
        });
        // Move focus to destination
        _destinationFocus.requestFocus();
      } catch (e) {
        debugPrint('Error getting pickup details: $e');
      }
    } else {
      // Destination selected
      setState(() {
        _showSuggestions = false;
        _destinationController.text =
            suggestion['structured_formatting']['main_text'] ?? address;
      });

      // Save it to recent trips
      await _saveRecentTrip({
        'place_id': placeId,
        'description': address,
        'main_text': suggestion['structured_formatting']['main_text'],
        'secondary_text': suggestion['structured_formatting']['secondary_text'],
      });

      _fetchRouteAndNavigate(placeId, address);
    }
  }

  Future<void> _fetchRouteAndNavigate(
    String destPlaceId,
    String destAddress,
  ) async {
    if (_pickupLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona un origen válido primero.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final destination = await _mapsService.getPlaceDetails(destPlaceId);
      final directions = await _mapsService.getDirections(
        _pickupLocation!,
        destination,
      );

      final boundsData = directions['bounds'];
      final latLngBounds = LatLngBounds(
        southwest: LatLng(
          boundsData['southwest']['lat'],
          boundsData['southwest']['lng'],
        ),
        northeast: LatLng(
          boundsData['northeast']['lat'],
          boundsData['northeast']['lng'],
        ),
      );

      final List<LatLng> polylinePoints = directions['polyline'];

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VehicleSelectionScreen(
              pickupLocation: _pickupLocation!,
              dropoffLocation: destination,
              pickupAddress: _pickupAddress,
              dropoffAddress: destAddress,
              distanceInKm: directions['distance'],
              polylines: {
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: polylinePoints,
                  color: Colors.black,
                  width: 5,
                ),
              },
              bounds: latLngBounds,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error routing: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al calcular la ruta')),
        );
      }
    }
  }

  void _onRecentTripTapped(Map<String, dynamic> trip) {
    _destinationController.text = trip['main_text'] ?? trip['description'];
    FocusScope.of(context).unfocus();
    _fetchRouteAndNavigate(trip['place_id'], trip['description']);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          localizations.planYourTrip,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: const Offset(0, 4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Timeline Graphics
                    Column(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 35,
                          color: Colors.grey[300],
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          color: Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
                    const SizedBox(width: 15),

                    // Input Fields
                    Expanded(
                      child: Column(
                        children: [
                          TextField(
                            controller: _pickupController,
                            focusNode: _pickupFocus,
                            onChanged: (val) => _onSearchChanged(val, true),
                            decoration: InputDecoration(
                              hintText: localizations.whereAmI,
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 12,
                              ),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _destinationController,
                            focusNode: _destinationFocus,
                            onChanged: (val) => _onSearchChanged(val, false),
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: localizations.whereToDest,
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 12,
                              ),
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Suggestions or Recent Trips
              Expanded(
                child: _showSuggestions && _suggestions.isNotEmpty
                    ? ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _suggestions.length,
                        separatorBuilder: (context, index) =>
                            Divider(height: 1, color: Colors.grey[200]),
                        itemBuilder: (context, index) {
                          final suggestion = _suggestions[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.place,
                                color: Colors.black54,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              suggestion['structured_formatting']['main_text'] ??
                                  "",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              suggestion['structured_formatting']['secondary_text'] ??
                                  "",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _onLocationSelected(suggestion),
                          );
                        },
                      )
                    : _recentTrips.isNotEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Text(
                            localizations.recentTrips,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 15),
                          ..._recentTrips.map(
                            (trip) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.history,
                                  color: Colors.black54,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                trip['main_text'] ?? trip['description'] ?? "",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                trip['secondary_text'] ?? "",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _onRecentTripTapped(trip),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.map_outlined,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                localizations.searchDestination,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
