import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../database/app_database.dart';
import '../models/route_result.dart';
import '../repositories/ops_repository.dart';
import '../services/location_service.dart';
import '../services/osrm_routing_service.dart';

class RoutePoint {
  final String address;
  final int priority;
  final LatLng position;

  const RoutePoint({
    required this.address,
    required this.priority,
    required this.position,
  });
}

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final _map = MapController();
  final _repo = OpsRepository();
  final _location = LocationService();
  final _routing = OsrmRoutingService();

  RouteResult? _result;
  LatLng? _engineer;
  List<RoutePoint> _points = [];
  bool _loading = false;
  String? _error;

  Future<List<RoutePoint>> _loadPoints() async {
    final requests = await _repo.getOpenRequests();
    final db = await AppDatabase.instance.database;

    final points = <RoutePoint>[];

    for (final request in requests) {
      final rows = await db.query(
        'objects',
        where: 'id = ?',
        whereArgs: [request.objectId],
        limit: 1,
      );

      if (rows.isEmpty) continue;

      final lat = (rows.first['latitude'] as num?)?.toDouble();
      final lon = (rows.first['longitude'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;

      points.add(
        RoutePoint(
          address: request.address,
          priority: request.priority,
          position: LatLng(lat, lon),
        ),
      );
    }

    points.sort((a, b) => b.priority.compareTo(a.priority));
    return points;
  }

  Future<void> _buildRoute() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final current = await _location.currentPosition();
      final points = await _loadPoints();

      if (points.isEmpty) {
        throw Exception('Нет открытых заявок с координатами');
      }

      final route = await _routing.route([
        current,
        ...points.map((e) => e.position),
      ]);

      if (!mounted) return;
      setState(() {
        _engineer = current;
        _points = points;
        _result = route;
      });

      _map.move(current, 13);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_buildRoute);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final info = _result == null
        ? 'Маршрут не рассчитан'
        : '${_result!.distanceKm.toStringAsFixed(1)} км • '
          '${_result!.duration.inMinutes} мин';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Маршрут дня'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _buildRoute,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          ListTile(
            leading: _loading
                ? const CircularProgressIndicator()
                : const Icon(Icons.route),
            title: Text(info),
            subtitle: Text(
              _error ?? 'Сначала более приоритетные заявки',
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _map,
              options: const MapOptions(
                initialCenter: LatLng(56.8389, 60.6057),
                initialZoom: 12.5,
              ),
              children: [
                ColorFiltered(
                  colorFilter: isDark
                      ? const ColorFilter.matrix([
                          0.46, 0, 0, 0, 0,
                          0, 0.50, 0, 0, 0,
                          0, 0, 0.56, 0, 0,
                          0, 0, 0, 1, 0,
                        ])
                      : const ColorFilter.matrix([
                          1, 0, 0, 0, 0,
                          0, 1, 0, 0, 0,
                          0, 0, 1, 0, 0,
                          0, 0, 0, 1, 0,
                        ]),
                  child: TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'ru.opscontrol.app',
                  ),
                ),
                if (_result != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _result!.geometry,
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (_engineer != null)
                      Marker(
                        point: _engineer!,
                        width: 48,
                        height: 48,
                        child: const Icon(
                          Icons.engineering,
                          size: 38,
                        ),
                      ),
                    ..._points.map(
                      (point) => Marker(
                        point: point.position,
                        width: 52,
                        height: 52,
                        child: Tooltip(
                          message:
                              '${point.address}\nПриоритет ${point.priority}',
                          child: const Icon(
                            Icons.location_on,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
