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

  // ─── Percorso (routing OSRM) ────────────────────────────────────────────────
  // Server demo pubblico OSRM: gratuito, senza API key, stesso approccio
  // "free OSM ecosystem" già usato per Nominatim/CARTO. È un servizio
  // "fair use" della community, senza SLA — adeguato ai volumi di quest'app.
  static const String osrmBaseUrl = 'https://router.project-osrm.org';
  // Larghezza del corridoio attorno al percorso entro cui un distributore
  // è considerato "sulla via".
  static const double routeCorridorKm = 3.0;
  // Distanza minima tra i centri delle query getNearbyStations lungo il
  // percorso (adattata al rialzo per tratte lunghe, vedi RoutePlannerBloc).
  static const double routeSampleIntervalKm = 15.0;
  // Raggio di fetch per ogni centro campionato: abbastanza largo da coprire
  // senza buchi la fascia tra due centri consecutivi + il corridoio.
  static const double routeSearchFetchRadiusKm = 10.0;
  static const int routeMaxSuggestions = 30;
  // Limite di alternative stradali mostrate, anche se OSRM ne restituisse
  // di più.
  static const int routeMaxAlternatives = 3;

  // ─── Brand distributori ─────────────────────────────────────────────────────
  // Lista condivisa tra FilterBottomSheet (mappa) e il filtro brand della
  // sezione Percorso.
  static const List<String> gasStationBrands = [
    'Agip', 'Eni', 'IP', 'Esso', 'Shell', 'Q8',
    'Tamoil', 'Total', 'TotalEnergies', 'Cepsa',
    'Lukoil', 'Pam', 'Conad', 'Retitalia',
    'Distributore', 'Pompe Bianche',
  ];

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