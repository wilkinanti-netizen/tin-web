import 'package:cloud_firestore/cloud_firestore.dart';

enum DriverStatus { active, inactive, pending, rejected }

enum VehicleType { essentials, essentialXL, executive, signature }

class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final String? phoneNumber;
  final bool isDriver;
  final DriverStatus? driverStatus;
  final bool isLeader;
  final String? city;
  final String? ssnLast4;
  final String? referredById;

  AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    this.phoneNumber,
    required this.isDriver,
    this.driverStatus,
    this.isLeader = false,
    this.city,
    this.ssnLast4,
    this.referredById,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? 'Unknown',
      avatarUrl: json['avatar_url'],
      phoneNumber: json['phone_number'],
      isDriver: json['is_driver'] ?? false,
      driverStatus: json['driver_status'] != null
          ? _parseDriverStatus(json['driver_status'])
          : null,
      isLeader: json['is_leader'] ?? false,
      city: json['city'],
      ssnLast4: json['ssn_last_4'],
      referredById: json['referred_by_id'],
    );
  }

  static DriverStatus _parseDriverStatus(String statusStr) {
    try {
      return DriverStatus.values.byName(statusStr.toLowerCase());
    } catch (e) {
      return DriverStatus.pending;
    }
  }
}

class DriverProfile {
  final String profileId;
  final String vehicleModel;
  final String vehiclePlate;
  final VehicleType vehicleType;
  final List<VehicleType> activeServices;

  final String? vehicleColor;
  final String? vehicleYear;
  final bool backgroundCheckConsent;

  // Documents (from driver_data table)
  final String? docLicenseUrl;
  final String? docInsuranceUrl;
  final String? docRegistrationUrl;
  final String? docPhotoUrl;

  DriverProfile({
    required this.profileId,
    required this.vehicleModel,
    required this.vehiclePlate,
    required this.vehicleType,
    required this.activeServices,
    this.vehicleColor,
    this.vehicleYear,
    this.docLicenseUrl,
    this.docInsuranceUrl,
    this.docRegistrationUrl,
    this.docPhotoUrl,
    this.backgroundCheckConsent = false,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      profileId: json['profile_id'] ?? '',
      vehicleModel: json['vehicle_model'] ?? 'Unknown',
      vehiclePlate: json['vehicle_plate'] ?? 'Unknown',
      vehicleType: _parseVehicleType(json['vehicle_type'] ?? 'essentials'),
      activeServices:
          (json['active_services'] as List<dynamic>?)
              ?.map((e) => _parseVehicleType(e as String))
              .toList() ??
          [_parseVehicleType(json['vehicle_type'] ?? 'essentials')],
      vehicleColor: json['vehicle_color'],
      vehicleYear: json['vehicle_year']?.toString(),
      docLicenseUrl: json['doc_license_url'],
      docInsuranceUrl: json['doc_insurance_url'],
      docRegistrationUrl: json['doc_registration_url'],
      docPhotoUrl: json['doc_photo_url'],
      backgroundCheckConsent: json['background_check_consent'] ?? false,
    );
  }

  static VehicleType _parseVehicleType(String typeStr) {
    try {
      if (typeStr == 'essentials_xl') return VehicleType.essentialXL;
      return VehicleType.values.byName(typeStr.toLowerCase());
    } catch (e) {
      return VehicleType.essentials;
    }
  }
}

class DriverVerification {
  final String driverId;
  final String? dniNumber;
  final String? facePhotoUrl;
  final String? licensePhotoUrl;
  final String? licenseBackPhotoUrl;
  final String? dniFrontPhotoUrl;
  final String? dniBackPhotoUrl;
  final String? registrationPhotoUrl;
  final String? vehiclePhotoUrl;
  final String status;
  final String? rejectionReason;

  DriverVerification({
    required this.driverId,
    this.dniNumber,
    this.facePhotoUrl,
    this.licensePhotoUrl,
    this.licenseBackPhotoUrl,
    this.dniFrontPhotoUrl,
    this.dniBackPhotoUrl,
    this.registrationPhotoUrl,
    this.vehiclePhotoUrl,
    required this.status,
    this.rejectionReason,
  });

  factory DriverVerification.fromJson(Map<String, dynamic> json) {
    return DriverVerification(
      driverId: json['driver_id'] ?? '',
      dniNumber: json['dni_number'],
      facePhotoUrl: json['face_photo_url'],
      licensePhotoUrl: json['license_photo_url'],
      licenseBackPhotoUrl: json['license_back_photo_url'],
      dniFrontPhotoUrl: json['dni_front_photo_url'],
      dniBackPhotoUrl: json['dni_back_photo_url'],
      registrationPhotoUrl: json['registration_photo_url'],
      vehiclePhotoUrl: json['vehicle_photo_url'],
      status: json['status'] ?? 'pending',
      rejectionReason: json['rejection_reason'],
    );
  }
}
