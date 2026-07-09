/// Confronto del prezzo di una stazione rispetto alla media della zona
/// attualmente visibile (mappa o preferiti), usato per colorare i pin.
enum PriceLevel { cheap, average, expensive }

/// Tolleranza attorno alla media entro cui il prezzo è considerato "in
/// linea" (né conveniente né caro) — evita che differenze di pochi
/// millesimi di euro facciano scattare un colore diverso.
const double priceLevelTolerance = 0.015;

/// Classifica [price] rispetto a [areaAverage]. Ritorna null se uno dei due
/// valori non è utilizzabile (nessun prezzo per quel carburante, media non
/// calcolabile).
PriceLevel? classifyPriceLevel(double? price, double? areaAverage) {
  if (price == null ||
      !price.isFinite ||
      areaAverage == null ||
      areaAverage <= 0) {
    return null;
  }
  final diff = (price - areaAverage) / areaAverage;
  if (diff < -priceLevelTolerance) return PriceLevel.cheap;
  if (diff > priceLevelTolerance) return PriceLevel.expensive;
  return PriceLevel.average;
}

/// Media dei prezzi validi (finiti) di un gruppo di stazioni. Ritorna null
/// se nessuna stazione ha un prezzo utilizzabile.
double? averageOfFinite(Iterable<double> prices) {
  final finite = prices.where((p) => p.isFinite).toList();
  if (finite.isEmpty) return null;
  return finite.reduce((a, b) => a + b) / finite.length;
}
