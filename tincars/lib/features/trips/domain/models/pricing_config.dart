import 'package:cloud_firestore/cloud_firestore.dart';

class PricingTier {
  final int upToKm;
  final double pricePerKm;

  PricingTier({required this.upToKm, required this.pricePerKm});

  factory PricingTier.fromJson(Map<String, dynamic> json) {
    return PricingTier(
      upToKm: (json['up_to_km'] as num?)?.toInt() ?? 0,
      pricePerKm: (json['price_per_km'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {'up_to_km': upToKm, 'price_per_km': pricePerKm};
}


class VehiclePricing {
  final String name;
  final String description;
  final int capacity;
  final double base;
  final double baseWeekend;
  final List<PricingTier> distanceTiers;
  final int waitTimeFreeMinutes;
  final double waitTimeFeePerMinute;

  VehiclePricing({
    required this.name,
    required this.description,
    required this.capacity,
    required this.base,
    required this.baseWeekend,
    required this.distanceTiers,
    required this.waitTimeFreeMinutes,
    required this.waitTimeFeePerMinute,
  });


  factory VehiclePricing.fromJson(Map<String, dynamic> json) {
    return VehiclePricing(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      capacity: (json['capacity'] as num?)?.toInt() ?? 4,
      base: (json['base'] as num?)?.toDouble() ?? 0.0,
      baseWeekend: (json['base_weekend'] as num?)?.toDouble() ?? 0.0,
      distanceTiers: (json['distance_tiers'] as List<dynamic>?)
              ?.map((e) => PricingTier.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      waitTimeFreeMinutes: (json['wait_time_free_minutes'] as num?)?.toInt() ?? 5,
      waitTimeFeePerMinute: (json['wait_time_fee_per_minute'] as num?)?.toDouble() ?? 0.0,
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'capacity': capacity,
      'base': base,
      'base_weekend': baseWeekend,
      'distance_tiers': distanceTiers.map((e) => e.toJson()).toList(),
      'wait_time_free_minutes': waitTimeFreeMinutes,
      'wait_time_fee_per_minute': waitTimeFeePerMinute,
    };
  }

}

class CommissionConfig {
  final bool enabled;
  final double percentage;
  final String message;

  CommissionConfig({
    required this.enabled,
    required this.percentage,
    required this.message,
  });

  factory CommissionConfig.fromJson(Map<String, dynamic> json) {
    return CommissionConfig(
      enabled: json['enabled'] ?? false,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      message: json['message'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'percentage': percentage,
      'message': message,
    };
  }
}

class PricingConfig {
  final Map<String, VehiclePricing> vehicles;
  final CommissionConfig commission;

  PricingConfig({required this.vehicles, required this.commission});

  factory PricingConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final vehiclesData = data['vehicles'] as Map<String, dynamic>? ?? {};
    final commissionData = data['commission'] as Map<String, dynamic>? ?? {};

    return PricingConfig(
      vehicles: vehiclesData.map(
        (key, value) => MapEntry(key, VehiclePricing.fromJson(value as Map<String, dynamic>)),
      ),
      commission: CommissionConfig.fromJson(commissionData),
    );
  }
}
