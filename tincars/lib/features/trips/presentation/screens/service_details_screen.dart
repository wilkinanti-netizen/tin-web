import 'package:flutter/material.dart';
import 'package:tincars/features/trips/domain/services/pricing_service.dart';

class ServiceDetailsScreen extends StatelessWidget {
  final String vehicleType;
  final PricingService _pricingService = PricingService();

  ServiceDetailsScreen({super.key, required this.vehicleType});

  @override
  Widget build(BuildContext context) {
    final name = _pricingService.getVehicleName(vehicleType);
    final description = _pricingService.getVehicleDescription(vehicleType);
    final capacity = _pricingService.getVehicleCapacity(vehicleType);

    String assetPath = '';
    switch (vehicleType) {
      case 'essentials':
        assetPath = 'assets/vehiculos/essentials.png';
        break;
      case 'essentials_xl':
        assetPath = 'assets/vehiculos/essentialxl.png';
        break;
      case 'executive':
        assetPath = 'assets/vehiculos/executive.png';
        break;
      case 'signature_lux':
        assetPath = 'assets/vehiculos/signatuve.png';
        break;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(name, style: const TextStyle(color: Colors.black)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Image.asset(
                assetPath,
                height: 150,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.directions_car,
                  size: 100,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              name,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Capacidad: $capacity personas",
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              "Descripción",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),
            _buildFeatureRow(
              Icons.security,
              "Seguridad Priorizada",
              "Conductores verificados y seguimiento en tiempo real.",
            ),
            const SizedBox(height: 20),
            _buildFeatureRow(
              Icons.timer,
              "Rapidez",
              "Conexión con el conductor más cercano a tu ubicación.",
            ),
            const SizedBox(height: 20),
            _buildFeatureRow(
              Icons.payment,
              "Pago Flexible",
              "Aceptamos efectivo y otros métodos locales.",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.black, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
