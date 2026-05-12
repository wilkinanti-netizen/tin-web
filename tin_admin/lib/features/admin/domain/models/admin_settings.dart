import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSettings {
  final CommissionSettings commission;
  final Map<String, VehicleSettings> vehicles;

  AdminSettings({
    required this.commission,
    required this.vehicles,
  });

  factory AdminSettings.fromJson(Map<String, dynamic> json) {
    final commissionJson = json['commission'] as Map<String, dynamic>? ?? {};
    final vehiclesJson = json['vehicles'] as Map<String, dynamic>? ?? {};

    return AdminSettings(
      commission: CommissionSettings.fromJson(commissionJson),
      vehicles: vehiclesJson.map(
        (key, value) => MapEntry(key, VehicleSettings.fromJson(value as Map<String, dynamic>)),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'commission': commission.toJson(),
      'vehicles': vehicles.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}

class CommissionSettings {
  final bool enabled;
  final String message;
  final int percentage;
  final DateTime? lastUpdated;

  CommissionSettings({
    required this.enabled,
    required this.message,
    required this.percentage,
    this.lastUpdated,
  });

  factory CommissionSettings.fromJson(Map<String, dynamic> json) {
    return CommissionSettings(
      enabled: json['enabled'] ?? false,
      message: json['message'] ?? '',
      percentage: (json['percentage'] as num?)?.toInt() ?? 0,
      lastUpdated: (json['last_updated'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'message': message,
      'percentage': percentage,
      'last_updated': lastUpdated != null ? Timestamp.fromDate(lastUpdated!) : FieldValue.serverTimestamp(),
    };
  }
}

class VehicleSettings {
  final double base;
  final double baseWeekend;
  final int capacity;
  final String description;
  final List<DistanceTier> distanceTiers;
  final String name;
  final double waitTimeFeePerMinute;
  final int waitTimeFreeMinutes;

  VehicleSettings({
    required this.base,
    required this.baseWeekend,
    required this.capacity,
    required this.description,
    required this.distanceTiers,
    required this.name,
    required this.waitTimeFeePerMinute,
    required this.waitTimeFreeMinutes,
  });

  factory VehicleSettings.fromJson(Map<String, dynamic> json) {
    return VehicleSettings(
      base: (json['base'] as num?)?.toDouble() ?? 0.0,
      baseWeekend: (json['base_weekend'] as num?)?.toDouble() ?? 0.0,
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      description: json['description'] ?? '',
      distanceTiers: (json['distance_tiers'] as List<dynamic>?)
              ?.map((e) => DistanceTier.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      name: json['name'] ?? '',
      waitTimeFeePerMinute: (json['wait_time_fee_per_minute'] as num?)?.toDouble() ?? 0.0,
      waitTimeFreeMinutes: (json['wait_time_free_minutes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'base': base,
      'base_weekend': baseWeekend,
      'capacity': capacity,
      'description': description,
      'distance_tiers': distanceTiers.map((e) => e.toJson()).toList(),
      'name': name,
      'wait_time_fee_per_minute': waitTimeFeePerMinute,
      'wait_time_free_minutes': waitTimeFreeMinutes,
    };
  }
}

class DistanceTier {
  final double pricePerKm;
  final int upToKm;

  DistanceTier({
    required this.pricePerKm,
    required this.upToKm,
  });

  factory DistanceTier.fromJson(Map<String, dynamic> json) {
    return DistanceTier(
      pricePerKm: (json['price_per_km'] as num?)?.toDouble() ?? 0.0,
      upToKm: (json['up_to_km'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'price_per_km': pricePerKm,
      'up_to_km': upToKm,
    };
  }
}
