import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum TripStatus {
  requested,
  accepted,
  arrived,
  inProgress,
  completed,
  cancelled,
}

class Trip {
  final String id;
  final String passengerId;
  final String? driverId;
  final LatLng pickupLocation;
  final LatLng dropoffLocation;
  final String pickupAddress;
  final String dropoffAddress;
  final double distance;
  final double price;
  final TripStatus status;
  final DateTime createdAt;
  final String vehicleType;

  Trip({
    required this.id,
    required this.passengerId,
    this.driverId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.distance,
    required this.price,
    required this.status,
    required this.createdAt,
    required this.vehicleType,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] ?? '',
      passengerId: json['passenger_id'] ?? '',
      driverId: json['driver_id'],
      pickupLocation: LatLng(
        (json['pickup_lat'] as num?)?.toDouble() ?? 0.0,
        (json['pickup_lng'] as num?)?.toDouble() ?? 0.0,
      ),
      dropoffLocation: LatLng(
        (json['dropoff_lat'] as num?)?.toDouble() ?? 0.0,
        (json['dropoff_lng'] as num?)?.toDouble() ?? 0.0,
      ),
      pickupAddress: json['pickup_address'] ?? 'Unknown',
      dropoffAddress: json['dropoff_address'] ?? 'Unknown',
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      status: _parseStatus(json['status'] ?? 'requested'),
      createdAt: json['created_at'] is Timestamp
          ? (json['created_at'] as Timestamp).toDate()
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now()),
      vehicleType: json['vehicle_type'] ?? 'essentials',
    );
  }

  static TripStatus _parseStatus(String statusStr) {
    final normalized = statusStr.toLowerCase().trim();
    if (normalized == 'in_progress' || normalized == 'inprogress')
      return TripStatus.inProgress;
    if (normalized == 'cancelled' || normalized == 'canceled')
      return TripStatus.cancelled;

    for (var val in TripStatus.values) {
      if (val.name.toLowerCase() == normalized) return val;
    }
    return TripStatus.requested;
  }
}
