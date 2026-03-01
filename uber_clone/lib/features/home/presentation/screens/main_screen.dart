import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tincars/core/services/session_service.dart';
import 'package:go_router/go_router.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/features/profile/presentation/screens/profile_screen.dart';
import 'package:tincars/features/trips/presentation/screens/activity_screen.dart';
import 'package:tincars/features/home/presentation/screens/home_screen.dart';
import 'package:tincars/features/home/presentation/providers/user_mode_provider.dart';
import 'package:tincars/features/home/presentation/screens/driver_home_screen.dart';
import 'package:tincars/features/profile/presentation/screens/earnings_screen.dart';
import 'package:tincars/features/trips/presentation/screens/trips_screen.dart';

import 'package:tincars/core/widgets/mode_switch_overlay.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;
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
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Listen to profile changes in realtime
    _profileSubscription = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', user.id)
        .listen((data) {
          if (data.isNotEmpty) {
            final remoteDeviceId = data.first['device_id'] as String?;
            if (remoteDeviceId != null && remoteDeviceId != _currentDeviceId) {
              _handleExternalLogout();
            }
          }
        });
  }

  void _handleExternalLogout() async {
    await Supabase.instance.client.auth.signOut();
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

    final currentMode = ref.watch(userModeProvider);
    final isPassenger = currentMode == UserMode.passenger;
    final isTransitioning = ref.watch(isModeTransitioningProvider);

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
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: screens),

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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: isPassenger ? Colors.black : Colors.blue.shade900,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: isPassenger
            ? const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.directions_car),
                  label: 'Viajar',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long),
                  label: 'Actividad',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Perfil',
                ),
              ]
            : const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Inicio',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_balance_wallet),
                  label: 'Ganancias',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: 'Historial',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Perfil',
                ),
              ],
      ),
    );
  }
}
