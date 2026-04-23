import 'package:cloud_firestore/cloud_firestore.dart';
enum DriverStatus { active, inactive, pending, rejected }

enum VehicleType { essentials, essentialXL, executive, signature }

class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final String? phoneNumber;
  final String? gender;
  final DateTime? birthDate;
  final bool isDriver;
  final DriverStatus? driverStatus;
  final String? lastMode;
  final double? averageRating;
  final int? totalRatings;
  final String? deviceId;
  final String? mapEmoji;
  final double walletBalance;
  final bool isAdmin;
  final String? referralCode;
  final String? referredById;

  AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    this.phoneNumber,
    this.gender,
    this.birthDate,
    required this.isDriver,
    this.driverStatus,
    this.lastMode,
    this.averageRating,
    this.totalRatings,
    this.deviceId,
    this.mapEmoji,
    this.walletBalance = 0.0,
    this.isAdmin = false,
    this.referralCode,
    this.referredById,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
      phoneNumber: json['phone_number'] ?? json['phone'],
      gender: json['gender'],
      birthDate: json['birth_date'] != null
          ? (json['birth_date'] is Timestamp 
              ? (json['birth_date'] as Timestamp).toDate() 
              : DateTime.tryParse(json['birth_date']))
          : null,
      isDriver: json['is_driver'] ?? false,
      driverStatus: json['driver_status'] != null
          ? DriverStatus.values.byName(json['driver_status'])
          : null,
      lastMode: json['last_mode'],
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 5.0,
      totalRatings: json['total_ratings'] as int? ?? 0,
      deviceId: json['device_id'],
      mapEmoji: json['map_emoji'],
      walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0.0,
      isAdmin: json['is_admin'] ?? false,
      referralCode: json['referral_code'],
      referredById: json['referred_by_id'],
    );
  }
}

class Vehicle {
  final String id;
  final String model;
  final String plate;
  final VehicleType type;
  final bool isVerified;
  final bool isActive;
  final String? color;

  Vehicle({
    required this.id,
    required this.model,
    required this.plate,
    required this.type,
    this.isVerified = false,
    this.isActive = false,
    this.color,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] ?? '',
      model: json['model'] ?? json['vehicle_model'] ?? '',
      plate: json['plate'] ?? json['vehicle_plate'] ?? '',
      type: VehicleType.values.byName(
        json['type'] ?? json['vehicle_type'] ?? 'essentials',
      ),
      isVerified: json['is_verified'] ?? false,
      isActive: json['is_active'] ?? false,
      color: json['color'] ?? json['vehicle_color'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'model': model,
      'plate': plate,
      'type': type.name,
      'is_verified': isVerified,
      'is_active': isActive,
      'color': color,
    };
  }
}

class DriverProfile {
  final String profileId;
  final String vehicleModel;
  final String vehiclePlate;
  final VehicleType vehicleType;
  final List<VehicleType> activeServices;
  final List<Vehicle> vehicles;
  final double totalEarnings;
  final String? vehicleColor;
  final double? lastLat;
  final double? lastLng;
  final double? lastHeading;
  final DateTime? lastLocationUpdate;

  DriverProfile({
    required this.profileId,
    required this.vehicleModel,
    required this.vehiclePlate,
    required this.vehicleType,
    required this.activeServices,
    this.vehicles = const [],
    this.totalEarnings = 0.0,
    this.vehicleColor,
    this.lastLat,
    this.lastLng,
    this.lastHeading,
    this.lastLocationUpdate,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    // Si viene de driver_data simple, el vehículo actual es el principal
    final currentVehicle = Vehicle(
      id: 'default',
      model: json['vehicle_model'],
      plate: json['vehicle_plate'],
      type: VehicleType.values.byName(json['vehicle_type']),
      isVerified: json['is_verified'] ?? false,
      isActive: true,
    );

    final profile = DriverProfile(
      profileId: json['profile_id'],
      vehicleModel: json['vehicle_model'],
      vehiclePlate: json['vehicle_plate'],
      vehicleType: VehicleType.values.byName(json['vehicle_type']),
      vehicleColor: json['vehicle_color'],
      activeServices:
          (json['active_services'] as List<dynamic>?)
              ?.map((e) => VehicleType.values.byName(e as String))
              .toList() ??
          [VehicleType.values.byName(json['vehicle_type'])],
      vehicles: [currentVehicle], // Por ahora solo uno
      totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0.0,
      lastLat: (json['last_lat'] as num?)?.toDouble(),
      lastLng: (json['last_lng'] as num?)?.toDouble(),
      lastHeading: (json['last_heading'] as num?)?.toDouble(),
      lastLocationUpdate: json['last_location_update'] != null
          ? (json['last_location_update'] is Timestamp
              ? (json['last_location_update'] as Timestamp).toDate()
              : DateTime.tryParse(json['last_location_update']))
          : null,
    );

    return profile;
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_id': profileId,
      'vehicle_model': vehicleModel,
      'vehicle_plate': vehiclePlate,
      'vehicle_type': vehicleType.name,
      'vehicle_color': vehicleColor,
      'active_services': activeServices.map((e) => e.name).toList(),
      'total_earnings': totalEarnings,
      'last_lat': lastLat,
      'last_lng': lastLng,
      'last_heading': lastHeading,
      'last_location_update': lastLocationUpdate?.toIso8601String(),
    };
  }
}
