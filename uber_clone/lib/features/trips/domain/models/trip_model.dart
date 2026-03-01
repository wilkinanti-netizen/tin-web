import 'package:tincars/core/utils/app_logger.dart';
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

  final LatLng? driverLocation;
  final String vehicleType; // 'car' or 'moto'
  final String paymentMethod;
  final String? comment;
  final bool hasExtraLuggage;
  final bool hasPets;
  final String? paymentIntentId;
  final String? paymentStatus; // 'pending', 'succeeded', 'failed'
  final String? cancellationReason;

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
    this.driverLocation,
    required this.vehicleType,
    this.paymentMethod = 'Efectivo',
    this.comment,
    this.hasExtraLuggage = false,
    this.hasPets = false,
    this.paymentIntentId,
    this.paymentStatus,
    this.cancellationReason,
  });

  Map<String, dynamic> toJson() {
    final map = {
      'id': id,
      'passenger_id': passengerId,
      'pickup_lat': pickupLocation.latitude,
      'pickup_lng': pickupLocation.longitude,
      'dropoff_lat': dropoffLocation.latitude,
      'dropoff_lng': dropoffLocation.longitude,
      'pickup_address': pickupAddress,
      'dropoff_address': dropoffAddress,
      'distance': distance,
      'price': price,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'vehicle_type': vehicleType,
      'payment_method': paymentMethod,
      'has_extra_luggage': hasExtraLuggage,
      'has_pets': hasPets,
    };

    if (driverId != null) map['driver_id'] = driverId!;
    if (driverLocation != null) {
      map['driver_lat'] = driverLocation!.latitude;
      map['driver_lng'] = driverLocation!.longitude;
    }
    if (comment != null) map['comment'] = comment!;
    if (paymentIntentId != null) map['payment_intent_id'] = paymentIntentId!;
    if (paymentStatus != null) map['payment_status'] = paymentStatus!;
    if (cancellationReason != null) {
      map['cancellation_reason'] = cancellationReason!;
    }

    return map;
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    try {
      return Trip(
        id: json['id'],
        passengerId: json['passenger_id'],
        driverId: json['driver_id'],
        pickupLocation: LatLng(json['pickup_lat'], json['pickup_lng']),
        dropoffLocation: LatLng(json['dropoff_lat'], json['dropoff_lng']),
        pickupAddress: json['pickup_address'],
        dropoffAddress: json['dropoff_address'],
        distance: (json['distance'] as num).toDouble(),
        price: (json['price'] as num).toDouble(),
        status: _parseStatus(json['status']),
        createdAt: DateTime.parse(json['created_at']),
        driverLocation: json['driver_lat'] != null && json['driver_lng'] != null
            ? LatLng(json['driver_lat'], json['driver_lng'])
            : null,
        vehicleType: json['vehicle_type'] ?? 'essentials',
        paymentMethod: json['payment_method'] ?? 'Efectivo',
        comment: json['comment'],
        hasExtraLuggage: json['has_extra_luggage'] ?? false,
        hasPets: json['has_pets'] ?? false,
        paymentIntentId: json['payment_intent_id'],
        paymentStatus: json['payment_status'],
        cancellationReason: json['cancellation_reason'],
      );
    } catch (e, stack) {
      AppLogger.log('ERROR en Trip.fromJson: $e\n$stack');
      rethrow;
    }
  }

  static TripStatus _parseStatus(String statusStr) {
    // Handle both snake_case and camelCase just in case
    final normalized = statusStr.toLowerCase().replaceAll('_', '');
    for (var val in TripStatus.values) {
      if (val.name.toLowerCase() == normalized) return val;
    }
    AppLogger.log('WARNING: Status desconocido "$statusStr", asumiendo requested');
    return TripStatus.requested;
  }
}
