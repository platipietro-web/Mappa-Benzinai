import 'package:dio/dio.dart';
import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/features/carwash/carwash_model.dart';

/// Fetches car wash locations from the OpenStreetMap Overpass API
/// (amenity=car_wash) and converts them to CarWashModel objects.
/// Document IDs use the OSM element ID (osm_node_*, osm_way_*) so
/// repeated imports are idempotent.
class OsmCarWashImporter {
  final Dio _dio;

  static const _overpassUrl = 'https://overpass-api.de/api/interpreter';

  OsmCarWashImporter(this._dio);

  Future<List<CarWashModel>> fetchCarWashes(
    double lat,
    double lon,
    double radiusKm,
  ) async {
    final radiusM = (radiusKm * 1000).clamp(500, 50000).round();
    final query = '''
[out:json][timeout:30];
(
  node(around:$radiusM,$lat,$lon)["amenity"="car_wash"];
  way(around:$radiusM,$lat,$lon)["amenity"="car_wash"];
  relation(around:$radiusM,$lat,$lon)["amenity"="car_wash"];
);
out center tags;
''';

    final response = await _dio.post<Map<String, dynamic>>(
      _overpassUrl,
      data: query,
      options: Options(
        contentType: Headers.textPlainContentType,
        responseType: ResponseType.json,
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        headers: {'User-Agent': AppConstants.osmUserAgent},
      ),
    );

    final elements = response.data?['elements'] as List<dynamic>? ?? [];
    final List<CarWashModel> results = [];

    for (final el in elements) {
      if (el is! Map<String, dynamic>) continue;
      final tags = (el['tags'] as Map<String, dynamic>?) ?? {};
      final center = (el['center'] as Map<String, dynamic>?) ?? {};

      final elLat = _toDouble(el['lat'] ?? center['lat']);
      final elLon = _toDouble(el['lon'] ?? center['lon']);
      if (elLat == null || elLon == null) continue;

      final type = el['type'] as String? ?? 'node';
      final id = el['id'];

      results.add(CarWashModel(
        id: 'osm_${type}_$id',
        name: _parseName(tags),
        address: _parseAddress(tags),
        latitude: elLat,
        longitude: elLon,
        type: _parseType(tags),
        hasVacuum: _parseVacuum(tags),
        paymentType: _parsePayment(tags),
      ));
    }

    return results;
  }

  // ─── Tag helpers ───────────────────────────────────────────────────────────

  String _parseName(Map<String, dynamic> tags) {
    final name = _clean(tags['name']);
    final operator0 = _clean(tags['operator']);
    final brand = _clean(tags['brand']);
    for (final s in [name, operator0, brand]) {
      if (s.isNotEmpty) return s;
    }
    return 'Autolavaggio';
  }

  String _parseType(Map<String, dynamic> tags) {
    final selfServiceTag = _clean(tags['self_service']).toLowerCase();
    final automatedTag = _clean(tags['automated']).toLowerCase();
    final carWashVal = _clean(tags['car_wash']).toLowerCase();
    final carWashType = _clean(tags['car_wash:type']).toLowerCase();
    final carWashSelf = _clean(tags['car_wash:self_service']).toLowerCase();
    final carWashAuto = _clean(tags['car_wash:automated']).toLowerCase();

    final isAutomated = automatedTag == 'yes' ||
        carWashAuto == 'yes' ||
        carWashVal == 'automated' ||
        carWashType == 'automatic' ||
        carWashType == 'tunnel' ||
        carWashType == 'rollover' ||
        carWashType == 'gantry' ||
        carWashVal.contains('tunnel') ||
        carWashVal.contains('gantry');

    final isSelfService = selfServiceTag == 'yes' ||
        carWashSelf == 'yes' ||
        carWashVal == 'manual' ||
        carWashVal == 'hand' ||
        carWashType == 'self_service' ||
        carWashType == 'manual';

    if (isAutomated && isSelfService) return 'both';
    if (isAutomated) return 'automatic';
    if (isSelfService) return 'self-only';
    return 'unknown'; // OSM doesn't specify — don't assume
  }

  bool? _parseVacuum(Map<String, dynamic> tags) {
    if (tags.containsKey('vacuum_cleaner')) {
      return tags['vacuum_cleaner'] == 'yes' ||
          tags['vacuum_cleaner:fee'] == 'yes';
    }
    return null; // unspecified — don't assume
  }

  String _parsePayment(Map<String, dynamic> tags) {
    final hasCoins = tags['payment:coins'] == 'yes';
    final hasCard = tags['payment:credit_cards'] == 'yes' ||
        tags['payment:debit_cards'] == 'yes' ||
        tags['payment:visa'] == 'yes' ||
        tags['payment:mastercard'] == 'yes';
    final hasKnownPayment = tags.keys.any((k) => k.startsWith('payment:'));
    if (!hasKnownPayment) return 'unknown'; // unspecified — don't assume
    if (hasCoins && hasCard) return 'both';
    if (hasCard) return 'card';
    return 'coins';
  }

  String? _parseAddress(Map<String, dynamic> tags) {
    final street = _clean(tags['addr:street']);
    final number = _clean(tags['addr:housenumber']);
    final city = _clean(tags['addr:city']);
    if (street.isEmpty && city.isEmpty) return null;
    final line1 = [street, number].where((s) => s.isNotEmpty).join(' ');
    return [line1, city].where((s) => s.isNotEmpty).join(', ');
  }

  String _clean(dynamic v) => (v as String? ?? '').trim();

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
