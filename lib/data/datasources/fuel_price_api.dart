import 'package:dio/dio.dart';
import 'package:mappa_prezzi_benzina/core/errors/exceptions.dart';
import 'package:mappa_prezzi_benzina/core/utils/logger.dart';
import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/data/models/gas_station_model.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';

abstract class FuelPriceApi {
  Future<List<GasStationModel>> getNearbyStations(
    UserLocation location,
    double radiusKm,
  );
}

class FuelPriceApiImpl implements FuelPriceApi {
  final Dio _dio;

  // Cache in-memory: i CSV MIMIT pesano ~10 MB, scaricati una volta sola
  List<GasStationModel>? _cachedStations;
  DateTime? _lastCacheUpdate;

  FuelPriceApiImpl(this._dio) {
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
    _dio.options.headers = {
      'Accept': 'text/csv,*/*',
      'User-Agent': 'MappaPrezziBenzina/1.0',
    };
  }

  // ─── Public ────────────────────────────────────────────────────────────────

  @override
  Future<List<GasStationModel>> getNearbyStations(
    UserLocation location,
    double radiusKm,
  ) async {
    try {
      final stations = await _loadAllStations();
      final nearby = stations
          .where((s) =>
              s.getDistanceFromCoordinates(
                location.latitude,
                location.longitude,
              ) <=
              radiusKm)
          .toList()
        ..sort((a, b) => a
            .getDistanceFromCoordinates(location.latitude, location.longitude)
            .compareTo(b.getDistanceFromCoordinates(
                location.latitude, location.longitude)));

      logInfo(
          'Found ${nearby.length} stations within ${radiusKm}km of '
          '${location.latitude},${location.longitude}');

      // Fallback OpenStreetMap se MIMIT non ha stazioni nella zona
      if (nearby.isEmpty) {
        logInfo('No MIMIT stations found, falling back to OpenStreetMap');
        return _getOpenStreetMapStations(location, radiusKm);
      }

      return nearby.take(100).toList();
    } on DioException catch (e) {
      logError('Network error fetching MIMIT data, fallback OSM', e);
      return _getOpenStreetMapStations(location, radiusKm);
    } catch (e) {
      logError('Unexpected error fetching stations', e);
      return _getOpenStreetMapStations(location, radiusKm);
    }
  }

  // ─── CSV Loading ───────────────────────────────────────────────────────────

  Future<List<GasStationModel>> _loadAllStations() async {
    final cacheUpdate = _lastCacheUpdate;
    if (_cachedStations != null &&
        cacheUpdate != null &&
        DateTime.now().difference(cacheUpdate) < AppConstants.cacheDuration) {
      logInfo('Using cached MIMIT data (${_cachedStations!.length} stations)');
      return _cachedStations!;
    }

    logInfo('Downloading MIMIT CSV files...');

    final responses = await Future.wait([
      _dio.get<String>(
        AppConstants.mimitStationsUrl,
        options: Options(responseType: ResponseType.plain),
      ),
      _dio.get<String>(
        AppConstants.mimitPricesUrl,
        options: Options(responseType: ResponseType.plain),
      ),
    ]);

    final stationsCsv = responses[0].data;
    final pricesCsv = responses[1].data;

    if (stationsCsv == null || stationsCsv.isEmpty) {
      throw ApiException(message: 'MIMIT anagrafica CSV vuoto');
    }
    if (pricesCsv == null || pricesCsv.isEmpty) {
      throw ApiException(message: 'MIMIT prezzi CSV vuoto');
    }

    final pricesByStation = _parsePricesCsv(pricesCsv);
    final stations = _parseStationsCsv(stationsCsv, pricesByStation);

    _cachedStations = stations;
    _lastCacheUpdate = DateTime.now();
    logInfo('MIMIT data loaded: ${stations.length} stations with prices');
    return stations;
  }

  // ─── CSV Parsing ───────────────────────────────────────────────────────────

  /// Ritorna mappa: idImpianto -> { 'Benzina': 1.799, 'Diesel': 1.699, ... }
  Map<String, Map<String, double>> _parsePricesCsv(String csv) {
    final records = _parseCsv(csv);
    final result = <String, Map<String, double>>{};

    for (final r in records) {
      final id = r['idImpianto'] ?? r['idimpianto'] ?? '';
      final fuelRaw = r['descCarburante'] ?? r['Descrizione Carburante'] ?? '';
      final priceRaw = r['prezzo'] ?? r['Prezzo'] ?? '';
      final isSelfRaw = (_clean(r['isSelf'])).toLowerCase();

      if (id.isEmpty) continue;
      final fuelType = _normalizeFuelType(fuelRaw);
      if (fuelType == null) continue;
      final price = _parseDouble(priceRaw);
      if (price == null || price <= 0.5 || price > 5.0) continue;

      final stationPrices = result.putIfAbsent(id, () => {});
      final existing = stationPrices[fuelType];

      // Preferisci il prezzo self-service; se uguale, prendi il minore
      final isSelf = isSelfRaw == '1' || isSelfRaw == 'true';
      final existingIsSelf =
          existing != null && stationPrices['${fuelType}_isSelf'] == 1.0;

      if (existing == null ||
          (isSelf && !existingIsSelf) ||
          (isSelf == existingIsSelf && price < existing)) {
        stationPrices[fuelType] = price;
        stationPrices['${fuelType}_isSelf'] = isSelf ? 1.0 : 0.0;
      }
    }

    // Rimuovi le chiavi _isSelf dai prezzi finali (erano solo helper)
    for (final prices in result.values) {
      prices.removeWhere((key, _) => key.endsWith('_isSelf'));
    }

    return result;
  }

  List<GasStationModel> _parseStationsCsv(
    String csv,
    Map<String, Map<String, double>> pricesByStation,
  ) {
    final records = _parseCsv(csv);
    final stations = <GasStationModel>[];

    for (final r in records) {
      final id = r['idImpianto'] ?? r['idimpianto'] ?? '';
      if (id.isEmpty) continue;

      final lat = _parseDouble(r['Latitudine']);
      final lon = _parseDouble(r['Longitudine']);
      if (lat == null || lon == null) continue;
      // Coordinate di default o nulle → salta
      if (lat == 0.0 && lon == 0.0) continue;
      // Bounding box Italia
      if (lat < 35.0 || lat > 48.0 || lon < 6.0 || lon > 19.0) continue;

      final prices = pricesByStation[id];
      // Includi solo stazioni che hanno almeno un prezzo
      if (prices == null || prices.isEmpty) continue;

      final brand = _clean(r['Bandiera']);
      final nome = _clean(r['Nome Impianto'] ?? r['NomeImpianto']);
      final gestore = _clean(r['Gestore']);
      final tipo = _clean(r['Tipo Impianto'] ?? r['TipoImpianto']);

      final displayName = nome.isNotEmpty
          ? nome
          : brand.isNotEmpty
              ? brand
              : gestore.isNotEmpty
                  ? gestore
                  : 'Distributore';

      final address = [
        _clean(r['Indirizzo']),
        _clean(r['Comune']),
        '(${_clean(r['Provincia'])})',
      ].where((p) => p.isNotEmpty && p != '()').join(' ');

      stations.add(GasStationModel(
        id: id,
        name: brand.isNotEmpty && !displayName.contains(brand)
            ? '$displayName ($brand)'
            : displayName,
        address: address.isNotEmpty ? address : 'Indirizzo non disponibile',
        latitude: lat,
        longitude: lon,
        prices: prices,
        brand: brand.isNotEmpty ? brand : null,
        lastUpdated: DateTime.now(),
        // tipo impianto: stradale, autostradale, etc.
        openingHours: tipo.isNotEmpty ? tipo : null,
      ));
    }

    return stations;
  }

  // ─── CSV Utilities ─────────────────────────────────────────────────────────

  List<Map<String, String>> _parseCsv(String csv) {
    final lines = csv
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return const [];

    // Cerca header: deve contenere 'idImpianto' e un separatore
    final headerIdx = lines.indexWhere((l) =>
        l.toLowerCase().contains('idimpianto') &&
        (l.contains('|') || l.contains(';')));

    if (headerIdx == -1) return const [];

    final sep = lines[headerIdx].contains('|') ? '|' : ';';
    final headers = _splitLine(lines[headerIdx], sep);
    final records = <Map<String, String>>[];

    for (final line in lines.skip(headerIdx + 1)) {
      final values = _splitLine(line, sep);
      if (values.length < headers.length) continue;
      final record = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        record[headers[i]] = values[i];
      }
      records.add(record);
    }

    return records;
  }

  List<String> _splitLine(String line, String sep) {
    final result = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == sep && !inQuotes) {
        result.add(_clean(buf.toString()));
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    result.add(_clean(buf.toString()));
    return result;
  }

  String _clean(String? v) {
    final s = (v ?? '').trim().replaceAll(RegExp(r'^"|"$'), '').trim();
    return s.toUpperCase() == 'NULL' ? '' : s;
  }

  double? _parseDouble(String? v) {
    if (v == null) return null;
    return double.tryParse(_clean(v).replaceAll(',', '.'));
  }

  String? _normalizeFuelType(String raw) {
    final cleaned = _clean(raw);
    if (cleaned.isEmpty) return null;
    final n = cleaned.toLowerCase();

    // Benzina — mantieni distinzione 95/100/super/speciale
    if (n.contains('benzina')) {
      if (n.contains('100') || n.contains('v-power') || n.contains('ultimate') ||
          n.contains('excellium') || n.contains('racing')) return 'Benzina 100';
      if (n.contains('super') || n.contains('premium')) return 'Benzina Super';
      if (n.contains('special') || n.contains('speciale')) return 'Benzina Speciale';
      return 'Benzina';
    }

    // Diesel — mantieni distinzione plus/HVO/speciale
    if (n.contains('gasolio') || n.contains('diesel')) {
      if (n.contains('hvo')) return 'Diesel HVO';
      if (n.contains('plus') || n.contains('+') || n.contains('premium') ||
          n.contains('excellium') || n.contains('v-power') ||
          n.contains('ultimate') || n.contains('blu')) return 'Diesel+';
      if (n.contains('special') || n.contains('speciale')) return 'Diesel Speciale';
      return 'Diesel';
    }

    // HVO puro (senza gasolio nel nome)
    if (n.contains('hvo')) return 'HVO';

    // Gas
    if (n.contains('gpl')) return 'GPL';
    if (n.contains('gnc') || n.contains('l-gnc')) return 'GNC';
    if (n.contains('gnl')) return 'GNL';
    if (n.contains('metano')) return 'Metano';

    // Idrogeno
    if (n.contains('idrogeno') || n.contains('hydrogen') || n.contains('h2')) {
      return 'Idrogeno';
    }

    // Altri carburanti speciali: mantieni nome originale capitalizzato
    return cleaned
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  // ─── OpenStreetMap Fallback ────────────────────────────────────────────────

  Future<List<GasStationModel>> _getOpenStreetMapStations(
    UserLocation location,
    double radiusKm,
  ) async {
    final radiusM = (radiusKm * 1000).clamp(1000, 10000).round();
    final query = '''
[out:json][timeout:20];
(
  node(around:$radiusM,${location.latitude},${location.longitude})["amenity"="fuel"];
  way(around:$radiusM,${location.latitude},${location.longitude})["amenity"="fuel"];
  relation(around:$radiusM,${location.latitude},${location.longitude})["amenity"="fuel"];
);
out center tags 100;
''';

    logInfo('OSM fallback: querying within ${radiusKm}km');

    final response = await _dio.post<Map<String, dynamic>>(
      'https://overpass-api.de/api/interpreter',
      data: query,
      options: Options(
        contentType: Headers.textPlainContentType,
        responseType: ResponseType.json,
      ),
    );

    final elements = response.data?['elements'] as List<dynamic>? ?? [];
    final stations = <GasStationModel>[];

    for (final el in elements) {
      if (el is! Map<String, dynamic>) continue;
      final tags = (el['tags'] as Map<String, dynamic>?) ?? {};
      final center = (el['center'] as Map<String, dynamic>?) ?? {};

      final lat = _asDouble(el['lat'] ?? center['lat']);
      final lon = _asDouble(el['lon'] ?? center['lon']);
      if (lat == null || lon == null) continue;

      final brand = _clean(tags['brand']?.toString());
      final name = _clean(tags['name']?.toString());
      final operator0 = _clean(tags['operator']?.toString());
      final displayName = [name, brand, operator0, 'Distributore']
          .firstWhere((s) => s.isNotEmpty);

      final address = [
        tags['addr:street'],
        tags['addr:housenumber'],
        tags['addr:city'],
      ].whereType<String>().map(_clean).where((s) => s.isNotEmpty).join(' ');

      stations.add(GasStationModel(
        id: 'osm-${el['type']}-${el['id']}',
        name: brand.isNotEmpty && !displayName.contains(brand)
            ? '$displayName ($brand)'
            : displayName,
        address: address.isNotEmpty ? address : 'Indirizzo non disponibile',
        latitude: lat,
        longitude: lon,
        brand: brand.isNotEmpty ? brand : null,
        openingHours: _clean(tags['opening_hours']?.toString()).isNotEmpty
            ? _clean(tags['opening_hours']?.toString())
            : null,
        prices: const {},
        lastUpdated: DateTime.now(),
      ));
    }

    stations.sort((a, b) => a
        .getDistanceFromCoordinates(location.latitude, location.longitude)
        .compareTo(
            b.getDistanceFromCoordinates(location.latitude, location.longitude)));

    logInfo('OSM fallback returned ${stations.length} stations');
    return stations;
  }

  double? _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}