import 'package:latlong2/latlong.dart';

class RouteResult {
  final double distanceKm;
  final Duration duration;
  final List<LatLng> geometry;

  const RouteResult({
    required this.distanceKm,
    required this.duration,
    required this.geometry,
  });
}
