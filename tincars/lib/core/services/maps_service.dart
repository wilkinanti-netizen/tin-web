import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

class MapsService {
  final String _apiKey = "AIzaSyB5w2dlzZa8gLc2z0gN31oDFGo8dh_jhrU";

  Future<List<Map<String, dynamic>>> getAutocompleteSuggestions(
    String input,
    String sessionToken,
  ) async {
    if (input.isEmpty) return [];

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$_apiKey&sessiontoken=$sessionToken', // Performance: Remove country restriction for US/Global support
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['predictions']);
    } else {
      throw Exception('Failed to load suggestions');
    }
  }

  Future<LatLng> getPlaceDetails(String placeId) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry&key=$_apiKey',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final location = data['result']['geometry']['location'];
      return LatLng(location['lat'], location['lng']);
    } else {
      throw Exception('Failed to load place details');
    }
  }

  Future<Map<String, dynamic>> getDirections(
    LatLng origin,
    LatLng destination, {
    List<LatLng> waypoints = const [],
  }) async {
    String waypointsStr = "";
    if (waypoints.isNotEmpty) {
      waypointsStr =
          "&waypoints=" +
          waypoints.map((w) => "${w.latitude},${w.longitude}").join('|');
    }

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}$waypointsStr&key=$_apiKey',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['routes'].isNotEmpty) {
        final route = data['routes'][0];
        final polylinePoints = _decodePolyline(
          route['overview_polyline']['points'],
        );

        double totalDistance = 0;
        int totalDuration = 0;

        for (var leg in route['legs']) {
          totalDistance += leg['distance']['value'] / 1000.0;
          totalDuration += (leg['duration']['value'] / 60.0).ceil() as int;
        }

        // Build human-readable text from the first leg (or total)
        String distanceText = '${totalDistance.toStringAsFixed(1)} km';
        String durationText = '$totalDuration min';
        if (route['legs'].isNotEmpty) {
          final firstLeg = route['legs'][0];
          distanceText = firstLeg['distance']['text'] ?? distanceText;
          durationText = firstLeg['duration']['text'] ?? durationText;
        }

        return {
          'polyline': polylinePoints,
          'distance': totalDistance,
          'duration': totalDuration,
          'distance_text': distanceText,
          'duration_text': durationText,
          'bounds': route['bounds'],
        };
      } else {
        throw Exception(
          'No se encontró una ruta de conducción entre estos puntos.',
        );
      }
    }
    throw Exception('Error al conectar con Google Maps');
  }

  Future<String> getAddressFromLatLng(LatLng location) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=${location.latitude},${location.longitude}&key=$_apiKey',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['results'].isNotEmpty) {
        return data['results'][0]['formatted_address'];
      }
    }
    return "Dirección desconocida";
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  /// Encuentra el punto más cercano en una polilínea para un punto dado (Snap to Road)
  LatLng findNearestPointOnPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return point;

    double minDistance = double.infinity;
    LatLng nearestPoint = polyline.first;

    for (int i = 0; i < polyline.length - 1; i++) {
      final p1 = polyline[i];
      final p2 = polyline[i + 1];

      final snapped = _getNearestPointOnSegment(point, p1, p2);
      final distance = _calculateDistance(point, snapped);

      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = snapped;
      }
    }

    return nearestPoint;
  }

  LatLng _getNearestPointOnSegment(LatLng p, LatLng a, LatLng b) {
    final double l2 = _calculateDistanceSq(a, b);
    if (l2 == 0.0) return a;

    final double t =
        ((p.latitude - a.latitude) * (b.latitude - a.latitude) +
            (p.longitude - a.longitude) * (b.longitude - a.longitude)) /
        l2;

    if (t < 0.0) return a;
    if (t > 1.0) return b;

    return LatLng(
      a.latitude + t * (b.latitude - a.latitude),
      a.longitude + t * (b.longitude - a.longitude),
    );
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    return math.sqrt(_calculateDistanceSq(p1, p2));
  }

  double _calculateDistanceSq(LatLng p1, LatLng p2) {
    final double dx = p1.latitude - p2.latitude;
    final double dy = p1.longitude - p2.longitude;
    return dx * dx + dy * dy;
  }
}
