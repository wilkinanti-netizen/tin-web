class PricingService {
  // Conversion constant
  static const double _kmToMiles = 0.621371;

  // New Pricing Config
  static const Map<String, Map<String, dynamic>> _pricingConfig = {
    'essentials': {
      'name': 'Essentials',
      'description':
          'Disfruta tu viaje en un vehiculo cómodo y agradable para mejorar tu experiencia.',
      'capacity': 4,
      'base': 2.50,
      'tiers': [
        {'upTo': 5.0, 'rate': 2.25},
        {'upTo': double.infinity, 'rate': 1.95},
      ],
    },
    'essentials_xl': {
      'name': 'Essential XL',
      'description':
          'Mas espacio para ti y tu viaje capacidad hasta 6 personas',
      'capacity': 6,
      'base': 3.10,
      'tiers': [
        {'upTo': 5.0, 'rate': 2.50},
        {'upTo': double.infinity, 'rate': 2.25},
      ],
    },
    'executive': {
      'name': 'Executive',
      'description':
          'una experiencia de lujo y Seguridad, con conductores experimentados',
      'capacity': 4,
      'base': 5.00,
      'tiers': [
        {'upTo': 5.0, 'rate': 4.50},
        {'upTo': 15.0, 'rate': 3.60},
        {'upTo': double.infinity, 'rate': 3.40},
      ],
    },
    'signature_lux': {
      'name': 'Signature',
      'description':
          'Lujo, comfort y seguridad en un mismo espacio, vehiculos gamma Alta y conductores experimentados',
      'capacity': 6,
      'base': 12.00,
      'tiers': [
        {'upTo': 5.0, 'rate': 6.00},
        {'upTo': 15.0, 'rate': 4.40},
        {'upTo': double.infinity, 'rate': 4.20},
      ],
    },
  };

  double calculatePrice(double distanceInKm, String vehicleType) {
    final config = _pricingConfig[vehicleType] ?? _pricingConfig['essentials']!;
    final double baseFare = config['base'];
    final List<Map<String, dynamic>> tiers = config['tiers'];

    final double distanceInMiles = distanceInKm * _kmToMiles;
    double variableFare = 0.0;
    double remainingMiles = distanceInMiles;
    double prevThreshold = 0.0;

    for (final tier in tiers) {
      final double threshold = tier['upTo'];
      final double rate = tier['rate'];

      if (remainingMiles <= 0) break;

      final double milesInThisTier = (threshold == double.infinity)
          ? remainingMiles
          : (threshold - prevThreshold);

      final double actualMilesInTier = remainingMiles < milesInThisTier
          ? remainingMiles
          : milesInThisTier;

      variableFare += actualMilesInTier * rate;
      remainingMiles -= actualMilesInTier;
      prevThreshold = threshold;
    }

    return baseFare + variableFare;
  }

  String formatPrice(double price) {
    return '\$${price.toStringAsFixed(2)}';
  }

  String getVehicleName(String vehicleType) {
    return _pricingConfig[vehicleType]?['name'] ?? vehicleType;
  }

  String getVehicleDescription(String vehicleType) {
    return _pricingConfig[vehicleType]?['description'] ?? '';
  }

  int getVehicleCapacity(String vehicleType) {
    return _pricingConfig[vehicleType]?['capacity'] ?? 4;
  }
}
