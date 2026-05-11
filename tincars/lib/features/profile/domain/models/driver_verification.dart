import 'package:cloud_firestore/cloud_firestore.dart';

class DriverVerification {
  final String driverId;
  final String dniNumber;
  final DateTime birthDate;
  final String facePhotoUrl;
  final String licensePhotoUrl;
  final String licenseBackPhotoUrl;
  final String dniFrontPhotoUrl;
  final String dniBackPhotoUrl;
  final String registrationPhotoUrl;
  final String vehiclePhotoUrl;
  final String insurancePhotoUrl;
  final String driverMotivation;
  final int hoursPerWeek;
  final bool hasExperience;
  final String ssn;
  final String status;
  final String? rejectionReason;
  final DateTime createdAt;

  DriverVerification({
    required this.driverId,
    required this.dniNumber,
    required this.birthDate,
    required this.facePhotoUrl,
    required this.licensePhotoUrl,
    required this.licenseBackPhotoUrl,
    required this.dniFrontPhotoUrl,
    required this.dniBackPhotoUrl,
    required this.registrationPhotoUrl,
    required this.vehiclePhotoUrl,
    required this.insurancePhotoUrl,
    required this.driverMotivation,
    required this.hoursPerWeek,
    required this.hasExperience,
    required this.ssn,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
  });

  factory DriverVerification.fromJson(Map<String, dynamic> json) {
    return DriverVerification(
      driverId: json['driver_id'] ?? '',
      dniNumber: json['dni_number'] ?? '',
      birthDate: (json['birth_date'] as Timestamp).toDate(),
      facePhotoUrl: json['face_photo_url'] ?? '',
      licensePhotoUrl: json['license_photo_url'] ?? '',
      licenseBackPhotoUrl: json['license_back_photo_url'] ?? '',
      dniFrontPhotoUrl: json['dni_front_photo_url'] ?? '',
      dniBackPhotoUrl: json['dni_back_photo_url'] ?? '',
      registrationPhotoUrl: json['registration_photo_url'] ?? '',
      vehiclePhotoUrl: json['vehicle_photo_url'] ?? '',
      insurancePhotoUrl: json['insurance_photo_url'] ?? '',
      driverMotivation: json['driver_motivation'] ?? '',
      hoursPerWeek: json['hours_per_week'] ?? 0,
      hasExperience: json['has_experience'] ?? false,
      ssn: json['ssn'] ?? '',
      status: json['status'] ?? 'pending',
      rejectionReason: json['rejection_reason'],
      createdAt: (json['created_at'] as Timestamp).toDate(),
    );
  }
}
