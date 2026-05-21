import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tincars/core/services/realtime_location_service.dart';
import 'package:tincars/core/utils/app_logger.dart';

/// Represents a demand zone with its surge multiplier
class DemandZone {
  final LatLng center;
  final double radiusMeters;
  final int requestCount;
  final int driverCount;
  final double surgeMultiplier;

  DemandZone({
    required this.center,
    required this.radiusMeters,
    required this.requestCount,
    required this.driverCount,
    required this.surgeMultiplier,
  });
}

/// Service that calculates surge pricing based on supply/demand ratio
/// and generates heatmap data for driver visualization.
class SurgePricingService {
  SurgePricingService._();
  static final SurgePricingService instance = SurgePricingService._();

  final RealtimeLocationService _locationService =
      RealtimeLocationService.instance;

  // Grid cell size in degrees (approx 1km at equator)
  static const double _gridSize = 0.01;

  /// Calculate surge multiplier for a given pickup location
  /// based on supply (drivers) and demand (trip requests) ratio.
  Future<double> getSurgeMultiplier(LatLng pickupLocation) async {
    try {
      // Get demand and supply data
      final demandCompleter = Completer<List<LatLng>>();
      final supplyCompleter =
          Completer<Map<String, Map<String, dynamic>>>();

      _locationService.streamDemandHeatmap().first.then(
        demandCompleter.complete,
        onError: demandCompleter.completeError,
      );
      _locationService.streamAllOnlineDrivers().first.then(
        supplyCompleter.complete,
        onError: supplyCompleter.completeError,
      );

      final demandPoints = await demandCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => <LatLng>[],
      );
      final onlineDrivers = await supplyCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => <String, Map<String, dynamic>>{},
      );

      // Count requests and drivers within 2km radius of pickup
      int nearbyRequests = 0;
      int nearbyDrivers = 0;
      const double radiusKm = 2.0;

      for (final point in demandPoints) {
        final dist = _distanceKm(pickupLocation, point);
        if (dist <= radiusKm) nearbyRequests++;
      }

      for (final entry in onlineDrivers.entries) {
        final driverLat = (entry.value['lat'] as num).toDouble();
        final driverLng = (entry.value['lng'] as num).toDouble();
        final dist =
            _distanceKm(pickupLocation, LatLng(driverLat, driverLng));
        if (dist <= radiusKm) nearbyDrivers++;
      }

      // Calculate surge multiplier
      return _calculateMultiplier(nearbyRequests, nearbyDrivers);
    } catch (e) {
      AppLogger.error('Error calculating surge multiplier', error: e);
      return 1.0; // No surge on error
    }
  }

  /// Generate heatmap circles for the driver's map view
  /// showing zones of high demand with color intensity
  Future<Set<Circle>> generateHeatmapCircles() async {
    try {
      final demandPoints = await _locationService
          .streamDemandHeatmap()
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () => <LatLng>[]);

      if (demandPoints.isEmpty) return {};

      // Group points into grid cells
      final Map<String, List<LatLng>> gridCells = {};

      for (final point in demandPoints) {
        final cellKey =
            '${(point.latitude / _gridSize).floor()}_${(point.longitude / _gridSize).floor()}';
        gridCells.putIfAbsent(cellKey, () => []);
        gridCells[cellKey]!.add(point);
      }

      // Create circles for each grid cell with demand
      final circles = <Circle>{};
      int index = 0;

      for (final entry in gridCells.entries) {
        final points = entry.value;
        if (points.isEmpty) continue;

        // Calculate center of the cell
        double avgLat = 0, avgLng = 0;
        for (final p in points) {
          avgLat += p.latitude;
          avgLng += p.longitude;
        }
        avgLat /= points.length;
        avgLng /= points.length;

        // Intensity based on number of requests
        final intensity = (points.length / 5.0).clamp(0.15, 1.0);
        final color = _getHeatColor(intensity);

        circles.add(Circle(
          circleId: CircleId('heatmap_$index'),
          center: LatLng(avgLat, avgLng),
          radius: 500, // 500 meters
          fillColor: color.withOpacity(0.25 * intensity),
          strokeColor: color.withOpacity(0.4),
          strokeWidth: 1,
        ));
        index++;
      }

      return circles;
    } catch (e) {
      AppLogger.error('Error generating heatmap circles', error: e);
      return {};
    }
  }

  /// Calculate the surge multiplier based on demand/supply ratio
  double _calculateMultiplier(int requests, int drivers) {
    if (drivers == 0 && requests == 0) return 1.0;
    if (drivers == 0 && requests > 0) return 2.0; // Max surge when no drivers

    final ratio = requests / drivers;

    // Surge thresholds:
    // ratio < 1.0 -> no surge (more drivers than requests)
    // ratio 1.0-2.0 -> 1.0x-1.3x
    // ratio 2.0-3.0 -> 1.3x-1.5x
    // ratio 3.0-5.0 -> 1.5x-1.8x
    // ratio > 5.0 -> 2.0x (cap)

    if (ratio <= 1.0) return 1.0;
    if (ratio <= 2.0) return 1.0 + (ratio - 1.0) * 0.3;
    if (ratio <= 3.0) return 1.3 + (ratio - 2.0) * 0.2;
    if (ratio <= 5.0) return 1.5 + (ratio - 3.0) * 0.15;
    return 2.0;
  }

  /// Get heat color from green (low) to red (high)
  Color _getHeatColor(double intensity) {
    if (intensity < 0.33) {
      return Color.lerp(Colors.green, Colors.yellow, intensity * 3)!;
    } else if (intensity < 0.66) {
      return Color.lerp(
          Colors.yellow, Colors.orange, (intensity - 0.33) * 3)!;
    } else {
      return Color.lerp(
          Colors.orange, Colors.red, (intensity - 0.66) * 3)!;
    }
  }

  /// Haversine formula for distance in km
  double _distanceKm(LatLng a, LatLng b) {
    const earthRadius = 6371.0;
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLng = _toRadians(b.longitude - a.longitude);
    final sinDLat = sin(dLat / 2);
    final sinDLng = sin(dLng / 2);
    final x = sinDLat * sinDLat +
        cos(_toRadians(a.latitude)) *
            cos(_toRadians(b.latitude)) *
            sinDLng *
            sinDLng;
    return earthRadius * 2 * atan2(sqrt(x), sqrt(1 - x));
  }

  double _toRadians(double degrees) => degrees * pi / 180;
}

/// Riverpod provider for demand heatmap circles
final demandHeatmapProvider = StreamProvider<Set<Circle>>((ref) {
  return Stream.periodic(
    const Duration(seconds: 30),
    (_) => SurgePricingService.instance.generateHeatmapCircles(),
  ).asyncMap((future) => future);
});

/// Provider for surge multiplier at a given location
final surgeMultiplierProvider =
    FutureProvider.family<double, LatLng>((ref, location) {
  return SurgePricingService.instance.getSurgeMultiplier(location);
});
