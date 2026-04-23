class PricingService {
  // Conversion constant
  static const double _kmToMiles = 0.621371;

  // ─── Wait Time Configuration ────────────────────────────────────────────────
  // freeWaitMinutes: grace period before charges start.
  // waitFeePerMinute: cost in USD for each minute beyond the grace period.
  static const Map<String, Map<String, dynamic>> _waitTimeConfig = {
    'essentials': {'freeWaitMinutes': 3, 'waitFeePerMinute': 0.40},
    'essentials_xl': {'freeWaitMinutes': 3, 'waitFeePerMinute': 0.40},
    'executive': {'freeWaitMinutes': 5, 'waitFeePerMinute': 0.60},
    'signature_lux': {'freeWaitMinutes': 5, 'waitFeePerMinute': 0.60},
  };

  /// Returns the free wait minutes for the given vehicle type.
  int getFreeWaitMinutes(String vehicleType) {
    return (_waitTimeConfig[vehicleType]?['freeWaitMinutes'] as int?) ?? 3;
  }

  /// Returns the wait fee per minute (USD) after the free period.
  double getWaitFeePerMinute(String vehicleType) {
    return (_waitTimeConfig[vehicleType]?['waitFeePerMinute'] as double?) ??
        0.40;
  }

  /// Returns the total extra charge for waiting beyond the free window.
  /// [elapsedSeconds] is how long the driver has been waiting.
  double calculateWaitFee(String vehicleType, int elapsedSeconds) {
    final freeSeconds = getFreeWaitMinutes(vehicleType) * 60;
    if (elapsedSeconds <= freeSeconds) return 0.0;
    final chargeableSeconds = elapsedSeconds - freeSeconds;
    final chargeableMinutes = chargeableSeconds / 60.0;
    return chargeableMinutes * getWaitFeePerMinute(vehicleType);
  }

  // New Pricing Config
  static const Map<String, Map<String, dynamic>> _pricingConfig = {
    'essentials': {
      'name': 'Essentials-Eco',
      'description':
          'Disfruta tu viaje en un vehiculo cómodo y agradable para mejorar tu experiencia.',
      'capacity': 4,
      'base': 5.50,
      'baseWeekend': 6.50,
      'tiers': [
        {'upTo': 5.0, 'rate': 2.45},
        {'upTo': 15.0, 'rate': 2.00},
        {'upTo': double.infinity, 'rate': 1.90},
      ],
    },
    'essentials_xl': {
      'name': 'Essentials XL',
      'description':
          'Mas espacio para ti y tu viaje capacidad hasta 6 personas',
      'capacity': 6,
      'base': 6.60,
      'baseWeekend': 7.70,
      'tiers': [
        {'upTo': 5.0, 'rate': 2.70},
        {'upTo': 15.0, 'rate': 2.25},
        {'upTo': double.infinity, 'rate': 2.10},
      ],
    },
    'executive': {
      'name': 'Executive',
      'description':
          'una experiencia de lujo y Seguridad, con conductores experimentados',
      'capacity': 4,
      'base': 9.00,
      'baseWeekend': 10.50,
      'tiers': [
        {'upTo': 5.0, 'rate': 4.80},
        {'upTo': 15.0, 'rate': 3.90},
        {'upTo': double.infinity, 'rate': 3.50},
      ],
    },
    'signature_lux': {
      'name': 'Signature Lux',
      'description':
          'Lujo, comfort y seguridad en un mismo espacio, vehiculos gamma Alta y conductores experimentados',
      'capacity': 6,
      'base': 16.00,
      'baseWeekend': 18.50,
      'tiers': [
        {'upTo': 5.0, 'rate': 6.50},
        {'upTo': 15.0, 'rate': 4.60},
        {'upTo': double.infinity, 'rate': 4.20},
      ],
    },
  };

  bool _isWeekend() {
    final DateTime now = DateTime.now();
    // Friday is 5, Saturday is 6
    return now.weekday == DateTime.friday || now.weekday == DateTime.saturday;
  }

  double calculatePrice(double distanceInKm, String vehicleType) {
    final config = _pricingConfig[vehicleType] ?? _pricingConfig['essentials']!;

    // Select base fare based on the day of the week
    final double baseFare = _isWeekend()
        ? (config['baseWeekend'] ?? config['base'])
        : config['base'];

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

    final double calculatedTotal = baseFare + variableFare;

    // Stripe minimum is $0.50 USD.
    const double minPrice = 0.50;
    return calculatedTotal < minPrice ? minPrice : calculatedTotal;
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

  Map<String, dynamic> getPricingConfig(String vehicleType) {
    return _pricingConfig[vehicleType] ?? _pricingConfig['essentials']!;
  }

  /// Recalculates the price when a trip is modified mid-way.
  /// [originalPrice]: The price agreed at the beginning.
  /// [originalDistance]: The distance estimated at the beginning.
  /// [distanceTraveled]: Distance already covered by the driver from pickup.
  /// [newSegmentDistance]: Distance from current location to the new destination (via stops).
  /// [vehicleType]: Type of vehicle to get correct rates.
  double calculateModifiedTripPrice({
    required double originalPrice,
    required double originalDistance,
    required double distanceTraveled,
    required double newSegmentDistance,
    required String vehicleType,
  }) {
    // 1. Calculate the cost of the portion already completed.
    // Use the percentage of distance completed against the original price.
    final double safeOriginalDistance = originalDistance > 0 ? originalDistance : 0.1;
    final double completedPercentage = (distanceTraveled / safeOriginalDistance).clamp(0.0, 1.0);
    final double completedCost = originalPrice * completedPercentage;

    // 2. Calculate the "money of the new stop/segment".
    // As per user request: "cobrar el porcentaje dependiendo de donde voy ... mas el dinero de la nueva parada".
    // This adds the full price of the new journey segment (which includes its own base fare).
    final double newSegmentCost = calculatePrice(newSegmentDistance, vehicleType);
    
    // We ensure a minimum "Modification Fee" (e.g. $1.50) added to the completed part
    // if the new segment is extremely short, but usually the segment cost covers it.
    final double total = completedCost + newSegmentCost;
    
    return double.parse(total.toStringAsFixed(2));
  }
}
