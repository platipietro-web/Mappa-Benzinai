class AppConstants {
  // ─── Cloudflare Worker (proxy MIMIT, risolve CORS su web) ────────────────
  static const String _workerBase =
      'https://mimit-proxy.piepla04.workers.dev';

  static const String mimitStationsUrl = '$_workerBase/stations';
  static const String mimitPricesUrl = '$_workerBase/prices';

  // ─── Servizi OpenStreetMap (Nominatim/Overpass) ────────────────────────────
  // Le policy di uso di Nominatim/Overpass richiedono un User-Agent che
  // identifichi l'app e un contatto — senza rischiamo il ban dell'IP/app.
  static const String osmUserAgent =
      'MappaBenzinai/1.0 (+plati.pietro@gmail.com)';

  // Tile raster CARTO (gratuite, nessuna API key, pensate per l'uso in app —
  // a differenza di tile.openstreetmap.org che vieta l'uso "bulk" da app
  // distribuite a molti utenti).
  static const String tileUrlTemplate =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
  static const List<String> tileSubdomains = ['a', 'b', 'c', 'd'];
  static const String tileAttribution =
      '© OpenStreetMap contributors © CARTO';

  // ─── Tipi carburante ───────────────────────────────────────────────────────
  static const List<String> fuelTypes = ['Benzina', 'Diesel', 'GPL', 'Metano'];
  static const Map<String, String> fuelTypeIcons = {
    'Benzina': '⛽',
    'Diesel': '🛢️',
    'GPL': '🔵',
    'Metano': '💨',
  };

  // ─── Mappa ─────────────────────────────────────────────────────────────────
  static const double defaultLatitude = 41.8719; // centro Italia
  static const double defaultLongitude = 12.5674;
  static const double defaultZoom = 6.0;
  static const double stationSearchRadius = 10.0; // km

  // ─── Firestore collections ─────────────────────────────────────────────────
  static const String stationsCollection = 'gas_stations';
  static const String priceUpdatesCollection = 'price_updates';
  static const String usersCollection = 'users';
  static const String favoritesCollection = 'favorites';
  static const String priceHistoryCollection = 'price_history';
  static const String refuelingLogsCollection = 'refueling_logs';
  static const String carWashesCollection = 'car_washes';
  static const String carWashFavoritesCollection = 'car_wash_favorites';
  static const String vehiclesCollection = 'vehicles';
  static const String vehicleCostEntriesCollection = 'cost_entries';
  static const String importCellsCollection = 'import_cells';

  // ─── Import autolavaggi da OSM ─────────────────────────────────────────────
  // Evita di richiamare Overpass per la stessa zona da più utenti/sessioni:
  // una volta importata una cella, resta "fresca" per questo periodo.
  static const Duration carWashImportCooldown = Duration(days: 30);

  // ─── Cache ─────────────────────────────────────────────────────────────────
  /// I CSV MIMIT vengono aggiornati una volta al giorno: cache di 6 ore.
  static const Duration cacheDuration = Duration(hours: 6);

  // ─── App ───────────────────────────────────────────────────────────────────
  static const String appName = 'Prezzi Benzina';
  static const String appVersion = '1.0.0';
}