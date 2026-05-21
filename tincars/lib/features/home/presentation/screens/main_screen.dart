import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tincars/core/services/session_service.dart';
import 'package:go_router/go_router.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/features/profile/presentation/screens/profile_screen.dart';
import 'package:tincars/features/passenger/presentation/screens/activity_screen.dart';
import 'package:tincars/features/passenger/presentation/screens/home_screen.dart';
import 'package:tincars/features/home/presentation/providers/user_mode_provider.dart';
import 'package:tincars/features/driver/presentation/screens/driver_home_screen.dart';
import 'package:tincars/features/trips/presentation/controllers/trip_controller.dart';
import 'package:tincars/features/driver/presentation/screens/earnings_screen.dart';
import 'package:tincars/features/trips/presentation/screens/trips_screen.dart';
import 'package:tincars/features/profile/domain/models/profiles.dart';

import 'package:tincars/core/widgets/mode_switch_overlay.dart';
import 'package:tincars/features/home/presentation/providers/main_nav_provider.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  StreamSubscription? _profileSubscription;
  String? _currentDeviceId;

  @override
  void initState() {
    super.initState();
    _setupSessionGuard();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }

  Future<void> _setupSessionGuard() async {
    _currentDeviceId = await SessionService.getUniqueDeviceId();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Listen to profile changes in Firestore
    _profileSubscription = FirebaseFirestore.instance
        .collection('profiles')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data();
            final remoteDeviceId = data?['device_id'] as String?;
            if (remoteDeviceId != null && remoteDeviceId != _currentDeviceId) {
              _handleExternalLogout();
            }
          }
        });
  }

  void _handleExternalLogout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Sesión Cerrada'),
          content: const Text(
            'Se ha iniciado sesión en otro dispositivo. Por seguridad, se ha cerrado la sesión en este teléfono.',
          ),
          actions: [
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to profile to set initial mode once
    ref.listen(userProfileProvider, (previous, next) {
      final value = next.asData?.value;
      if (value != null && value.lastMode != null) {
        final mode = value.lastMode == 'driver'
            ? UserMode.driver
            : UserMode.passenger;
        // Only set if different to avoid redundant updates
        if (ref.read(userModeProvider) != mode) {
          ref.read(userModeProvider.notifier).setMode(mode);
        }
      }
    });

    // Activar el listener de notificaciones de viaje
    ref.watch(tripNotificationProvider);

    final currentMode = ref.watch(userModeProvider);
    final isPassenger = currentMode == UserMode.passenger;
    final isTransitioning = ref.watch(isModeTransitioningProvider);
    final currentIndex = ref.watch(mainNavIndexProvider);

    final userProfileAsync = ref.watch(userProfileProvider);

    return userProfileAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      ),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (userProfile) {
        final isDriverActive =
            !isPassenger && userProfile?.driverStatus == DriverStatus.active;

        if (!isPassenger && !isDriverActive) {
          return const DriverHomeScreen();
        }

        final incomingTrips =
            ref.watch(requestedTripsProvider).asData?.value ?? [];
        final activeTrip = ref.watch(activeTripProvider).asData?.value;
        final isDriverOfActiveTrip =
            activeTrip != null &&
            activeTrip.driverId == FirebaseAuth.instance.currentUser?.uid;
        final hideBottomBar =
            !isPassenger && (incomingTrips.isNotEmpty || isDriverOfActiveTrip);

        final List<Widget> passengerScreens = [
          const HomeScreen(),
          const ActivityScreen(),
          const ProfileScreen(),
        ];

        final List<Widget> driverScreens = [
          const DriverHomeScreen(),
          const EarningsScreen(),
          const TripsScreen(),
          const ProfileScreen(),
        ];

        final screens = isPassenger ? passengerScreens : driverScreens;

        // Reset index if it's out of bounds after mode switch
        if (currentIndex >= screens.length) {
          Future.microtask(
            () => ref.read(mainNavIndexProvider.notifier).setIndex(0),
          );
        }

        return Scaffold(
          body: Stack(
            children: [
              IndexedStack(index: currentIndex, children: screens),

              // Mode indicator removed as per user request
              if (isTransitioning)
                ModeSwitchOverlay(
                  toDriver: !isPassenger,
                  onComplete: () {
                    ref.read(isModeTransitioningProvider.notifier).stop();
                  },
                ),
            ],
          ),
          bottomNavigationBar: hideBottomBar
              ? null
              : Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 10,
                    top: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: isPassenger
                        ? [
                            _buildNavItem(
                              0,
                              Icons.directions_car_filled_rounded,
                              'Viajar',
                              isPassenger,
                              currentIndex,
                            ),
                            _buildNavItem(
                              1,
                              Icons.receipt_long_rounded,
                              'Actividad',
                              isPassenger,
                              currentIndex,
                            ),
                            _buildNavItem(
                              2,
                              Icons.person_rounded,
                              'Perfil',
                              isPassenger,
                              currentIndex,
                            ),
                          ]
                        : [
                            _buildNavItem(
                              0,
                              Icons.home_rounded,
                              'Inicio',
                              isPassenger,
                              currentIndex,
                            ),
                            _buildNavItem(
                              1,
                              Icons.account_balance_wallet_rounded,
                              'Ganancias',
                              isPassenger,
                              currentIndex,
                            ),
                            _buildNavItem(
                              2,
                              Icons.history_rounded,
                              'Historial',
                              isPassenger,
                              currentIndex,
                            ),
                            _buildNavItem(
                              3,
                              Icons.person_rounded,
                              'Perfil',
                              isPassenger,
                              currentIndex,
                            ),
                          ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    bool isPassenger,
    int currentIndex,
  ) {
    final isSelected = currentIndex == index;
    final activeColor = isPassenger ? Colors.black : Colors.blue.shade900;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(mainNavIndexProvider.notifier).setIndex(index);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: isSelected ? activeColor : Colors.grey.shade400,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? activeColor : Colors.grey.shade400,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
