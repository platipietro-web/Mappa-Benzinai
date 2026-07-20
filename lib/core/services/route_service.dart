import 'package:dio/dio.dart';
import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/core/services/service_error_logger.dart';
import 'package:mappa_prezzi_benzina/domain/entities/route_info.dart';

class RouteService {
  static final _dio = Dio()
    ..options.connectTimeout = const Duration(seconds: 10)
    ..options.receiveTimeout = const Duration(seconds: 15)
    ..options.headers = {'User-Agent': AppConstants.osmUserAgent};

  /// Calcola il percorso stradale (auto) tra due o più punti usando il
  /// server demo pubblico OSRM. [waypoints] va da 2 in su, in ordine
  /// (partenza, eventuali tappe intermedie, destinazione). [alternatives]
  /// chiede percorsi alternativi a OSRM — affidabile solo con esattamente
  /// 2 waypoint; con una tappa intermedia va lasciato `false`.
  /// Ritorna una lista vuota se il servizio non risponde o non trova una
  /// rotta.
  static Future<List<RouteInfo>> getRoutes({
    required List<RoutePoint> waypoints,
    bool alternatives = false,
  }) async {
    assert(waypoints.length >= 2);
    try {
      final coords =
          waypoints.map((w) => '${w.longitude},${w.latitude}').join(';');
      final response = await _dio.get<Map<String, dynamic>>(
        '${AppConstants.osrmBaseUrl}/route/v1/driving/$coords',
        queryParameters: {
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'false',
          if (alternatives) 'alternatives': 'true',
        },
      );

      final data = response.data;
      if (data == null || data['code'] != 'Ok') return const [];

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return const [];

      return routes
          .map((r) => _parseRoute(r as Map<String, dynamic>))
          .whereType<RouteInfo>()
          .toList();
    } on DioException catch (e) {
      ServiceErrorLogger.log('osrm',
          detail: e.response?.statusCode?.toString() ?? e.type.name);
      return const [];
    } catch (_) {
      return const [];
    }
  }

  static RouteInfo? _parseRoute(Map<String, dynamic> route) {
    final geometry = route['geometry'] as Map<String, dynamic>?;
    final coordinates = geometry?['coordinates'] as List<dynamic>?;
    if (coordinates == null || coordinates.isEmpty) return null;

    final points = coordinates.map((c) {
      final pair = c as List<dynamic>;
      return RoutePoint(
        longitude: (pair[0] as num).toDouble(),
        latitude: (pair[1] as num).toDouble(),
      );
    }).toList();

    final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0;
    final durationSeconds = (route['duration'] as num?)?.toDouble() ?? 0;

    return RouteInfo(
      points: points,
      distanceKm: distanceMeters / 1000,
      durationMin: durationSeconds / 60,
    );
  }
}
