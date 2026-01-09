import 'dart:math' as math;

/// Utility class for Google Polyline encoding/decoding
/// Used to efficiently store GPS routes as compact strings
class PolylineUtils {
  PolylineUtils._();

  /// Encode a list of coordinates into a polyline string
  /// Coordinates are [latitude, longitude] pairs
  static String encode(List<List<double>> coordinates) {
    if (coordinates.isEmpty) return '';

    final StringBuffer encoded = StringBuffer();
    int lastLat = 0;
    int lastLng = 0;

    for (final coord in coordinates) {
      final lat = (coord[0] * 1e5).round();
      final lng = (coord[1] * 1e5).round();

      encoded.write(_encodeSignedNumber(lat - lastLat));
      encoded.write(_encodeSignedNumber(lng - lastLng));

      lastLat = lat;
      lastLng = lng;
    }

    return encoded.toString();
  }

  /// Decode a polyline string into a list of coordinates
  /// Returns list of [latitude, longitude] pairs
  static List<List<double>> decode(String encoded) {
    if (encoded.isEmpty) return [];

    final List<List<double>> coordinates = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      // Decode latitude
      final latResult = _decodeSignedNumber(encoded, index);
      lat += latResult.value;
      index = latResult.nextIndex;

      // Decode longitude
      final lngResult = _decodeSignedNumber(encoded, index);
      lng += lngResult.value;
      index = lngResult.nextIndex;

      coordinates.add([lat / 1e5, lng / 1e5]);
    }

    return coordinates;
  }

  /// Encode a signed number for polyline format
  static String _encodeSignedNumber(int num) {
    int sgn = num << 1;
    if (num < 0) {
      sgn = ~sgn;
    }
    return _encodeNumber(sgn);
  }

  /// Encode a number for polyline format
  static String _encodeNumber(int num) {
    final StringBuffer encoded = StringBuffer();
    
    while (num >= 0x20) {
      encoded.writeCharCode((0x20 | (num & 0x1f)) + 63);
      num >>= 5;
    }
    encoded.writeCharCode(num + 63);
    
    return encoded.toString();
  }

  /// Decode a signed number from polyline format
  static ({int value, int nextIndex}) _decodeSignedNumber(String encoded, int index) {
    int shift = 0;
    int result = 0;
    int char;

    do {
      char = encoded.codeUnitAt(index++) - 63;
      result |= (char & 0x1f) << shift;
      shift += 5;
    } while (char >= 0x20);

    final value = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    return (value: value, nextIndex: index);
  }

  /// Calculate total distance of a polyline in kilometers
  static double calculateTotalDistance(List<List<double>> coordinates) {
    if (coordinates.length < 2) return 0;

    double totalDistance = 0;
    for (int i = 1; i < coordinates.length; i++) {
      totalDistance += _haversineDistance(
        coordinates[i - 1][0],
        coordinates[i - 1][1],
        coordinates[i][0],
        coordinates[i][1],
      );
    }

    return totalDistance / 1000; // Convert to km
  }

  /// Calculate distance between two points using Haversine formula (in meters)
  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // meters

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  /// Simplify a polyline using Douglas-Peucker algorithm
  /// This reduces the number of points while preserving the shape
  static List<List<double>> simplify(List<List<double>> coordinates, double tolerance) {
    if (coordinates.length <= 2) return coordinates;

    // Find the point with the maximum distance from the line
    double maxDistance = 0;
    int maxIndex = 0;

    final start = coordinates.first;
    final end = coordinates.last;

    for (int i = 1; i < coordinates.length - 1; i++) {
      final distance = _perpendicularDistance(coordinates[i], start, end);
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }

    // If max distance is greater than tolerance, recursively simplify
    if (maxDistance > tolerance) {
      final firstPart = simplify(coordinates.sublist(0, maxIndex + 1), tolerance);
      final secondPart = simplify(coordinates.sublist(maxIndex), tolerance);
      
      return [...firstPart.sublist(0, firstPart.length - 1), ...secondPart];
    } else {
      return [start, end];
    }
  }

  /// Calculate perpendicular distance from a point to a line
  static double _perpendicularDistance(
    List<double> point,
    List<double> lineStart,
    List<double> lineEnd,
  ) {
    final dx = lineEnd[1] - lineStart[1];
    final dy = lineEnd[0] - lineStart[0];

    final mag = math.sqrt(dx * dx + dy * dy);
    if (mag == 0) return 0;

    final u = ((point[1] - lineStart[1]) * dx + (point[0] - lineStart[0]) * dy) /
        (mag * mag);

    double closestX, closestY;
    if (u < 0) {
      closestX = lineStart[1];
      closestY = lineStart[0];
    } else if (u > 1) {
      closestX = lineEnd[1];
      closestY = lineEnd[0];
    } else {
      closestX = lineStart[1] + u * dx;
      closestY = lineStart[0] + u * dy;
    }

    return _haversineDistance(point[0], point[1], closestY, closestX);
  }
}
