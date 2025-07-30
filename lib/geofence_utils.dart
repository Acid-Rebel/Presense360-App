import 'package:hive/hive.dart';
import 'package:turf/turf.dart';

/// Checks if the given lat/lon is inside any polygon stored in Hive
Future<bool> isInsideAnyFence(double latitude, double longitude) async {
  final Box box = Hive.box('geoBox'); // assuming already opened

  final Position userPosition = Position(longitude, latitude); // Turf uses [lon, lat]

  for (final dynamic value in box.values) {
    try {
      List<dynamic> rawCoords = value as List<dynamic>;

      final List<Position> polygonPoints = rawCoords
          .map<Position>((coord) => Position(coord[0] as double, coord[1] as double))
          .toList();

      final Polygon polygon = Polygon(coordinates: [polygonPoints]);

      if (booleanPointInPolygon(userPosition, polygon)) {
        return true;
      }
    } catch (e) {
      print("Invalid geofence entry in Hive: $e");
      continue;
    }
  }

  return false;
}
