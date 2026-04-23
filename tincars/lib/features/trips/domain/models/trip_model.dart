import 'package:tincars/core/utils/app_logger.dart';
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

class TripStop {
  final LatLng location;
  final String address;
  final bool isCompleted;

  TripStop({
    required this.location,
    required this.address,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'lat': location.latitude,
        'lng': location.longitude,
        'address': address,
        'is_completed': isCompleted,
      };

  factory TripStop.fromJson(Map<String, dynamic> json) => TripStop(
        location: LatLng(json['lat'], json['lng']),
        address: json['address'],
        isCompleted: json['is_completed'] ?? false,
      );
}

class Trip {
  final String id;
  final String passengerId;
  final String? driverId;
  final LatLng pickupLocation;
  final LatLng dropoffLocation;
  final String pickupAddress;
  final String dropoffAddress;
  final List<TripStop> intermediateStops;
  final double distance;
  final double price;
  final TripStatus status;
  final DateTime createdAt;

  final LatLng? driverLocation;
  final LatLng? passengerLocation;
  final String? passengerEmoji;
  final String vehicleType; // 'car' or 'moto'
  final String paymentMethod;
  final String? comment;
  final bool hasExtraLuggage;
  final bool hasPets;
  final String? paymentIntentId;
  final String? paymentStatus; // 'pending', 'succeeded', 'failed'
  final String? cancellationReason;
  final double? tipAmount;
  final double? driverHeading;

  Trip({
    required this.id,
    required this.passengerId,
    this.driverId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.intermediateStops = const [],
    required this.distance,
    required this.price,
    required this.status,
    required this.createdAt,
    this.driverLocation,
    this.passengerLocation,
    this.passengerEmoji,
    required this.vehicleType,
    this.paymentMethod = 'Efectivo',
    this.comment,
    this.hasExtraLuggage = false,
    this.hasPets = false,
    this.paymentIntentId,
    this.paymentStatus,
    this.cancellationReason,
    this.tipAmount,
    this.driverHeading,
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
      'intermediate_stops': intermediateStops.map((s) => s.toJson()).toList(),
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
    if (passengerLocation != null) {
      map['passenger_lat'] = passengerLocation!.latitude;
      map['passenger_lng'] = passengerLocation!.longitude;
    }
    if (passengerEmoji != null) map['passenger_emoji'] = passengerEmoji!;
    if (comment != null) map['comment'] = comment!;
    if (paymentIntentId != null) map['payment_intent_id'] = paymentIntentId!;
    if (paymentStatus != null) map['payment_status'] = paymentStatus!;
    if (cancellationReason != null) {
      map['cancellation_reason'] = cancellationReason!;
    }
    if (tipAmount != null) map['tip_amount'] = tipAmount!;

    return map;
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    try {
      return Trip(
        id: json['id'] ?? '',
        passengerId: json['passenger_id'] ?? '',
        driverId: json['driver_id'],
        pickupLocation: LatLng(json['pickup_lat'] ?? 0, json['pickup_lng'] ?? 0),
        dropoffLocation:
            LatLng(json['dropoff_lat'] ?? 0, json['dropoff_lng'] ?? 0),
        pickupAddress: json['pickup_address'] ?? '',
        dropoffAddress: json['dropoff_address'] ?? '',
        intermediateStops: (json['intermediate_stops'] as List? ?? [])
            .map((s) => TripStop.fromJson(s))
            .toList(),
        distance: (json['distance'] as num? ?? 0).toDouble(),
        price: (json['price'] as num? ?? 0).toDouble(),
        status: _parseStatus(json['status'] ?? 'requested'),
        createdAt: json['created_at'] is Timestamp
            ? (json['created_at'] as Timestamp).toDate()
            : DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
        driverLocation: json['driver_lat'] != null && json['driver_lng'] != null
            ? LatLng(json['driver_lat'], json['driver_lng'])
            : null,
        passengerLocation:
            json['passenger_lat'] != null && json['passenger_lng'] != null
                ? LatLng(json['passenger_lat'], json['passenger_lng'])
                : null,
        passengerEmoji: json['passenger_emoji'],
        vehicleType: json['vehicle_type'] ?? 'essentials',
        paymentMethod: json['payment_method'] ?? 'Efectivo',
        comment: json['comment'],
        hasExtraLuggage: json['has_extra_luggage'] ?? false,
        hasPets: json['has_pets'] ?? false,
        paymentIntentId: json['payment_intent_id'],
        paymentStatus: json['payment_status'],
        cancellationReason: json['cancellation_reason'],
        tipAmount: (json['tip_amount'] as num?)?.toDouble(),
        driverHeading: (json['driver_heading'] as num?)?.toDouble(),
      );
    } catch (e, stack) {
      AppLogger.log('ERROR en Trip.fromJson: $e\n$stack');
      rethrow;
    }
  }

  static TripStatus _parseStatus(String statusStr) {
    final normalized = statusStr.toLowerCase().trim();

    // Handle specific common mappings
    if (normalized == 'in_progress' || normalized == 'inprogress')
      return TripStatus.inProgress;
    if (normalized == 'cancelled' || normalized == 'canceled')
      return TripStatus.cancelled;

    for (var val in TripStatus.values) {
      if (val.name.toLowerCase() == normalized) return val;
    }

    AppLogger.log(
      'WARNING: Status desconocido "$statusStr", asumiendo requested',
    );
    return TripStatus.requested;
  }
}
