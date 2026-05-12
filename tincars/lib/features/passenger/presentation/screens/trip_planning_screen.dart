import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:tincars/l10n/app_localizations.dart';

import 'package:tincars/core/services/maps_service.dart';
import 'package:tincars/features/passenger/presentation/screens/vehicle_selection_screen.dart';
import 'package:tincars/features/passenger/presentation/screens/map_selection_screen.dart';
import 'package:tincars/features/profile/presentation/screens/set_address_screen.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';

class TripPlanningScreen extends ConsumerStatefulWidget {
  final LatLng? initialPickupLocation;
  final String? initialPickupAddress;
  final LatLng? initialDropoffLocation;
  final String? initialDropoffAddress;

  const TripPlanningScreen({
    super.key,
    this.initialPickupLocation,
    this.initialPickupAddress,
    this.initialDropoffLocation,
    this.initialDropoffAddress,
  });

  @override
  ConsumerState<TripPlanningScreen> createState() => _TripPlanningScreenState();
}

class _TripPlanningScreenState extends ConsumerState<TripPlanningScreen> {
  // State
  LatLng? _pickupLocation;
  String _pickupAddress = "";

  // Intermediate Stops
  LatLng? _stop1Location;
  LatLng? _stop2Location;

  // Controllers
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _stop1Controller = TextEditingController();
  final TextEditingController _stop2Controller = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  final FocusNode _pickupFocus = FocusNode();
  final FocusNode _stop1Focus = FocusNode();
  final FocusNode _stop2Focus = FocusNode();
  final FocusNode _destinationFocus = FocusNode();

  // Search State
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  String _sessionToken = Uuid().v4();

  // 0: pickup, 1: stop1, 2: stop2, 3: destination
  int _searchingIndex = 0;
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
          _searchingIndex = 0;
          _showSuggestions = _pickupController.text.isNotEmpty;
        });
        if (_pickupController.text.isNotEmpty) {
          _onSearchChanged(_pickupController.text, 0);
        }
      }
    });

    _stop1Focus.addListener(() {
      if (_stop1Focus.hasFocus) {
        setState(() {
          _searchingIndex = 1;
          _showSuggestions = _stop1Controller.text.isNotEmpty;
        });
        if (_stop1Controller.text.isNotEmpty) {
          _onSearchChanged(_stop1Controller.text, 1);
        }
      }
    });

    _stop2Focus.addListener(() {
      if (_stop2Focus.hasFocus) {
        setState(() {
          _searchingIndex = 2;
          _showSuggestions = _stop2Controller.text.isNotEmpty;
        });
        if (_stop2Controller.text.isNotEmpty) {
          _onSearchChanged(_stop2Controller.text, 2);
        }
      }
    });

    _destinationFocus.addListener(() {
      if (_destinationFocus.hasFocus) {
        setState(() {
          _searchingIndex = 3;
          _showSuggestions = _destinationController.text.isNotEmpty;
        });
        if (_destinationController.text.isNotEmpty) {
          _onSearchChanged(_destinationController.text, 3);
        }
      }
    });

    if (widget.initialDropoffLocation != null &&
        widget.initialDropoffAddress != null) {
      _destinationController.text = widget.initialDropoffAddress!;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pickupLocation != null && mounted) {
          _fetchRouteAndNavigate(
            '',
            widget.initialDropoffAddress!,
            destinationOverride: widget.initialDropoffLocation,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _stop1Controller.dispose();
    _stop2Controller.dispose();
    _destinationController.dispose();
    _pickupFocus.dispose();
    _stop1Focus.dispose();
    _stop2Focus.dispose();
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
      // Try to get last known position first for speed
      Position? position = await Geolocator.getLastKnownPosition();

      if (position != null && mounted) {
        final location = LatLng(position.latitude, position.longitude);
        setState(() {
          _pickupLocation = location;
        });
        _reverseGeocode(location);
      }

      // Then get fresh position
      position = await Geolocator.getCurrentPosition(
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
          // O si el campo está vacío, lo llenamos.
          if (_pickupController.text.isEmpty ||
              _pickupController.text == "Obteniendo ubicación...") {
            _pickupController.text = address;
          }
        });
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    }
  }

  Timer? _debounceTimer;

  void _onSearchChanged(String val, int index) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    if (val.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    setState(() {
      _searchingIndex = index;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
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
    });
  }

  void _onSelectOnMapTapped() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapSelectionScreen(
          initialPosition: _pickupLocation ?? const LatLng(4.6097, -74.0817),
          title: _searchingIndex == 0
              ? "Punto de recogida"
              : "Destino del viaje",
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      final location = result['location'] as LatLng;
      final address = result['address'] as String;

      if (_searchingIndex == 0) {
        setState(() {
          _pickupLocation = location;
          _pickupAddress = address;
          _pickupController.text = address;
          _showSuggestions = false;
        });
        _destinationFocus.requestFocus();
      } else if (_searchingIndex == 1) {
        setState(() {
          _stop1Location = location;
          _stop1Controller.text = address;
          _showSuggestions = false;
        });
      } else if (_searchingIndex == 2) {
        setState(() {
          _stop2Location = location;
          _stop2Controller.text = address;
          _showSuggestions = false;
        });
      } else {
        setState(() {
          _showSuggestions = false;
          _destinationController.text = address;
        });
        _fetchRouteAndNavigate('', address, destinationOverride: location);
      }
    }
  }

  Widget _buildSavedPlaceItem({
    required IconData icon,
    required String label,
    required String type,
  }) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        final address = snapshot.data?.getString('${type}_address');
        final lat = snapshot.data?.getDouble('${type}_lat');
        final lng = snapshot.data?.getDouble('${type}_lng');

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            if (address != null && lat != null && lng != null) {
              final loc = LatLng(lat, lng);
              if (_searchingIndex == 0) {
                setState(() {
                  _pickupLocation = loc;
                  _pickupAddress = address;
                  _pickupController.text = address;
                });
                _destinationFocus.requestFocus();
              } else if (_searchingIndex == 1) {
                setState(() {
                  _stop1Location = loc;
                  _stop1Controller.text = address;
                });
              } else if (_searchingIndex == 2) {
                setState(() {
                  _stop2Location = loc;
                  _stop2Controller.text = address;
                });
              } else {
                setState(() {
                  _destinationController.text = address;
                });
                _fetchRouteAndNavigate('', address, destinationOverride: loc);
              }
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SetAddressScreen(
                    actionType: type,
                    title: 'Configurar $label',
                  ),
                ),
              ).then((value) {
                if (value == true) setState(() {});
              });
            }
          },
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: Colors.black54),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onLocationSelected(Map<String, dynamic> suggestion) async {
    final placeId = suggestion['place_id'];
    final address = suggestion['description'];

    if (_searchingIndex == 0) {
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
    } else if (_searchingIndex == 1) {
      setState(() {
        _showSuggestions = false;
        _stop1Controller.text =
            suggestion['structured_formatting']['main_text'] ?? address;
      });
      try {
        final location = await _mapsService.getPlaceDetails(placeId);
        setState(() {
          _stop1Location = location;
        });
      } catch (e) {
        debugPrint('Error getting stop 1 details: $e');
      }
    } else if (_searchingIndex == 2) {
      setState(() {
        _showSuggestions = false;
        _stop2Controller.text =
            suggestion['structured_formatting']['main_text'] ?? address;
      });
      try {
        final location = await _mapsService.getPlaceDetails(placeId);
        setState(() {
          _stop2Location = location;
        });
      } catch (e) {
        debugPrint('Error getting stop 2 details: $e');
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
    String destAddress, {
    LatLng? destinationOverride,
  }) async {
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
      final destination =
          destinationOverride ??
          await _mapsService.getPlaceDetails(destPlaceId);

      // Collect waypoints
      final List<LatLng> waypoints = [];
      final List<TripStop> intermediateStops = [];

      if (_stop1Location != null) {
        waypoints.add(_stop1Location!);
        intermediateStops.add(
          TripStop(location: _stop1Location!, address: _stop1Controller.text),
        );
      }
      if (_stop2Location != null) {
        waypoints.add(_stop2Location!);
        intermediateStops.add(
          TripStop(location: _stop2Location!, address: _stop2Controller.text),
        );
      }

      final directions = await _mapsService.getDirections(
        _pickupLocation!,
        destination,
        waypoints: waypoints,
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
              intermediateStops: intermediateStops,
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
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline Graphics
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Column(
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
                            height:
                                _stop1Location != null || _stop1Focus.hasFocus
                                ? (_stop2Location != null ||
                                          _stop2Focus.hasFocus
                                      ? 120
                                      : 80)
                                : 40,
                            color: Colors.grey[300],
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            color: Theme.of(context).primaryColor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),

                    // Input Fields
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSearchField(
                            controller: _pickupController,
                            focusNode: _pickupFocus,
                            hint: localizations.whereAmI,
                            onChanged: (val) => _onSearchChanged(val, 0),
                          ),
                          const SizedBox(height: 10),

                          // Intermediate Stop 1
                          if (_stop1Location != null ||
                              _stop1Focus.hasFocus ||
                              _searchingIndex == 1)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildSearchField(
                                controller: _stop1Controller,
                                focusNode: _stop1Focus,
                                hint: "Añadir parada",
                                onChanged: (val) => _onSearchChanged(val, 1),
                                suffix: IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _stop1Location = null;
                                      _stop1Controller.clear();
                                      if (_searchingIndex == 1)
                                        _destinationFocus.requestFocus();
                                    });
                                  },
                                ),
                              ),
                            ),

                          // Intermediate Stop 2
                          if (_stop2Location != null ||
                              _stop2Focus.hasFocus ||
                              _searchingIndex == 2)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildSearchField(
                                controller: _stop2Controller,
                                focusNode: _stop2Focus,
                                hint: "Añadir parada 2",
                                onChanged: (val) => _onSearchChanged(val, 2),
                                suffix: IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _stop2Location = null;
                                      _stop2Controller.clear();
                                      if (_searchingIndex == 2)
                                        _destinationFocus.requestFocus();
                                    });
                                  },
                                ),
                              ),
                            ),

                          Row(
                            children: [
                              Expanded(
                                child: _buildSearchField(
                                  controller: _destinationController,
                                  focusNode: _destinationFocus,
                                  hint: localizations.whereToDest,
                                  onChanged: (val) => _onSearchChanged(val, 3),
                                  autofocus: true,
                                ),
                              ),
                              if (_stop1Location == null ||
                                  _stop2Location == null)
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () {
                                    setState(() {
                                      if (_stop1Location == null &&
                                          !(_stop1Focus.hasFocus ||
                                              _searchingIndex == 1)) {
                                        _searchingIndex = 1;
                                        _stop1Focus.requestFocus();
                                      } else if (_stop2Location == null) {
                                        _searchingIndex = 2;
                                        _stop2Focus.requestFocus();
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Suggestions or Recent Trips
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Saved Places Shortcuts
                      if (!_showSuggestions)
                        Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          margin: const EdgeInsets.only(top: 15),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _buildSavedPlaceItem(
                                icon: Icons.home_rounded,
                                label: 'Casa',
                                type: 'casa',
                              ),
                              _buildSavedPlaceItem(
                                icon: Icons.work_rounded,
                                label: 'Trabajo',
                                type: 'trabajo',
                              ),
                              _buildSavedPlaceItem(
                                icon: Icons.star_rounded,
                                label: 'Favoritos',
                                type: 'favoritos',
                              ),
                            ],
                          ),
                        ),

                      _showSuggestions
                          ? ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(20),
                              itemCount: _suggestions.length + 1,
                              separatorBuilder: (context, index) =>
                                  Divider(height: 1, color: Colors.grey[200]),
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent.withValues(
                                          alpha: 0.1,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.map_rounded,
                                        color: Colors.blueAccent,
                                        size: 20,
                                      ),
                                    ),
                                    title: const Text(
                                      "Fijar ubicación en el mapa",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                    onTap: _onSelectOnMapTapped,
                                  );
                                }
                                final suggestion = _suggestions[index - 1];
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
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
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
                                      trip['main_text'] ??
                                          trip['description'] ??
                                          "",
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
                                    // Add select on map even when empty
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent.withValues(
                                            alpha: 0.1,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.map_rounded,
                                          color: Colors.blueAccent,
                                          size: 20,
                                        ),
                                      ),
                                      title: const Text(
                                        "Fijar ubicación en el mapa",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                      onTap: _onSelectOnMapTapped,
                                    ),
                                    const SizedBox(height: 40),
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
                    ],
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

  Widget _buildSearchField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required Function(String) onChanged,
    bool autofocus = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      autofocus: autofocus,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[100],
        suffixIcon: suffix,
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
    );
  }
}
