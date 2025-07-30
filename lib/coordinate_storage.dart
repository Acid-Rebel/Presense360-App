import 'package:hive/hive.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class CoordinateStorage {
  static final Box geoBox = Hive.box('geoBox');

  static Future<void> savePolygon(String id, List<List<double>> coordinates) async {
    await geoBox.put(id, coordinates);
  }

  static List<List<double>>? getPolygon(String id) {
    final data = geoBox.get(id);
    if (data != null && data is List) {
      return data.map<List<double>>((e) => List<double>.from(e)).toList();
    }
    return null;
  }

  static bool hasPolygon(String id) {
    return geoBox.containsKey(id);
  }

  static Future<void> deletePolygon(String id) async {
    await geoBox.delete(id);
  }

  Future<void> storeCoordinates(List<dynamic> geofences, List<int> encryptionKey) async {
    final box = Hive.box('geoBox');

    for (var item in geofences) {
      final id = item['id'];
      final coordinates = item['coordinates']; // Expecting List<List<double>>

      await box.put(id, coordinates); // Store coordinates with 'id' as key
      await FlutterSecureStorage().write(key: 'geo_data_written', value: 'true');

    }
  }

}
