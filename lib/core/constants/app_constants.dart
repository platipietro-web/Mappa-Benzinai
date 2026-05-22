class AppConstants {
  // ─── Cloudflare Worker (proxy MIMIT, risolve CORS su web) ────────────────
  static const String _workerBase =
      'https://mimit-proxy.piepla04.workers.dev';

  static const String mimitStationsUrl = '$_workerBase/stations';
  static const String mimitPricesUrl = '$_workerBase/prices';

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

  // ─── Cache ─────────────────────────────────────────────────────────────────
  /// I CSV MIMIT vengono aggiornati una volta al giorno: cache di 6 ore.
  static const Duration cacheDuration = Duration(hours: 6);

  // ─── App ───────────────────────────────────────────────────────────────────
  static const String appName = 'Prezzi Benzina';
  static const String appVersion = '1.0.0';
}