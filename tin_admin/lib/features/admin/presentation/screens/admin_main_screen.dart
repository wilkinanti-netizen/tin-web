import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tin_admin/features/admin/presentation/controllers/admin_controller.dart';
import 'package:tin_admin/features/profile/domain/models/profiles.dart';
import 'package:tin_admin/features/trips/domain/models/trip_model.dart';
import 'package:tin_admin/core/widgets/premium_glass_container.dart';
import 'package:tin_admin/features/admin/presentation/screens/driver_verification_detail_screen.dart';
import 'package:tin_admin/features/admin/presentation/screens/active_driver_profile_screen.dart';
import 'package:tin_admin/features/admin/presentation/screens/passenger_profile_screen.dart';

class AdminMainScreen extends ConsumerStatefulWidget {
  const AdminMainScreen({super.key});

  @override
  ConsumerState<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends ConsumerState<AdminMainScreen> {
  int _selectedIndex = 0;

  final List<String> _menuTitles = [
    'DASHBOARD',
    'PENDIENTES',
    'SOLICITUDES',
    'LÍDERES',
    'CONDUCTORES',
    'PASAJEROS',
  ];

  final List<IconData> _menuIcons = [
    Icons.dashboard,
    Icons.pending_actions,
    Icons.history,
    Icons.groups,
    Icons.drive_eta,
    Icons.person,
  ];

  Widget _getSelectedView() {
    switch (_selectedIndex) {
      case 0:
        return const _DashboardOverviewTab();
      case 1:
        return const _PendingDriversTab();
      case 2:
        return const _PendingTripsTab();
      case 3:
        return const _LeadersTab();
      case 4:
        return const _DriversTab();
      case 5:
        return const _PassengersTab();
      default:
        return const _DashboardOverviewTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC), // Softer, more modern background
      appBar: isDesktop
          ? null
          : AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.black),
              title: Text(
                _menuTitles[_selectedIndex],
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 1.2,
                ),
              ),
            ),
      drawer: isDesktop ? null : _buildDrawer(),
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      _menuTitles[_selectedIndex],
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _getSelectedView(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: _buildSidebarContent(),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: _buildSidebarContent(),
    );
  }

  Widget _buildSidebarContent() {
    return Column(
      children: [
        const SizedBox(height: 40),
        // Logo or Main Title
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield, size: 32, color: Colors.blueAccent),
            const SizedBox(width: 12),
            Text(
              'TinAdmin',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        const Divider(height: 1, color: Colors.black12),
        const SizedBox(height: 16),
        // Menu Items
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _menuTitles.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedIndex == index;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blueAccent.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(
                    _menuIcons[index],
                    color: isSelected ? Colors.blueAccent : Colors.grey[600],
                  ),
                  title: Text(
                    _menuTitles[index],
                    style: GoogleFonts.outfit(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.blueAccent : Colors.grey[800],
                    ),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    setState(() => _selectedIndex = index);
                    if (!MediaQuery.of(context).size.width.isFinite || MediaQuery.of(context).size.width <= 800) {
                      Navigator.pop(context); // Close drawer on mobile
                    }
                  },
                ),
              );
            },
          ),
        ),
        // Footer (User info or logout)
        const Divider(height: 1, color: Colors.black12),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey[200],
                child: const Icon(Icons.admin_panel_settings, color: Colors.blueAccent),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Administrador',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    'admin@tincars.com',
                    style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardOverviewTab extends ConsumerWidget {
  const _DashboardOverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(allProfilesProvider);

    return profilesAsync.when(
      data: (profiles) {
        final pendingCount = profiles.where((p) => p.driverStatus == DriverStatus.pending).length;
        final activeDrivers = profiles.where((p) => p.driverStatus == DriverStatus.active).length;
        final passengersCount = profiles.where((p) => !p.isDriver && p.driverStatus != DriverStatus.pending).length;
        final leadersCount = profiles.where((p) => p.isLeader).length;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allProfilesProvider),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen General',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 24),
                // Stats Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmallScreen = constraints.maxWidth < 600;
                    return GridView.count(
                      crossAxisCount: isSmallScreen ? 1 : 2,
                      childAspectRatio: isSmallScreen ? 2.5 : 2.0,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _DashboardStatCard(
                          title: 'Conductores Pendientes',
                          value: '$pendingCount',
                          icon: Icons.pending_actions,
                          color: Colors.orange,
                          subtitle: 'Requieren revisión urgente',
                        ),
                        _DashboardStatCard(
                          title: 'Conductores Activos',
                          value: '$activeDrivers',
                          icon: Icons.drive_eta,
                          color: Colors.green,
                          subtitle: 'Trabajando actualmente',
                        ),
                        _DashboardStatCard(
                          title: 'Pasajeros Registrados',
                          value: '$passengersCount',
                          icon: Icons.person,
                          color: Colors.blue,
                          subtitle: 'Usuarios en la plataforma',
                        ),
                        _DashboardStatCard(
                          title: 'Líderes de Ciudad',
                          value: '$leadersCount',
                          icon: Icons.groups,
                          color: Colors.purple,
                          subtitle: 'Coordinadores activos',
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 40),
                Text(
                  'Actividad Reciente',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                PremiumGlassContainer(
                  padding: const EdgeInsets.all(24),
                  color: Colors.white,
                  opacity: 1,
                  child: const Center(
                    child: Text(
                      'El historial detallado de viajes estará disponible pronto.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _DashboardStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.1), width: 1.5),
      ),
      padding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          // Background Icon Watermark
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              icon,
              size: 100,
              color: color.withOpacity(0.05),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const Spacer(),
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Removing the old _AdminStatsHeader and _StatItem as they are replaced.

class _PendingTripsTab extends ConsumerWidget {
  const _PendingTripsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(globalRequestedTripsProvider);

    return tripsAsync.when(
      data: (trips) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(globalRequestedTripsProvider),
        child: trips.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: const Center(
                      child: Text('No hay viajes pendientes'),
                    ),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: trips.length,
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  return _TripCard(trip: trip);
                },
              ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    return PremiumGlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      opacity: 1,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildServiceIcon(trip.vehicleType),
              Text(
                trip.vehicleType.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              Text(
                '\$${trip.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _LocationRow(
            icon: Icons.my_location,
            color: Colors.blue,
            label: trip.pickupAddress,
          ),
          const SizedBox(height: 8),
          _LocationRow(
            icon: Icons.location_on,
            color: Colors.red,
            label: trip.dropoffAddress,
          ),
        ],
      ),
    );
  }

  Widget _buildServiceIcon(String type) {
    String assetPath;
    switch (type) {
      case 'essentials':
        assetPath = 'assets/logo/vehiculos/essentials.png';
        break;
      case 'essentialXL':
        assetPath = 'assets/logo/vehiculos/essentialxl.png';
        break;
      case 'executive':
        assetPath = 'assets/logo/vehiculos/executive.png';
        break;
      case 'signature':
        assetPath = 'assets/logo/vehiculos/signatuve.png';
        break;
      default:
        return const Icon(Icons.directions_car, size: 32);
    }
    return Image.asset(assetPath, width: 40);
  }
}

class _DriversTab extends ConsumerWidget {
  const _DriversTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(allProfilesProvider);

    return profilesAsync.when(
      data: (profiles) {
        final drivers = profiles
            .where((p) => p.isDriver || p.driverStatus == DriverStatus.pending)
            .toList();
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allProfilesProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              return _UserCard(user: driver, isDriver: true);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _PassengersTab extends ConsumerWidget {
  const _PassengersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(allProfilesProvider);

    return profilesAsync.when(
      data: (profiles) {
        final passengers = profiles
            .where((p) => !p.isDriver && p.driverStatus != DriverStatus.pending)
            .toList();
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allProfilesProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: passengers.length,
            itemBuilder: (context, index) {
              final passenger = passengers[index];
              return _UserCard(user: passenger, isDriver: false);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _PendingDriversTab extends ConsumerWidget {
  const _PendingDriversTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(allProfilesProvider);

    return profilesAsync.when(
      data: (profiles) {
        final pendingDrivers = profiles
            .where((p) => p.driverStatus == DriverStatus.pending)
            .toList();
        
        if (pendingDrivers.isEmpty) {
          return const Center(child: Text('No hay conductores pendientes de aprobación'));
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allProfilesProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: pendingDrivers.length,
            itemBuilder: (context, index) {
              final driver = pendingDrivers[index];
              return _UserCard(user: driver, isDriver: true);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _UserCard extends ConsumerWidget {
  final AppUser user;
  final bool isDriver;
  const _UserCard({required this.user, required this.isDriver});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PremiumGlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      opacity: 1,
      child: InkWell(
        onTap: () {
          if (isDriver) {
            if (user.driverStatus == DriverStatus.pending) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DriverVerificationDetailScreen(
                    userId: user.id,
                    userName: user.fullName,
                  ),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ActiveDriverProfileScreen(driver: user),
                ),
              );
            }
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PassengerProfileScreen(passenger: user),
              ),
            );
          }
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[100],
              backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              child: user.avatarUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    user.email,
                    style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 13),
                  ),
                  if (user.city != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 12, color: Colors.redAccent),
                          const SizedBox(width: 4),
                          Text(
                            user.city!,
                            style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (isDriver) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status: user.driverStatus ?? DriverStatus.pending),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (user.driverStatus == DriverStatus.pending)
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.blue),
                      PopupMenuButton<DriverStatus>(
                        icon: const Icon(Icons.more_horiz),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 150),
                        onSelected: (status) async {
                          await ref
                              .read(adminControllerProvider.notifier)
                              .updateDriverStatus(user.id, status);
                          ref.invalidate(allProfilesProvider);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: DriverStatus.active,
                            child: ListTile(
                              leading: Icon(Icons.check_circle, color: Colors.green),
                              title: Text('Aprobar'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: DriverStatus.rejected,
                            child: ListTile(
                              leading: Icon(Icons.cancel, color: Colors.red),
                              title: Text('Rechazar'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: DriverStatus.inactive,
                            child: ListTile(
                              leading: Icon(Icons.block, color: Colors.grey),
                              title: Text('Desactivar'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ] else 
              const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final DriverStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case DriverStatus.active:
        color = Colors.green;
        label = 'ACTIVO';
        break;
      case DriverStatus.pending:
        color = Colors.orange;
        label = 'PENDIENTE';
        break;
      case DriverStatus.rejected:
        color = Colors.red;
        label = 'RECHAZADO';
        break;
      case DriverStatus.inactive:
        color = Colors.grey;
        label = 'INACTIVO';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _LocationRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
class _LeadersTab extends ConsumerWidget {
  const _LeadersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(allProfilesProvider);

    return profilesAsync.when(
      data: (profiles) {
        final citiesWithLeaders = <String, List<AppUser>>{};
        final pendingDriversByCity = <String, int>{};

        for (final profile in profiles) {
          if (profile.isLeader && profile.city != null) {
            citiesWithLeaders.putIfAbsent(profile.city!, () => []).add(profile);
          }
          if (profile.driverStatus == DriverStatus.pending &&
              profile.city != null) {
            pendingDriversByCity[profile.city!] =
                (pendingDriversByCity[profile.city!] ?? 0) + 1;
          }
        }

        final sortedCities = citiesWithLeaders.keys.toList()..sort();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allProfilesProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: sortedCities.length,
            itemBuilder: (context, index) {
              final city = sortedCities[index];
              final leaders = citiesWithLeaders[city]!;
              final pendingCount = pendingDriversByCity[city] ?? 0;

              return PremiumGlassContainer(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                opacity: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          city.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$pendingCount PENDIENTES',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Líderes activos:',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children:
                          leaders.map((leader) {
                            return Chip(
                              avatar: const CircleAvatar(
                                backgroundColor: Colors.blue,
                                child: Icon(
                                  Icons.person,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                              label: Text(
                                leader.fullName,
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: Colors.blue.withOpacity(0.05),
                              side: BorderSide.none,
                            );
                          }).toList(),
                    ),
                    const Divider(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: Implement navigation to city-filtered drivers screen
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Filtrando por $city')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('GESTIONAR PENDIENTES'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

