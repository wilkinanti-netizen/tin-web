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
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
      phoneNumber: json['phone_number'],
      gender: json['gender'],
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'])
          : null,
      isDriver: json['is_driver'] ?? false,
      driverStatus: json['driver_status'] != null
          ? DriverStatus.values.byName(json['driver_status'])
          : null,
      lastMode: json['last_mode'],
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 5.0,
      totalRatings: json['total_ratings'] as int? ?? 0,
      deviceId: json['device_id'],
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

  Vehicle({
    required this.id,
    required this.model,
    required this.plate,
    required this.type,
    this.isVerified = false,
    this.isActive = false,
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

  DriverProfile({
    required this.profileId,
    required this.vehicleModel,
    required this.vehiclePlate,
    required this.vehicleType,
    required this.activeServices,
    this.vehicles = const [],
    this.totalEarnings = 0.0,
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
      activeServices:
          (json['active_services'] as List<dynamic>?)
              ?.map((e) => VehicleType.values.byName(e as String))
              .toList() ??
          [VehicleType.values.byName(json['vehicle_type'])],
      vehicles: [currentVehicle], // Por ahora solo uno
      totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0.0,
    );

    print(
      'DriverProfile: Perfil parseado para ${profile.profileId}. Servicios activos: ${profile.activeServices.map((e) => e.name).toList()}',
    );
    return profile;
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_id': profileId,
      'vehicle_model': vehicleModel,
      'vehicle_plate': vehiclePlate,
      'vehicle_type': vehicleType.name,
      'active_services': activeServices.map((e) => e.name).toList(),
      'total_earnings': totalEarnings,
    };
  }
}
