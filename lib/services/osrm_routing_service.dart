import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/route_result.dart';

class OsrmRoutingService {
  final http.Client _client;
  OsrmRoutingService({http.Client? client}) : _client = client ?? http.Client();

  Future<RouteResult> route(List<LatLng> points) async {
    if (points.length < 2) {
      throw ArgumentError('Нужно минимум две точки');
    }

    final coords = points
        .map((p) => '${p.longitude},${p.latitude}')
        .join(';');

    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$coords'
      '?overview=full&geometries=geojson&steps=false',
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Ошибка маршрута HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>;
    if (routes.isEmpty) throw Exception('Маршрут не найден');

    final first = routes.first as Map<String, dynamic>;
    final geometry = first['geometry'] as Map<String, dynamic>;
    final coordsList = geometry['coordinates'] as List<dynamic>;

    final polyline = coordsList.map((item) {
      final pair = item as List<dynamic>;
      return LatLng(
        (pair[1] as num).toDouble(),
        (pair[0] as num).toDouble(),
      );
    }).toList();

    return RouteResult(
      distanceKm: (first['distance'] as num).toDouble() / 1000,
      duration: Duration(
        seconds: (first['duration'] as num).round(),
      ),
      geometry: polyline,
    );
  }
}
