import 'package:dio/dio.dart';
import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/core/services/service_error_logger.dart';

class GeocodingResult {
  final String name;
  final String subtitle;
  final double lat;
  final double lon;

  const GeocodingResult({
    required this.name,
    required this.subtitle,
    required this.lat,
    required this.lon,
  });
}

class GeocodingService {
  static final _dio = Dio()
    ..options.connectTimeout = const Duration(seconds: 10)
    ..options.receiveTimeout = const Duration(seconds: 10)
    ..options.headers = {'User-Agent': AppConstants.osmUserAgent};

  static Future<List<GeocodingResult>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    try {
      final response = await _dio.get<List<dynamic>>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': q,
          'format': 'json',
          'limit': '6',
          'addressdetails': '1',
          'accept-language': 'it',
          'countrycodes': 'it',
        },
      );
      final data = response.data;
      if (data == null) return const [];

      return data.whereType<Map<String, dynamic>>().map((r) {
        final addr = (r['address'] as Map<String, dynamic>?) ?? {};
        final rawName = r['name'] as String? ?? '';
        final city = (addr['city'] ??
            addr['town'] ??
            addr['village'] ??
            addr['municipality']) as String?;
        final county = addr['county'] as String?;
        final state = addr['state'] as String?;

        final name = rawName.isNotEmpty
            ? rawName
            : city ??
                (r['display_name'] as String? ?? q).split(',').first.trim();

        final subParts = <String>[];
        if (city != null && city != name) subParts.add(city);
        if (county != null && county != name) subParts.add(county);
        if (state != null && subParts.length < 2 && state != name) {
          subParts.add(state);
        }

        final lat = double.tryParse(r['lat']?.toString() ?? '') ?? 0;
        final lon = double.tryParse(r['lon']?.toString() ?? '') ?? 0;
        if (lat == 0 || lon == 0) return null;

        return GeocodingResult(
          name: name,
          subtitle: subParts.take(2).join(', '),
          lat: lat,
          lon: lon,
        );
      }).whereType<GeocodingResult>().toList();
    } on DioException catch (e) {
      ServiceErrorLogger.log('nominatim',
          detail: e.response?.statusCode?.toString() ?? e.type.name);
      return const [];
    } catch (_) {
      return const [];
    }
  }
}
