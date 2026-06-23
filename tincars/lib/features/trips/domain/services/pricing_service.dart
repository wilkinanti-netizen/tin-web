import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tincars/features/trips/domain/models/pricing_config.dart';

final pricingConfigProvider = StreamProvider<PricingConfig>((ref) {
  return FirebaseFirestore.instance
      .collection('admin_settings')
      .doc('pricing')
      .snapshots()
      .map((doc) => PricingConfig.fromFirestore(doc));
});

final pricingServiceProvider = Provider<PricingService>((ref) {
  final configAsync = ref.watch(pricingConfigProvider);
  return PricingService(configAsync.value);
});

class PricingService {
  final PricingConfig? _config;

  PricingService(this._config);

  // Conversion constant
  static const double _kmToMiles = 0.621371;

  PricingConfig? get config => _config;

  /// Returns the free wait minutes for the given vehicle type.
  /// Signature Lux gets 5 minutes of courtesy; all others get 3 minutes.
  int getFreeWaitMinutes(String vehicleType) {
    final normalized = _normalizeVehicleType(vehicleType);
    if (normalized == 'signature_lux') return 5;
    return 3;
  }

  /// Returns the wait fee per minute (USD) after the free period.
  double getWaitFeePerMinute(String vehicleType) {
    return 1.0; // User requested 1 dollar per minute
  }

  /// Returns the total extra charge for waiting beyond the free window.
  /// Essentials/Executive/XL: 3 minutes of courtesy, then $1.00 USD per minute.
  /// Signature Lux: 5 minutes of courtesy, then $1.00 USD per minute.
  double calculateWaitFee(String vehicleType, int elapsedSeconds) {
    final int freeMinutes = getFreeWaitMinutes(vehicleType);
    const double feePerMinute = 1.0;

    final freeSeconds = freeMinutes * 60;
    if (elapsedSeconds <= freeSeconds) return 0.0;

    final chargeableSeconds = elapsedSeconds - freeSeconds;
    final chargeableMinutes = chargeableSeconds / 60.0;
    return chargeableMinutes * feePerMinute;
  }

  /// Returns the cancellation fee when the driver has already arrived.
  /// Essentials / Essentials XL → $5.00
  /// Executive / Signature Lux → $7.00
  double getCancellationFee(String vehicleType) {
    final normalized = _normalizeVehicleType(vehicleType);
    if (normalized == 'executive' || normalized == 'signature_lux') return 7.0;
    return 5.0;
  }
  bool _isWeekend() {
    final DateTime now = DateTime.now();
    // Friday is 5, Saturday is 6, Sunday is 7
    return now.weekday == DateTime.friday ||
        now.weekday == DateTime.saturday ||
        now.weekday == DateTime.sunday;
  }

  String _normalizeVehicleType(String type) {
    final clean = type.toLowerCase().trim();
    if (clean.contains('executive') || clean.contains('exrequi')) {
      return 'executive';
    } else if (clean.contains('signature') || clean.contains('lux')) {
      return 'signature_lux';
    } else if (clean.contains('xl')) {
      return 'essentials_xl';
    } else if (clean.contains('essential')) {
      return 'essentials';
    } else if (clean.contains('ex')) {
      return 'executive';
    }
    return type;
  }

  double calculatePrice(double distanceInKm, String vehicleType) {
    final normalized = _normalizeVehicleType(vehicleType);
    final vehicleConfig = _config?.vehicles[normalized] ?? 
                         _config?.vehicles['essentials'];

    if (vehicleConfig == null) {
      // Fallback to minimal logic if no config yet
      return 5.0; 
    }

    // Select base fare based on the day of the week
    final double baseFare = _isWeekend()
        ? vehicleConfig.baseWeekend
        : vehicleConfig.base;

    final List<PricingTier> tiers = vehicleConfig.distanceTiers;


    final double distanceInMiles = distanceInKm * _kmToMiles;
    double variableFare = 0.0;

    final double rate0to5 = tiers.isNotEmpty ? tiers[0].pricePerKm : 0.0;
    final double rate5to15 = tiers.length > 1 ? tiers[1].pricePerKm : 0.0;
    final double rate15plus = tiers.length > 2 ? tiers[2].pricePerKm : 0.0;

    if (distanceInMiles <= 5) {
      variableFare = distanceInMiles * rate0to5;
    } else if (distanceInMiles <= 15) {
      // First 5 miles at tier 1, rest at tier 2
      variableFare = (5 * rate0to5) + ((distanceInMiles - 5) * rate5to15);
    } else {
      // First 5 at tier 1, next 10 at tier 2, rest at tier 3
      variableFare =
          (5 * rate0to5) +
          (10 * rate5to15) +
          ((distanceInMiles - 15) * rate15plus);
    }

    final double calculatedTotal = baseFare + variableFare;

    // Minimum trip price
    const double minPrice = 5.00;
    return calculatedTotal < minPrice ? minPrice : calculatedTotal;
  }

  String formatPrice(double price) {
    return '\$${price.toStringAsFixed(2)}';
  }

  String getVehicleName(String vehicleType) {
    final normalized = _normalizeVehicleType(vehicleType);
    final configName = _config?.vehicles[normalized]?.name;
    if (configName != null) return configName;
    
    // Capitalize and format the normalized key as a premium fallback name
    if (normalized == 'signature_lux') return 'Signature Lux';
    if (normalized == 'essentials_xl') return 'Essentials XL';
    if (normalized == 'executive') return 'Executive';
    if (normalized == 'essentials') return 'Essentials';
    return normalized.replaceAll('_', ' ');
  }

  String getVehicleDescription(String vehicleType) {
    final normalized = _normalizeVehicleType(vehicleType);
    return _config?.vehicles[normalized]?.description ?? '';
  }

  int getVehicleCapacity(String vehicleType) {
    final normalized = _normalizeVehicleType(vehicleType);
    return _config?.vehicles[normalized]?.capacity ?? 4;
  }

  Map<String, dynamic> getPricingConfig(String vehicleType) {
    final normalized = _normalizeVehicleType(vehicleType);
    return _config?.vehicles[normalized]?.toJson() ??
        _config?.vehicles['essentials']?.toJson() ??
        {};
  }

  double calculateModifiedTripPrice({
    required double originalPrice,
    required double originalDistance,
    required double distanceTraveled,
    required double newSegmentDistance,
    required String vehicleType,
  }) {
    final double safeOriginalDistance = originalDistance > 0
        ? originalDistance
        : 0.1;
    final double completedPercentage = (distanceTraveled / safeOriginalDistance)
        .clamp(0.0, 1.0);
    final double completedCost = originalPrice * completedPercentage;

    final double newSegmentCost = calculatePrice(
      newSegmentDistance,
      vehicleType,
    );
    final double total = completedCost + newSegmentCost;

    return double.parse(total.toStringAsFixed(2));
  }
}
