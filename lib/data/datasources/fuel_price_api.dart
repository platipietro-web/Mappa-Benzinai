import 'package:dio/dio.dart';
import 'package:mappa_prezzi_benzina/core/errors/exceptions.dart';
import 'package:mappa_prezzi_benzina/core/utils/logger.dart';
import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/data/models/gas_station_model.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';

// ─── Nomi canonici carburanti ──────────────────────────────────────────────────
// Questi sono gli UNICI nomi usati in tutta l'app (parser, filtri, dettaglio).
// Modificare qui si propaga ovunque.
class FuelTypes {
  static const benzina = 'Benzina';
  static const benzinaSp100 = 'Benzina Speciale 100';
  static const benzinaServita = 'Benzina Servita';
  static const diesel = 'Diesel';
  static const dieselPlus = 'Diesel+';
  static const dieselServito = 'Diesel Servito';
  static const dieselHvo = 'Diesel HVO';
  static const hvo = 'HVO';
  static const gpl = 'GPL';
  static const metano = 'Metano';
  static const gnc = 'GNC';
  static const gnl = 'GNL';
  static const idrogeno = 'Idrogeno';

  static const all = [
    benzina,
    benzinaSp100,
    benzinaServita,
    diesel,
    dieselPlus,
    dieselServito,
    dieselHvo,
    hvo,
    gpl,
    metano,
    gnc,
    gnl,
    idrogeno,
  ];
}

abstract class FuelPriceApi {
  Future<List<GasStationModel>> getNearbyStations(
    UserLocation location,
    double radiusKm,
  );
}

class FuelPriceApiImpl implements FuelPriceApi {
  final Dio _dio;

  List<GasStationModel>? _cachedStations;
  DateTime? _lastCacheUpdate;

  FuelPriceApiImpl(this._dio) {
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
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

      logInfo('Found ${nearby.length} stations within ${radiusKm}km');

      if (nearby.isEmpty) {
        logInfo('No MIMIT stations found, falling back to OpenStreetMap');
        return _getOpenStreetMapStations(location, radiusKm);
      }

      return nearby;
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

    final parsedPrices = _parsePricesCsv(pricesCsv);
    final stations = _parseStationsCsv(stationsCsv, parsedPrices);

    _cachedStations = stations;
    _lastCacheUpdate = DateTime.now();
    logInfo('MIMIT data loaded: ${stations.length} stations with prices');
    return stations;
  }

  // ─── CSV Parsing ───────────────────────────────────────────────────────────

  _ParsedPrices _parsePricesCsv(String csv) {
    final records = _parseCsv(csv);
    final now = DateTime.now();

    // Prima passata: raccogli TUTTI i prezzi e la data più recente per stazione
    // Struttura: id -> fuelType -> lista di prezzi trovati
    final allPrices = <String, Map<String, List<double>>>{};
    // id -> data più recente di aggiornamento prezzo (dtComu)
    final latestDates = <String, DateTime>{};

    for (final r in records) {
      final id = r['idImpianto'] ?? r['idimpianto'] ?? '';
      final fuelRaw = r['descCarburante'] ?? r['Descrizione Carburante'] ?? '';
      final priceRaw = r['prezzo'] ?? r['Prezzo'] ?? '';

      if (id.isEmpty) continue;
      final fuelType = _normalizeFuelType(fuelRaw);
      if (fuelType == null) continue;
      final price = _parseDouble(priceRaw);
      // Range realistico per il mercato italiano (GPL ~0.65, carburanti premium ~3.0)
      if (price == null || price < 0.65 || price > 3.5) continue;

      // Salta prezzi non aggiornati da più di 60 giorni: indicano pompe inattive
      final dateRaw = r['dtComu'] ?? r['DtComu'] ?? r['dt_Comu'] ?? '';
      DateTime? priceDate;
      if (dateRaw.isNotEmpty) {
        priceDate = _parseDate(dateRaw);
        if (priceDate != null && now.difference(priceDate).inDays > 60) continue;
      }

      allPrices
          .putIfAbsent(id, () => {})
          .putIfAbsent(fuelType, () => [])
          .add(price);

      // Tieni traccia della data più recente per questa stazione
      if (priceDate != null) {
        final current = latestDates[id];
        if (current == null || priceDate.isAfter(current)) {
          latestDates[id] = priceDate;
        }
      }
    }

    // Seconda passata: per ogni stazione risolvi i duplicati
    final result = <String, Map<String, double>>{};

    for (final entry in allPrices.entries) {
      final id = entry.key;
      final fuelMap = entry.value;
      final stationPrices = <String, double>{};

      for (final fuelEntry in fuelMap.entries) {
        final fuelType = fuelEntry.key;
        final prices = fuelEntry.value..sort(); // ordina dal più basso

        // In presenza di più prezzi per lo stesso tipo canonico
        // (es. duplicati nel CSV) teniamo solo il minimo (self-service).
        stationPrices[fuelType] = prices.first;
      }

      if (stationPrices.isNotEmpty) {
        result[id] = stationPrices;
      }
    }

    return _ParsedPrices(result, latestDates);
  }

  List<GasStationModel> _parseStationsCsv(
    String csv,
    _ParsedPrices parsedPrices,
  ) {
    final pricesByStation = parsedPrices.prices;
    final datesByStation = parsedPrices.latestDates;
    final records = _parseCsv(csv);
    final stations = <GasStationModel>[];

    for (final r in records) {
      final id = r['idImpianto'] ?? r['idimpianto'] ?? '';
      if (id.isEmpty) continue;

      // Salta stazioni esplicitamente marcate come inattive
      final flagAttivo = _clean(r['flagAttivo'] ?? r['FlagAttivo'] ?? '');
      if (flagAttivo == '0') continue;

      final lat = _parseDouble(r['Latitudine']);
      final lon = _parseDouble(r['Longitudine']);
      if (lat == null || lon == null) continue;
      if (lat == 0.0 && lon == 0.0) continue;
      if (lat < 35.0 || lat > 48.0 || lon < 6.0 || lon > 19.0) continue;

      var prices = pricesByStation[id];
      if (prices == null || prices.isEmpty) continue;

      final brand = _clean(r['Bandiera']);

      // Pompe bianche are independent unbranded stations — they never sell
      // brand-formulated premium fuels (V-Power, Blue, Hi-Q, etc.).
      if (brand.toUpperCase() == 'POMPE BIANCHE') {
        prices = Map<String, double>.from(prices)
          ..remove(FuelTypes.benzinaSp100)
          ..remove(FuelTypes.benzinaServita)
          ..remove(FuelTypes.dieselPlus)
          ..remove(FuelTypes.dieselServito);
        if (prices.isEmpty) continue;
      }

      final nome = _clean(r['Nome Impianto'] ?? r['NomeImpianto'] ?? '');
      final gestore = _clean(r['Gestore'] ?? '');
      final tipo = _clean(r['Tipo Impianto'] ?? r['TipoImpianto'] ?? '');

      final displayName = nome.isNotEmpty
          ? nome
          : brand.isNotEmpty
              ? brand
              : gestore.isNotEmpty
                  ? gestore
                  : 'Distributore';

      final address = [
        _clean(r['Indirizzo'] ?? ''),
        _clean(r['Comune'] ?? ''),
        '(${_clean(r['Provincia'] ?? '')})',
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
        lastUpdated: datesByStation[id],
        openingHours: tipo.isNotEmpty ? tipo : null,
      ));
    }

    return stations;
  }

  // ─── Normalizzazione tipo carburante ───────────────────────────────────────
  //
  // REGOLA: un solo nome per categoria → corrisponde 1:1 con FuelTypes e filtri
  //
  // Benzina base    → "Benzina"
  // Tutto il resto con benzina (V-Power, 100 ottani, Supreme, Racing...)
  //                 → "Benzina Speciale 100"
  //
  // Diesel base     → "Diesel"
  // Diesel premium  → "Diesel+"
  // Diesel HVO      → "Diesel HVO"
  // HVO puro        → "HVO"
  //
  String? _normalizeFuelType(String raw) {
    final cleaned = _clean(raw);
    if (cleaned.isEmpty) return null;
    final n = cleaned.toLowerCase();

    // ── Benzina Speciale 100 — nomi brand-specifici nel CSV MIMIT ──────────
    if (_isBenzinaSp100(n)) return FuelTypes.benzinaSp100;

    // ── Benzina/Diesel Servita — prezzo pieno servizio (NON carburante premium)
    // Deve venire PRIMA dei check generici benzina/diesel per evitare
    // che "Benzina Servita" venga classificata come benzina normale.
    if (n.contains('servit')) {
      if (n.contains('benzina')) return FuelTypes.benzinaServita;
      if (n.contains('gasolio') || n.contains('diesel')) return FuelTypes.dieselServito;
      return null; // "servito" senza tipo carburante → ignora
    }

    // ── Benzina base ───────────────────────────────────────────────────────
    if (n.contains('benzina')) return FuelTypes.benzina;

    // ── Diesel HVO ─────────────────────────────────────────────────────────
    if ((n.contains('gasolio') || n.contains('diesel')) && n.contains('hvo')) {
      return FuelTypes.dieselHvo;
    }

    // ── Diesel+ — nomi brand-specifici nel CSV MIMIT ───────────────────────
    if (_isDieselPlus(n)) return FuelTypes.dieselPlus;

    // ── Diesel base ────────────────────────────────────────────────────────
    if (n.contains('gasolio') || n.contains('diesel')) return FuelTypes.diesel;

    // ── HVO puro ───────────────────────────────────────────────────────────
    if (n.contains('hvo')) return FuelTypes.hvo;

    // ── Gas ────────────────────────────────────────────────────────────────
    if (n.contains('gpl')) return FuelTypes.gpl;
    if (n.contains('gnc') || n.contains('l-gnc')) return FuelTypes.gnc;
    if (n.contains('gnl')) return FuelTypes.gnl;
    if (n.contains('metano')) return FuelTypes.metano;

    // ── Idrogeno ───────────────────────────────────────────────────────────
    if (n.contains('idrogeno') || n.contains('hydrogen') || n == 'h2') {
      return FuelTypes.idrogeno;
    }

    return null;
  }

  bool _isBenzinaSp100(String n) {
    // Nomi che contengono "benzina" + qualificatore speciale
    if (n.contains('benzina')) {
      return n.contains('100') ||
          n.contains('super') ||
          n.contains('premium') ||
          n.contains('special') ||
          n.contains('speciale') ||
          n.contains('plus') ||
          n.contains('racing') ||
          n.contains('optimo');
    }
    // Nomi brand-specifici che NON contengono "benzina" ma sono benzina speciale
    if (n.contains('blue super')) return true; // ENI
    if (n.contains('blu super')) return true; // ENI variante
    if (n.contains('hi-q perform')) return true; // Q8
    if (n.contains('hiq perform')) return true; // Q8 variante
    if (n.contains('hi-q 100')) return true; // Q8
    if (n.contains('hiq 100')) return true; // Q8 variante
    if (n.contains('v-power') &&
        !n.contains('diesel') &&
        !n.contains('gasolio')) { return true; } // Shell
    if (n.contains('vpower') && !n.contains('diesel') && !n.contains('gasolio')) {
      return true; // Shell variante
    }
    if (n.contains('supreme') &&
        !n.contains('diesel') &&
        !n.contains('gasolio')) { return true; } // Esso
    if (n.contains('excellium') &&
        (n.contains('benz') ||
            n.contains('100') ||
            (!n.contains('diesel') && !n.contains('gasolio')))) {
      return true; // Tamoil
    }
    if (n.contains('racing fuel')) return true;
    if (n.contains('optimo')) return true; // IP
    return false;
  }

  bool _isDieselPlus(String n) {
    if (n.contains('gasolio') || n.contains('diesel')) {
      return n.contains('special') ||
          n.contains('speciale') ||
          n.contains('premium') ||
          n.contains('plus') ||
          n.contains('+') ||
          n.contains('blu') || // Blue Diesel ENI
          n.contains('blue') ||
          n.contains('hi-q') || // Hi-Q Diesel Q8
          n.contains('hiq') ||
          n.contains('v-power') || // V-Power Diesel Shell
          n.contains('vpower') ||
          n.contains('supreme') || // Supreme Diesel Esso
          n.contains('excellium') || // Excellium Diesel Tamoil
          n.contains('extra') || // Extraverde IP
          n.contains('ultimate');
    }
    // Nomi che non contengono "gasolio"/"diesel" ma sono diesel speciale
    if (n.contains('extraverde')) return true; // IP
    if (n.contains('blue diesel')) return true;
    if (n.contains('blu diesel')) return true;
    return false;
  }

  // ─── CSV Utilities ─────────────────────────────────────────────────────────

  List<Map<String, String>> _parseCsv(String csv) {
    final lines = csv
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return const [];

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

  // Parsa formati data MIMIT: "dd/MM/yyyy HH:mm:ss", "M/d/yyyy h:mm:ss AM/PM", "yyyy-MM-dd"
  DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    final s = raw.trim();
    try {
      // ISO: yyyy-MM-dd o yyyy-MM-dd HH:mm:ss
      if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) {
        return DateTime.parse(s.substring(0, 10));
      }
      // dd/MM/yyyy [HH:mm:ss] o M/d/yyyy [h:mm:ss AM/PM]
      final parts = s.split(' ');
      final dateParts = parts[0].split('/');
      if (dateParts.length == 3) {
        final a = int.tryParse(dateParts[0]);
        final b = int.tryParse(dateParts[1]);
        final c = int.tryParse(dateParts[2]);
        if (a == null || b == null || c == null) return null;
        // Se il primo numero è 4 cifre → yyyy/MM/dd
        if (dateParts[0].length == 4) return DateTime(a, b, c);
        // Altrimenti dd/MM/yyyy
        return DateTime(c, b, a);
      }
    } catch (_) {}
    return null;
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
        .compareTo(b.getDistanceFromCoordinates(
            location.latitude, location.longitude)));

    logInfo('OSM fallback returned ${stations.length} stations');
    return stations;
  }

  double? _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

class _ParsedPrices {
  final Map<String, Map<String, double>> prices;
  final Map<String, DateTime> latestDates;
  const _ParsedPrices(this.prices, this.latestDates);
}
