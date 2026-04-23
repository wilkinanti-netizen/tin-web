import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tincars/core/widgets/premium_glass_container.dart';
import 'package:tincars/features/profile/domain/models/profiles.dart';
import 'package:tincars/features/profile/presentation/controllers/profile_controller.dart';
import 'package:tincars/features/profile/presentation/screens/add_vehicle_screen.dart';

class MyVehiclesScreen extends ConsumerWidget {
  const MyVehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverProfile = ref.watch(driverProfileProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('MIS VEHÍCULOS'),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F5F7), Colors.white],
          ),
        ),
        child: driverProfile.when(
          data: (profile) {
            if (profile == null)
              return const Center(child: Text('No hay datos'));

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 120, 20, 40),
              children: [
                const Text(
                  'GESTIONA TU FLOTA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 24),
                ...profile.vehicles.map((v) => _buildVehicleCard(context, v)),
                const SizedBox(height: 24),
                _buildAddVehicleButton(context),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildVehicleCard(BuildContext context, Vehicle vehicle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: PremiumGlassContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: BorderRadius.circular(30),
        color: vehicle.isActive ? Colors.black : Colors.white,
        opacity: vehicle.isActive ? 0.9 : 0.8,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (vehicle.isActive ? Colors.white : Colors.black)
                        .withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_car_rounded,
                    color: vehicle.isActive ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.model.toUpperCase(),
                        style: TextStyle(
                          color: vehicle.isActive ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        vehicle.plate,
                        style: TextStyle(
                          color:
                              (vehicle.isActive ? Colors.white : Colors.black)
                                  .withOpacity(0.5),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (vehicle.isVerified)
                  const Icon(Icons.verified, color: Colors.blueAccent, size: 20)
                else
                  const Text(
                    'PENDIENTE',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  vehicle.type.name.toUpperCase(),
                  style: TextStyle(
                    color: (vehicle.isActive ? Colors.white : Colors.black)
                        .withOpacity(0.4),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                if (!vehicle.isActive)
                  TextButton(
                    onPressed: () {
                      // Logic to set active
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text(
                      'ACTIVAR',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  const Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.greenAccent,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'ACTIVO',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddVehicleButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddVehicleScreen()),
        );
      },
      child: PremiumGlassContainer(
        padding: const EdgeInsets.all(24),
        borderRadius: BorderRadius.circular(30),
        color: Colors.white,
        opacity: 0.5,
        border: Border.all(
          color: Colors.black12,
          width: 2,
          style: BorderStyle.none,
        ), // Border style not supported well in my container yet
        child: const Column(
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              color: Colors.black38,
              size: 32,
            ),
            SizedBox(height: 12),
            Text(
              'AÑADIR NUEVO VEHÍCULO',
              style: TextStyle(
                color: Colors.black38,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
