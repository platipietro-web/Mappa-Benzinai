import 'package:equatable/equatable.dart';
import 'package:mappa_prezzi_benzina/domain/entities/gas_station.dart';

class RouteStationSuggestion extends Equatable {
  final GasStation station;
  final double detourKm; // distanza (sola andata) dal percorso alla stazione
  final double distanceAlongRouteKm; // progresso dall'origine
  final double fuelPrice;
  final double effectivePrice; // prezzo tenendo conto della deviazione
  final double netSaving; // risparmio netto sul pieno vs media zona
  final bool isWorthIt;

  const RouteStationSuggestion({
    required this.station,
    required this.detourKm,
    required this.distanceAlongRouteKm,
    required this.fuelPrice,
    required this.effectivePrice,
    required this.netSaving,
    required this.isWorthIt,
  });

  @override
  List<Object?> get props => [
        station,
        detourKm,
        distanceAlongRouteKm,
        fuelPrice,
        effectivePrice,
        netSaving,
        isWorthIt,
      ];
}
