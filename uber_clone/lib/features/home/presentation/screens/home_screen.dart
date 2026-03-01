import 'package:tincars/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tincars/features/trips/presentation/screens/searching_driver_screen.dart';
import 'package:tincars/features/trips/presentation/screens/trip_tracking_screen.dart';
import 'package:tincars/features/trips/presentation/screens/trip_cancellation_screen.dart';
import 'package:tincars/features/trips/domain/models/trip_model.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tincars/core/utils/marker_utils.dart';
import 'package:tincars/features/trips/presentation/screens/vehicle_selection_screen.dart';
import 'package:tincars/features/profile/presentation/screens/set_address_screen.dart';
import 'package:tincars/features/trips/presentation/widgets/trip_status_widget.dart';
import 'package:tincars/core/utils/permission_service.dart';
import 'package:tincars/core/services/maps_service.dart';
import 'package:tincars/l10n/app_localizations.dart';
import 'package:tincars/features/home/presentation/providers/user_mode_provider.dart';
import 'package:tincars/features/trips/presentation/screens/trip_planning_screen.dart';
import 'package:tincars/features/profile/presentation/screens/driver_registration_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late GoogleMapController mapController;
  static const LatLng _center = LatLng(4.6097, -74.0817); // Bogotá, Colombia
  Set<Marker> _markers = {};
  bool _isRedirectingToTrip = false;
  BitmapDescriptor? _pickupIcon;

  BitmapDescriptor? _dropoffIcon;
  BitmapDescriptor? _vehicleIcon;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _loadMarkerIcons();
  }

  Future<void> _loadMarkerIcons() async {
    final pickup = await MarkerUtils.createABMarker(
      letter: 'A',
      backgroundColor: Colors.blueAccent,
      foregroundColor: Colors.white,
      label: 'Recogida',
    );
    final dropoff = await MarkerUtils.createABMarker(
      letter: 'B',
      backgroundColor: Colors.redAccent,
      foregroundColor: Colors.white,
      label: 'Destino',
    );
    final vehicle = await MarkerUtils.createVehicleMarker();

    if (mounted) {
      setState(() {
        _pickupIcon = pickup;
        _dropoffIcon = dropoff;
        _vehicleIcon = vehicle;
      });
    }
  }

  Future<void> _checkLocationPermission() async {
    await PermissionService.instance.handleLocationPermission(context);
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _getCurrentLocation(); // Auto-center on creation
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          16,
        ),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _onMenuPressed() {
    _scaffoldKey.currentState?.openDrawer();
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MapsService _mapsService = MapsService();
  bool _isLoadingRoute = false;

  Future<void> _handleQuickAction(String type, String title) async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString('${type}_address');
    final lat = prefs.getDouble('${type}_lat');
    final lng = prefs.getDouble('${type}_lng');

    if (address == null || lat == null || lng == null) {
      final success = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SetAddressScreen(actionType: type, title: title),
        ),
      );

      if (success == true) {
        _handleQuickAction(type, title);
      }
      return;
    }

    setState(() => _isLoadingRoute = true);

    try {
      Position position = await Geolocator.getCurrentPosition();
      final currentLoc = LatLng(position.latitude, position.longitude);
      final destLoc = LatLng(lat, lng);

      final currentAddress = await _mapsService.getAddressFromLatLng(
        currentLoc,
      );

      final directions = await _mapsService.getDirections(currentLoc, destLoc);

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

      if (!mounted) return;

      setState(() => _isLoadingRoute = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VehicleSelectionScreen(
            pickupLocation: currentLoc,
            dropoffLocation: destLoc,
            pickupAddress: currentAddress,
            dropoffAddress: address,
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
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRoute = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error calculando ruta a $title: $e')),
        );
      }
    }
  }

  Future<void> _showCancellationDialog(Trip trip) async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripCancellationScreen(trip: trip),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final activeTrip = ref.watch(activeTripProvider).asData?.value;
    final isPassenger = ref.watch(userModeProvider) == UserMode.passenger;

    // Initial redirection if trip exists (Recovery)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (activeTrip != null && !_isRedirectingToTrip && mounted) {
        if (activeTrip.status == TripStatus.requested) {
          _isRedirectingToTrip = true;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SearchingDriverScreen(
                tripId: activeTrip.id,
                pickupLocation: activeTrip.pickupLocation,
                dropoffLocation: activeTrip.dropoffLocation,
                pickupAddress: activeTrip.pickupAddress,
                dropoffAddress: activeTrip.dropoffAddress,
                vehicleType: activeTrip.vehicleType,
              ),
            ),
          ).then((_) {
            if (mounted) setState(() => _isRedirectingToTrip = false);
          });
        } else if (activeTrip.status == TripStatus.accepted ||
            activeTrip.status == TripStatus.arrived ||
            activeTrip.status == TripStatus.inProgress) {
          _isRedirectingToTrip = true;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TripTrackingScreen(tripId: activeTrip.id),
            ),
          ).then((_) {
            if (mounted) setState(() => _isRedirectingToTrip = false);
          });
        }
      }
    });

    // Auto-navigation for active trips (Status Update)
    ref.listen<AsyncValue<Trip?>>(activeTripProvider, (previous, next) {
      final trip = next.asData?.value;
      if (trip != null && !_isRedirectingToTrip) {
        if (trip.status == TripStatus.requested) {
          _isRedirectingToTrip = true;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SearchingDriverScreen(
                tripId: trip.id,
                pickupLocation: trip.pickupLocation,
                dropoffLocation: trip.dropoffLocation,
                pickupAddress: trip.pickupAddress,
                dropoffAddress: trip.dropoffAddress,
                vehicleType: trip.vehicleType,
              ),
            ),
          ).then((_) => _isRedirectingToTrip = false);
        } else if (trip.status == TripStatus.accepted ||
            trip.status == TripStatus.arrived ||
            trip.status == TripStatus.inProgress) {
          _isRedirectingToTrip = true;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TripTrackingScreen(tripId: trip.id),
            ),
          ).then((_) => _isRedirectingToTrip = false);
        }
      }
    });

    // Update markers dynamically if active trip exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (activeTrip != null) {
        final newMarkers = {
          Marker(
            markerId: const MarkerId('pickup'),
            position: activeTrip.pickupLocation,
            icon: _pickupIcon ?? BitmapDescriptor.defaultMarker,
            infoWindow: InfoWindow(title: l10n.pickup),
          ),
          Marker(
            markerId: const MarkerId('dropoff'),
            position: activeTrip.dropoffLocation,
            icon: _dropoffIcon ?? BitmapDescriptor.defaultMarker,
            infoWindow: InfoWindow(title: l10n.destination),
          ),
          if (activeTrip.driverLocation != null)
            Marker(
              markerId: const MarkerId('driver'),
              position: activeTrip.driverLocation!,
              icon: _vehicleIcon ?? BitmapDescriptor.defaultMarker,
              infoWindow: InfoWindow(title: l10n.driver),
            ),
        };

        if (_markers.length != newMarkers.length ||
            (activeTrip.driverLocation != null &&
                _markers.any(
                  (m) =>
                      m.markerId.value == 'driver' &&
                      m.position != activeTrip.driverLocation,
                ))) {
          setState(() => _markers = newMarkers);

          // Auto-zoom if markers changed
          final points = [
            activeTrip.pickupLocation,
            activeTrip.dropoffLocation,
            if (activeTrip.driverLocation != null) activeTrip.driverLocation!,
          ];

          double minLat = points.first.latitude;
          double maxLat = points.first.latitude;
          double minLng = points.first.longitude;
          double maxLng = points.first.longitude;

          for (var p in points) {
            if (p.latitude < minLat) minLat = p.latitude;
            if (p.latitude > maxLat) maxLat = p.latitude;
            if (p.longitude < minLng) minLng = p.longitude;
            if (p.longitude > maxLng) maxLng = p.longitude;
          }

          mapController.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(minLat, minLng),
                northeast: LatLng(maxLat, maxLng),
              ),
              80,
            ),
          );
        }
      } else if (_markers.isNotEmpty) {
        setState(() => _markers = {});
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      drawer: _buildDrawer(context, ref),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: _center,
              zoom: 16.0,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Shadow Gradient at Bottom (behind the bottom sheet)
          if (activeTrip == null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 100,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.1), Colors.transparent],
                  ),
                ),
              ),
            ),

          // Premium Bottom Search Card
          if (activeTrip == null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: 34,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Hola,',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¿A dónde vamos hoy?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Search Input Trigger
                    GestureDetector(
                      onTap: () async {
                        LatLng? pickupLoc;
                        try {
                          Position position =
                              await Geolocator.getCurrentPosition();
                          pickupLoc = LatLng(
                            position.latitude,
                            position.longitude,
                          );
                        } catch (e) {
                          pickupLoc = _center;
                        }

                        if (!mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TripPlanningScreen(
                              initialPickupLocation: pickupLoc,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search,
                              color: Colors.black87,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Buscar destino',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black.withOpacity(0.6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Quick Actions
                    Row(
                      children: [
                        _buildQuickAction(
                          icon: Icons.home_rounded,
                          label: 'Casa',
                          onTap: () =>
                              _handleQuickAction('casa', 'Configurar Casa'),
                        ),
                        const SizedBox(width: 12),
                        _buildQuickAction(
                          icon: Icons.work_rounded,
                          label: 'Trabajo',
                          onTap: () => _handleQuickAction(
                            'trabajo',
                            'Configurar Trabajo',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Active Trip Widget
          if (activeTrip != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: TripStatusWidget(
                trip: activeTrip,
                onCancel: () => _showCancellationDialog(activeTrip),
              ),
            ),

          // Custom Menu Button (Only for Drivers)
          if (!isPassenger)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: Colors.black,
                    size: 26,
                  ),
                  onPressed: _onMenuPressed,
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(),
                ),
              ),
            ),

          // Map Control Buttons (Stacked)
          Positioned(
            bottom: activeTrip != null ? 320 : 280,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'loc_btn',
                  onPressed: _getCurrentLocation,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: Colors.black),
                ),
              ],
            ),
          ),

          if (_isLoadingRoute)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final l10n = AppLocalizations.of(context)!;
    final fullName = user?.userMetadata?['full_name'] ?? l10n.user;

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.black),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Colors.black, size: 40),
            ),
            accountName: Text(
              fullName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(user?.email ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(l10n.yourTripsHistory),
            onTap: () {
              Navigator.pop(context); // Close drawer
              // The user is already in HomeScreen (Passenger),
              // maybe they want to go to Profile/History.
              // We'll use a controller or just navigate to ProfileScreen.
              // But ProfileScreen is already in the main navigation probably.
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.myProfile),
            onTap: () {
              Navigator.pop(context);
              // Navigate to profile (this depends on your router/nav structure)
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.drive_eta),
            title: Text(l10n.switchToDriver),
            onTap: () async {
              Navigator.pop(context); // Close drawer
              final user = Supabase.instance.client.auth.currentUser;
              if (user == null) return;

              final profileResponse = await Supabase.instance.client
                  .from('profiles')
                  .select('driver_status')
                  .eq('id', user.id)
                  .maybeSingle();

              final status = profileResponse?['driver_status'] as String?;
              AppLogger.log(
                '===================================================',
              );
              AppLogger.log('🔍 VERIFICACIÓN DE CONDUCTOR 🔍');
              AppLogger.log('👤 Usuario ID: ${user.id}');
              AppLogger.log(
                '📄 Estado en BD (profiles.driver_status): $status',
              );
              if (status == 'active') {
                print(
                  '✅ ESTADO: ACEPTADO. Permitiendo acceso al modo conductor.',
                );
              } else if (status == 'pending') {
                print(
                  '⏳ ESTADO: PENDIENTE. Bloqueando acceso por falta de aprobación del ADMIN.',
                );
              } else if (status == 'rejected') {
                print(
                  '❌ ESTADO: RECHAZADO. Bloqueando acceso (documentos denegados).',
                );
              } else {
                print(
                  '⚠️ ESTADO: NO REGISTRADO o INACTIVO. Redirigiendo a pantalla de registro.',
                );
              }
              AppLogger.log(
                '===================================================',
              );

              if (status == null || status == 'inactive' || status.isEmpty) {
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DriverRegistrationScreen(),
                    ),
                  );
                }
                return;
              } else if (status == 'rejected') {
                final verificationData = await Supabase.instance.client
                    .from('driver_verifications')
                    .select('rejection_reason')
                    .eq('driver_id', user.id)
                    .order('created_at', ascending: false)
                    .limit(1)
                    .maybeSingle();
                final reason =
                    verificationData?['rejection_reason'] as String? ??
                    'No se especificó motivo.';
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: Text(l10n.accessDenied),
                      content: Text('${l10n.accessDenied}: $reason'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.close),
                        ),
                      ],
                    ),
                  );
                }
                return;
              } else if (status == 'pending') {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.requestPending)));
                }
                return;
              }

              ref.read(userModeProvider.notifier).toggleMode();
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.logout),
                  content: Text(l10n.logoutConfirm),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l10n.confirm),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await Supabase.instance.client.auth.signOut();
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.black87, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
