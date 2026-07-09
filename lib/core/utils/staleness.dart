/// Oltre questa soglia i prezzi di un distributore sono considerati
/// "vecchi": potrebbero non essere più affidabili.
const Duration stalePriceThreshold = Duration(days: 2);

bool isPriceStale(DateTime? lastUpdated) {
  if (lastUpdated == null) return false;
  return DateTime.now().difference(lastUpdated) >= stalePriceThreshold;
}

String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes} min fa';
  if (diff.inHours < 24) return '${diff.inHours} ore fa';
  return '${diff.inDays} giorni fa';
}
