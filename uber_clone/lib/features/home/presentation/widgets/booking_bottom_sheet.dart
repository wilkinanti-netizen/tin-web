import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BookingBottomSheet extends ConsumerStatefulWidget {
  const BookingBottomSheet({super.key});

  @override
  ConsumerState<BookingBottomSheet> createState() => _BookingBottomSheetState();
}

class _BookingBottomSheetState extends ConsumerState<BookingBottomSheet> {
  final TextEditingController _pickupController = TextEditingController(
    text: 'Ubicación Actual',
  );
  final TextEditingController _dropoffController = TextEditingController();

  // Mock states
  bool _isRequesting = false;
  bool _isAssigned = false;

  // We'll store cancelled trips in the local state for demonstration
  final List<Map<String, String>> _cancelledTrips = [];

  void _handleRequestOrCancel() {
    if (_dropoffController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa tu destino primero.')),
      );
      return;
    }

    if (!_isRequesting && !_isAssigned) {
      // Start requesting
      setState(() {
        _isRequesting = true;
      });

      // Simulate assigning a driver after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isRequesting) {
          setState(() {
            _isRequesting = false;
            _isAssigned = true;
          });
        }
      });
    } else {
      // Cancel trip
      setState(() {
        _cancelledTrips.insert(0, {
          'pickup': _pickupController.text,
          'dropoff': _dropoffController.text,
          'time': TimeOfDay.now().format(context),
        });
        _isRequesting = false;
        _isAssigned = false;
        _dropoffController.clear();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Viaje cancelado')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ListView(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Planifica tu viaje',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Location Inputs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Timeline Graphics
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(width: 2, height: 40, color: Colors.grey[200]),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Dónde estoy',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _dropoffController,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'A dónde vas',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Request / Cancel Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(
              onPressed: _handleRequestOrCancel,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRequesting
                    ? Colors.orange
                    : _isAssigned
                    ? Colors.redAccent
                    : Colors.black, // Dark sleek look
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                minimumSize: const Size(double.infinity, 54),
              ),
              child: Text(
                _isRequesting
                    ? 'Buscando conductor...'
                    : _isAssigned
                    ? 'Cancelar Viaje'
                    : 'Solicitar Viaje',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Recent / Suggestions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Viajes recientes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),

          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.flight_takeoff_rounded,
                color: Colors.black87,
                size: 22,
              ),
            ),
            title: const Text(
              'Aeropuerto Internacional',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Destino frecuente',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            onTap: () {
              _dropoffController.text = 'Aeropuerto Internacional';
            },
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.domain_rounded,
                color: Colors.black87,
                size: 22,
              ),
            ),
            title: const Text(
              'Hotel Centro',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Lugar guardado',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            onTap: () {
              _dropoffController.text = 'Hotel Centro';
            },
          ),

          // Cancelled History Section
          if (_cancelledTrips.isNotEmpty) ...[
            const Divider(height: 30, thickness: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.history, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Historial Cancelados',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _cancelledTrips.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ..._cancelledTrips.map(
              (trip) => ListTile(
                dense: true,
                title: Text('${trip['pickup']} ➔ ${trip['dropoff']}'),
                subtitle: Text(
                  'Cancelado a las ${trip['time']}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
