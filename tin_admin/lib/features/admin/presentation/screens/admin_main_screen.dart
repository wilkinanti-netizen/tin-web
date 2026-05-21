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
import 'package:tin_admin/features/admin/presentation/screens/admin_settings_tab.dart';
import 'package:tin_admin/features/admin/presentation/screens/admin_notifications_tab.dart';
import 'package:tin_admin/features/admin/presentation/screens/admin_support_tab.dart';
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
    'CONDUCTORES',
    'PASAJEROS',
    'HISTORIAL',
    'AJUSTES',
    'NOTIFICACIONES',
    'SOPORTE',
  ];

  final List<IconData> _menuIcons = [
    Icons.dashboard,
    Icons.pending_actions,
    Icons.history,
    Icons.drive_eta,
    Icons.person,
    Icons.assignment_turned_in,
    Icons.settings,
    Icons.send_rounded,
    Icons.support_agent_rounded,
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
        return const _DriversTab();
      case 4:
        return const _PassengersTab();
      case 5:
        return const _TripHistoryTab();
      case 6:
        return const AdminSettingsTab();
      case 7:
        return const AdminNotificationsTab();
      case 8:
        return const AdminSupportTab();
      default:
        return const _DashboardOverviewTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5), // Executive Slate Grey
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
      body: Container(
        decoration: const BoxDecoration(color: Color(0xFFF0F2F5)),
        child: Row(
          children: [
            if (isDesktop) _buildSidebar(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isDesktop)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 20,
                      ),
                      color: Colors.white,
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _menuTitles[_selectedIndex],
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A1C1E),
                                ),
                              ),
                              Text(
                                'Bienvenido de nuevo al centro de control',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Executive Search Bar
                          Container(
                            width: 300,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F2F5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Buscar...',
                                hintStyle: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: Colors.grey[400],
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          _buildTopBarAction(Icons.notifications_none_rounded),
                          const SizedBox(width: 12),
                          _buildTopBarAction(Icons.help_outline_rounded),
                        ],
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
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(backgroundColor: Colors.white, child: _buildSidebarContent());
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1C1E), // Deep Executive Charcoal
      ),
      child: _buildSidebarContent(),
    );
  }

  Widget _buildSidebarContent() {
    return Column(
      children: [
        const SizedBox(height: 50),
        // Logo or Main Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  size: 28,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'TIN ADMIN',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Navegación Principal',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white24,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Menu Items
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _menuTitles.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedIndex == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blueAccent.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(
                    _menuIcons[index],
                    size: 20,
                    color: isSelected ? Colors.blueAccent : Colors.white38,
                  ),
                  title: Text(
                    _menuTitles[index],
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    setState(() => _selectedIndex = index);
                    if (MediaQuery.of(context).size.width <= 800) {
                      Navigator.pop(context);
                    }
                  },
                ),
              );
            },
          ),
        ),
        // Footer (User info or logout)
        Container(
          padding: const EdgeInsets.all(24.0),
          decoration: const BoxDecoration(color: Color(0xFF121416)),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white10, width: 2),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.blueAccent.withOpacity(0.2),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.blueAccent,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Socio Admin',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'admin@tincars.com',
                      style: GoogleFonts.outfit(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBarAction(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF0F2F5)),
      ),
      child: Icon(icon, size: 20, color: const Color(0xFF1A1C1E)),
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
        final pendingCount = profiles
            .where((p) => p.driverStatus == DriverStatus.pending)
            .length;
        final activeDrivers = profiles
            .where((p) => p.driverStatus == DriverStatus.active)
            .length;
        final passengersCount = profiles
            .where((p) => !p.isDriver && p.driverStatus != DriverStatus.pending)
            .length;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allProfilesProvider),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DashboardSectionTitle('Rendimiento Semanal'),
                          const SizedBox(height: 16),
                          const _ExecutiveMainChart(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _DashboardSectionTitle('Distribución de Flota'),
                          const SizedBox(height: 16),
                          const _FleetDistributionCard(),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _DashboardSectionTitle('Indicadores Clave'),
                const SizedBox(height: 24),
                // Stats Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmallScreen = constraints.maxWidth < 600;
                    return GridView.count(
                      crossAxisCount: isSmallScreen ? 2 : 4,
                      childAspectRatio: isSmallScreen ? 1.2 : 1.4,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _DashboardStatCard(
                          title: 'Conductores',
                          value: '$pendingCount',
                          icon: Icons.pending_actions,
                          color: Colors.orange,
                          trend: '+5.2%',
                        ),
                        _DashboardStatCard(
                          title: 'Activos',
                          value: '$activeDrivers',
                          icon: Icons.drive_eta,
                          color: Colors.green,
                          trend: '+2.1%',
                        ),
                        _DashboardStatCard(
                          title: 'Pasajeros',
                          value: '$passengersCount',
                          icon: Icons.person,
                          color: Colors.blue,
                          trend: '+12%',
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
                  padding: const EdgeInsets.all(0),
                  color: Colors.white,
                  opacity: 1,
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      _buildActivityItem(
                        'Registro de conductor',
                        'Nuevo conductor de Bucaramanga',
                        'Hace 2 min',
                        Colors.blue,
                      ),
                      _buildActivityItem(
                        'Viaje completado',
                        'ID: #8321 - \$12,500',
                        'Hace 15 min',
                        Colors.green,
                      ),
                      _buildActivityItem(
                        'Solicitud pendiente',
                        'Revisión de documentos',
                        'Hace 1 hora',
                        Colors.orange,
                      ),
                    ],
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

  Widget _DashboardSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1A1C1E).withOpacity(0.7),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String desc,
    String time,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              color: color,
              size: 14,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: const Color(0xFF1A1C1E),
                  ),
                ),
                Text(
                  desc,
                  style: GoogleFonts.outfit(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: GoogleFonts.outfit(
              color: Colors.grey[400],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutiveMainChart extends StatelessWidget {
  const _ExecutiveMainChart();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'HISTÓRICO DE INGRESOS (MILLONES)',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
              const Icon(
                Icons.show_chart_rounded,
                color: Colors.blueAccent,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$142.5M',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1C1E),
            ),
          ),
          const Spacer(),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _LineChartPainter(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM']
                .map(
                  (d) => Text(
                    d,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _FleetDistributionCard extends StatelessWidget {
  const _FleetDistributionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'USO DE VEHÍCULOS',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white24,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          _buildFleetProgress('ESSENTIALS', 0.65, Colors.blue),
          _buildFleetProgress('EXECUTIVE', 0.25, Colors.amber),
          _buildFleetProgress('SIGNATURE', 0.10, Colors.purpleAccent),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildFleetProgress(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(value * 100).toInt()}%',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.blueAccent.withOpacity(0.2),
          Colors.blueAccent.withOpacity(0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    final dataPoints = [0.2, 0.4, 0.35, 0.7, 0.55, 0.85, 0.6];
    final stepX = size.width / (dataPoints.length - 1);

    path.moveTo(0, size.height * (1 - dataPoints[0]));
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, size.height * (1 - dataPoints[0]));

    for (var i = 1; i < dataPoints.length; i++) {
      final x = i * stepX;
      final y = size.height * (1 - dataPoints[i]);

      // Control points for smooth curves
      final prevX = (i - 1) * stepX;
      final prevY = size.height * (1 - dataPoints[i - 1]);

      path.cubicTo(prevX + stepX / 2, prevY, x - stepX / 2, y, x, y);
      fillPath.cubicTo(prevX + stepX / 2, prevY, x - stepX / 2, y, x, y);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String trend;

  const _DashboardStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.03), width: 1),
      ),
      padding: const EdgeInsets.all(12), // Reduced padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween, // Use alignment instead of Spacer
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: trend.contains('+')
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    trend,
                    style: GoogleFonts.outfit(
                      color: trend.contains('+') ? Colors.green : Colors.grey,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 24, // Slightly smaller
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1C1E),
                    ),
                  ),
                ),
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 8, // Slightly smaller
                    fontWeight: FontWeight.w800,
                    color: Colors.black26,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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

class _TripCard extends ConsumerWidget {
  final Trip trip;
  final bool showStatus;
  const _TripCard({required this.trip, this.showStatus = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              Row(
                children: [
                  _buildServiceIcon(trip.vehicleType),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.vehicleType.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                      if (showStatus)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: trip.status == TripStatus.completed
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            trip.status.name.toUpperCase(),
                            style: TextStyle(
                              color: trip.status == TripStatus.completed
                                  ? Colors.green
                                  : Colors.red,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '\$${trip.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!showStatus) // Only show in PendingTripsTab
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Eliminar viaje'),
                            content: const Text(
                              '¿Estás seguro de que quieres eliminar esta solicitud de viaje?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'Eliminar',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref
                              .read(adminControllerProvider.notifier)
                              .deleteTrip(trip.id);
                        }
                      },
                    ),
                ],
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
          if (trip.driverId != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person, size: 14, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Driver ID: ${trip.driverId}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
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
      case 'essentials_xl':
        assetPath = 'assets/logo/vehiculos/essentialxl.png';
        break;
      case 'executive':
        assetPath = 'assets/logo/vehiculos/executive.png';
        break;
      case 'signature_lux':
        assetPath = 'assets/logo/vehiculos/signatuve.png';
        break;

      default:
        return const Icon(Icons.directions_car, size: 32);
    }
    return Image.asset(assetPath, width: 32);
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
            .where(
              (p) =>
                  p.isDriver ||
                  p.driverStatus == DriverStatus.pending ||
                  p.driverStatus == DriverStatus.rejected,
            )
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

class _PendingDriversTab extends ConsumerStatefulWidget {
  const _PendingDriversTab();

  @override
  ConsumerState<_PendingDriversTab> createState() => _PendingDriversTabState();
}

class _PendingDriversTabState extends ConsumerState<_PendingDriversTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(allProfilesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Buscar conductor...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.black.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: profilesAsync.when(
            data: (profiles) {
              final allPending = profiles.where(
                (p) => p.driverStatus == DriverStatus.pending,
              );
              final allRejected = profiles.where(
                (p) => p.driverStatus == DriverStatus.rejected,
              );

              final pendingDrivers = allPending
                  .where(
                    (p) =>
                        p.fullName.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ) ||
                        p.email.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ),
                  )
                  .toList();
              final rejectedDrivers = allRejected
                  .where(
                    (p) =>
                        p.fullName.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ) ||
                        p.email.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ),
                  )
                  .toList();

              final newDrivers = pendingDrivers
                  .where((p) => !p.hasBeenRejected)
                  .toList();
              final resubmittedDrivers = pendingDrivers
                  .where((p) => p.hasBeenRejected)
                  .toList();

              if (newDrivers.isEmpty &&
                  resubmittedDrivers.isEmpty &&
                  rejectedDrivers.isEmpty) {
                return const Center(
                  child: Text('No hay conductores pendientes de aprobación'),
                );
              }

              final List<Widget> items = [];

              if (newDrivers.isNotEmpty) {
                items.add(
                  _SectionHeader(
                    label: 'NUEVOS EN REVISIÓN',
                    count: newDrivers.length,
                    color: Colors.blueAccent,
                    icon: Icons.new_releases_outlined,
                  ),
                );
                for (final driver in newDrivers) {
                  items.add(_UserCard(user: driver, isDriver: true));
                }
              }

              if (resubmittedDrivers.isNotEmpty) {
                items.add(
                  _SectionHeader(
                    label: 'REENVIADOS',
                    count: resubmittedDrivers.length,
                    color: Colors.orange,
                    icon: Icons.replay_circle_filled_rounded,
                  ),
                );
                for (final driver in resubmittedDrivers) {
                  items.add(_UserCard(user: driver, isDriver: true));
                }
              }

              if (rejectedDrivers.isNotEmpty) {
                items.add(
                  _SectionHeader(
                    label: 'RECHAZADOS',
                    count: rejectedDrivers.length,
                    color: Colors.red,
                    icon: Icons.cancel_outlined,
                  ),
                );
                for (final driver in rejectedDrivers) {
                  items.add(_UserCard(user: driver, isDriver: true));
                }
              }

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(allProfilesProvider),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: items,
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  final AppUser user;
  final bool isDriver;
  const _UserCard({required this.user, required this.isDriver});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.04), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (isDriver) {
            if (user.driverStatus == DriverStatus.pending ||
                user.driverStatus == DriverStatus.rejected) {
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user.fullName,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: const Color(0xFF1A1C1E),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isDriver)
                          _buildStatusBadge(
                            user.driverStatus ?? DriverStatus.pending,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: GoogleFonts.outfit(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                    if (user.city != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user.city!,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Acciones movidas al interior del detalle de conductor
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.black12,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.blueAccent.withOpacity(0.05),
          width: 3,
        ),
      ),
      child: CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFFF0F2F5),
        backgroundImage: user.avatarUrl != null
            ? NetworkImage(user.avatarUrl!)
            : null,
        child: user.avatarUrl == null
            ? const Icon(Icons.person_rounded, color: Colors.blueGrey, size: 24)
            : null,
      ),
    );
  }

  Widget _buildStatusBadge(DriverStatus status) {
    Color color;
    String text;
    switch (status) {
      case DriverStatus.active:
        color = Colors.green;
        text = 'ACTIVO';
        break;
      case DriverStatus.pending:
        color = Colors.orange;
        text = 'PENDIENTE';
        break;
      case DriverStatus.rejected:
        color = Colors.red;
        text = 'RECHAZADO';
        break;
      case DriverStatus.inactive:
        color = Colors.grey;
        text = 'INACTIVO';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildActionButtons(WidgetRef ref, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.green,
            size: 22,
          ),
          onPressed: () async {
            await ref
                .read(adminControllerProvider.notifier)
                .updateDriverStatus(user.id, DriverStatus.active);
            ref.invalidate(allProfilesProvider);
          },
        ),
        IconButton(
          icon: const Icon(
            Icons.highlight_off_rounded,
            color: Colors.red,
            size: 22,
          ),
          onPressed: () async {
            await ref
                .read(adminControllerProvider.notifier)
                .updateDriverStatus(user.id, DriverStatus.rejected);
            ref.invalidate(allProfilesProvider);
          },
        ),
      ],
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

class _TripHistoryTab extends ConsumerWidget {
  const _TripHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(globalTripHistoryProvider);

    return historyAsync.when(
      data: (trips) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(globalTripHistoryProvider),
        child: trips.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: const Center(
                      child: Text('No hay viajes en el historial'),
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
                  return _TripCard(trip: trip, showStatus: true);
                },
              ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
