import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mappa_prezzi_benzina/core/services/real_cost_calculator.dart';
import 'package:mappa_prezzi_benzina/core/services/service_locator.dart';
import 'package:mappa_prezzi_benzina/domain/entities/gas_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/price_update.dart';
import 'package:mappa_prezzi_benzina/domain/entities/refueling_log.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';
import 'package:mappa_prezzi_benzina/domain/repositories/repositories.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/auth_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/dashboard_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/favorites_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/location_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/map_bloc.dart'
    show MapBloc, MapLoaded, MapLoading, UpdateStationPricesEvent;
import 'package:mappa_prezzi_benzina/presentation/bloc/price_prediction_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/user_profile_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';
import 'package:mappa_prezzi_benzina/presentation/widgets/price_trend_widget.dart';
import 'package:mappa_prezzi_benzina/presentation/widgets/real_cost_widget.dart';
import 'package:uuid/uuid.dart';

// Mappa colori e icone per tipo carburante
const _fuelMeta = {
  'Benzina':              {'color': 0xFF4CAF50, 'icon': Icons.local_gas_station},
  'Benzina Speciale 100': {'color': 0xFF388E3C, 'icon': Icons.local_gas_station},
  'Benzina Servita':      {'color': 0xFF8BC34A, 'icon': Icons.local_gas_station},
  'Diesel':               {'color': 0xFF2196F3, 'icon': Icons.local_gas_station},
  'Diesel+':              {'color': 0xFF1976D2, 'icon': Icons.local_gas_station},
  'Diesel Servito':       {'color': 0xFF42A5F5, 'icon': Icons.local_gas_station},
  'Diesel HVO':           {'color': 0xFF0D47A1, 'icon': Icons.eco},
  'HVO':                  {'color': 0xFF1B5E20, 'icon': Icons.eco},
  'GPL':                  {'color': 0xFFFF9800, 'icon': Icons.bubble_chart},
  'Metano':               {'color': 0xFF9C27B0, 'icon': Icons.air},
  'GNC':                  {'color': 0xFF7B1FA2, 'icon': Icons.air},
  'GNL':                  {'color': 0xFF4A148C, 'icon': Icons.air},
  'Idrogeno':             {'color': 0xFF00BCD4, 'icon': Icons.bolt},
};

Color _fuelColor(String fuelType) {
  for (final key in _fuelMeta.keys) {
    if (fuelType.toLowerCase().contains(key.toLowerCase())) {
      return Color(_fuelMeta[key]!['color'] as int);
    }
  }
  return const Color(0xFF607D8B);
}

IconData _fuelIcon(String fuelType) {
  for (final key in _fuelMeta.keys) {
    if (fuelType.toLowerCase().contains(key.toLowerCase())) {
      return _fuelMeta[key]!['icon'] as IconData;
    }
  }
  return Icons.local_gas_station;
}

// Ordine di visualizzazione preferito
const _fuelOrder = [
  'Benzina', 'Benzina Speciale 100', 'Benzina Servita',
  'Diesel', 'Diesel+', 'Diesel Servito', 'Diesel HVO', 'HVO',
  'GPL', 'Metano', 'GNC', 'GNL', 'Idrogeno',
];

List<MapEntry<String, double>> _sortedPrices(Map<String, double> prices) {
  final entries = prices.entries.toList();
  entries.sort((a, b) {
    final ia = _fuelOrder.indexWhere(
        (k) => a.key.toLowerCase().contains(k.toLowerCase()));
    final ib = _fuelOrder.indexWhere(
        (k) => b.key.toLowerCase().contains(k.toLowerCase()));
    final ra = ia == -1 ? 999 : ia;
    final rb = ib == -1 ? 999 : ib;
    return ra.compareTo(rb);
  });
  return entries;
}

class StationDetailPage extends StatefulWidget {
  final GasStation? station;
  final UserLocation? userLocation;

  const StationDetailPage({
    Key? key,
    required this.station,
    this.userLocation,
  }) : super(key: key);

  @override
  State<StationDetailPage> createState() => _StationDetailPageState();
}

class _StationDetailPageState extends State<StationDetailPage> {
  late Future<GasStation?> _stationDetailsFuture;
  late final PricePredictionBloc _predictionBloc;

  @override
  void initState() {
    super.initState();
    _predictionBloc = PricePredictionBloc(getIt<AnalyticsRepository>());

    final station = widget.station;
    if (station != null &&
        station.prices.isEmpty &&
        !station.id.startsWith('osm-')) {
      _stationDetailsFuture = getIt<GasStationRepository>()
          .getStationDetails(station.id)
          .then((details) {
            final s = details ?? station;
            _dispatchPrediction(s);
            return s;
          })
          .catchError((_) {
            _dispatchPrediction(station);
            return station;
          });
    } else {
      _stationDetailsFuture = Future.value(station);
      if (station != null && station.prices.isNotEmpty) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _dispatchPrediction(station));
      }
    }
  }

  void _dispatchPrediction(GasStation? station) {
    if (station == null ||
        station.prices.isEmpty ||
        station.id.startsWith('osm-')) {
      return;
    }
    final profile =
        getIt<UserProfileBloc>().state.profileOrDefault(station.id);
    final fuelType = profile.preferredFuelType;
    final price =
        station.prices[fuelType] ?? station.prices.values.first;
    _predictionBloc.add(LoadPredictionEvent(
      stationId: station.id,
      fuelType: fuelType,
      currentPrice: price,
    ));
  }

  @override
  void dispose() {
    _predictionBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final authenticated = authState is Authenticated ? authState : null;
    final favState = context.watch<FavoritesBloc>().state;
    final isLoggedIn = authenticated != null && !authenticated.isAnonymous;
    final stationId = widget.station?.id ?? '';
    final isFav = favState.isFavorite(stationId);

    return BlocProvider.value(
      value: _predictionBloc,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Dettaglio distributore',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          actions: [
            if (isLoggedIn && stationId.isNotEmpty)
              IconButton(
                icon: Icon(
                  isFav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFav ? Colors.red : null,
                ),
                tooltip:
                    isFav ? 'Rimuovi dai preferiti' : 'Aggiungi ai preferiti',
                onPressed: () {
                  final station = widget.station;
                  if (station == null) return;
                  if (isFav) {
                    context.read<FavoritesBloc>().add(RemoveFavoriteEvent(
                          userId: authenticated.userId,
                          stationId: station.id,
                        ));
                  } else {
                    context.read<FavoritesBloc>().add(AddFavoriteEvent(
                          userId: authenticated.userId,
                          station: station,
                        ));
                  }
                },
              ),
          ],
        ),
        floatingActionButton: isLoggedIn
            ? FutureBuilder<GasStation?>(
                future: _stationDetailsFuture,
                builder: (context, snap) {
                  final s = snap.data ?? widget.station;
                  if (s == null || s.prices.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return FloatingActionButton.extended(
                    onPressed: () => _showRefuelingSheet(context, s),
                    icon: const Icon(Icons.local_gas_station_rounded),
                    label: Text('Rifornimento',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                  );
                },
              )
            : null,
        body: FutureBuilder<GasStation?>(
          future: _stationDetailsFuture,
          builder: (context, snapshot) {
            final station = snapshot.data ?? widget.station;

            if (station == null) {
              return const Center(
                  child: Text('Distributore non disponibile'));
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                station.prices.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(station),
                  _prices(context, station),
                  _details(station,
                    context.read<LocationBloc>().state is LocationLoaded
                      ? (context.read<LocationBloc>().state as LocationLoaded).location
                      : widget.userLocation,
                  ),
                  _contacts(station),
                  const SizedBox(height: 96),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Log rifornimento ──────────────────────────────────────────────────────

  void _showRefuelingSheet(BuildContext context, GasStation station) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    final profile =
        context.read<UserProfileBloc>().state.profileOrDefault(authState.userId);
    String selectedFuel =
        station.prices.containsKey(profile.preferredFuelType)
            ? profile.preferredFuelType
            : station.prices.keys.first;
    final litersCtrl =
        TextEditingController(text: profile.tankSize.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final price = station.prices[selectedFuel] ?? 0;
            final liters =
                double.tryParse(litersCtrl.text.replaceAll(',', '.')) ?? 0;
            final total = price * liters;

            // Prezzo medio zona per carburante selezionato
            final mapState = context.read<MapBloc>().state;
            final nearbyStations = mapState is MapLoaded
                ? mapState.stations
                : mapState is MapLoading
                    ? mapState.stations
                    : <GasStation>[];
            final nearbyPrices = nearbyStations
                .where((s) =>
                    s.id != station.id && s.prices.containsKey(selectedFuel))
                .map((s) => s.prices[selectedFuel]!)
                .toList();
            final areaAvg = nearbyPrices.isNotEmpty
                ? RealCostCalculator.areaAverage(nearbyPrices)
                : price;
            final saved = (areaAvg - price) * liters;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 20, 24,
                  MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registra rifornimento',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  Text(
                    station.name,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Carburante',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppTheme.textSecondaryColor)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedFuel,
                    decoration: _sheetInputDecoration(),
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppTheme.textPrimaryColor),
                    items: station.prices.keys
                        .map((k) =>
                            DropdownMenuItem(value: k, child: Text(k)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSheet(() => selectedFuel = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Litri riforniti',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppTheme.textSecondaryColor)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: litersCtrl,
                    decoration:
                        _sheetInputDecoration(hint: 'es. 40'),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    style: GoogleFonts.poppins(fontSize: 13),
                    onChanged: (_) => setSheet(() {}),
                  ),
                  const SizedBox(height: 16),
                  if (price > 0) ...[
                    _sheetRow('Prezzo al litro',
                        '€ ${price.toStringAsFixed(3)}'),
                    const SizedBox(height: 4),
                    _sheetRow('Totale stimato',
                        '€ ${total.toStringAsFixed(2)}',
                        bold: true),
                    if (areaAvg > 0 && saved.abs() > 0.01) ...[
                      const SizedBox(height: 4),
                      _sheetRow(
                        saved >= 0
                            ? 'Risparmio vs zona'
                            : 'Extra vs zona',
                        saved >= 0
                            ? '+ € ${saved.toStringAsFixed(2)}'
                            : '- € ${saved.abs().toStringAsFixed(2)}',
                        color: saved >= 0
                            ? const Color(0xFF4CAF50)
                            : Colors.orange[700]!,
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: liters > 0 && price > 0
                          ? () {
                              final log = RefuelingLog(
                                id: const Uuid().v4(),
                                userId: authState.userId,
                                stationId: station.id,
                                stationName: station.name,
                                fuelType: selectedFuel,
                                pricePerLiter: price,
                                liters: liters,
                                totalCost: total,
                                savedVsArea: saved,
                                areaAvgPrice: areaAvg,
                                timestamp: DateTime.now(),
                              );
                              context
                                  .read<DashboardBloc>()
                                  .add(LogRefuelingEvent(log));
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Rifornimento registrato — €${total.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          : null,
                      child: Text(
                        'Salva rifornimento',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Segnalazione prezzo ──────────────────────────────────────────────────

  void _showPriceReportSheet(
      BuildContext context, GasStation station, String userId) {
    final sorted = _sortedPrices(station.prices);
    String selectedFuel = sorted.first.key;
    final priceCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final currentPrice = station.prices[selectedFuel]!;
          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Segnala prezzo aggiornato',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Accettato solo entro ±€0.20 dal prezzo attuale.',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppTheme.textSecondaryColor),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedFuel,
                  decoration:
                      const InputDecoration(labelText: 'Tipo carburante'),
                  items: sorted
                      .map((e) => DropdownMenuItem(
                          value: e.key, child: Text(e.key)))
                      .toList(),
                  onChanged: (v) =>
                      setSheetState(() => selectedFuel = v ?? selectedFuel),
                ),
                const SizedBox(height: 8),
                Text(
                  'Prezzo attuale: €${currentPrice.toStringAsFixed(3)}',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppTheme.textSecondaryColor),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Nuovo prezzo (€/L)',
                    hintText: 'Es. 1.899',
                    prefixText: '€ ',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final raw = priceCtrl.text
                          .trim()
                          .replaceAll(',', '.');
                      final newPrice = double.tryParse(raw);
                      if (newPrice == null || newPrice <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Inserisci un prezzo valido')),
                        );
                        return;
                      }
                      if ((newPrice - currentPrice).abs() > 0.20) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Il prezzo deve essere entro ±€0.20 dal valore attuale '
                              '(€${currentPrice.toStringAsFixed(3)})',
                            ),
                            backgroundColor: AppTheme.errorColor,
                          ),
                        );
                        return;
                      }
                      final update = PriceUpdate(
                        id: const Uuid().v4(),
                        stationId: station.id,
                        userId: userId,
                        fuelType: selectedFuel,
                        price: newPrice,
                        timestamp: DateTime.now(),
                      );
                      getIt<GasStationRepository>()
                          .submitPriceUpdate(update)
                          .then((_) {
                        if (context.mounted) {
                          context.read<MapBloc>().add(
                                UpdateStationPricesEvent(
                                  stationId: station.id,
                                  fuelType: selectedFuel,
                                  price: newPrice,
                                ),
                              );
                        }
                      });
                      Navigator.pop(sheetCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Segnalazione inviata, grazie!'),
                          backgroundColor: AppTheme.secondaryColor,
                        ),
                      );
                    },
                    child: const Text('Invia segnalazione'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _sheetInputDecoration({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
            fontSize: 13, color: AppTheme.borderColor),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: AppTheme.backgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
      );

  Widget _sheetRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 13, color: AppTheme.textSecondaryColor)),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? AppTheme.textPrimaryColor,
          ),
        ),
      ],
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _header(GasStation station) {
    return Container(
      color: AppTheme.backgroundColor,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            station.name,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 10),
          if (station.brand != null && station.brand!.isNotEmpty) ...[
            _badge(station.brand!, AppTheme.primaryColor),
            const SizedBox(height: 8),
          ] else if (station.id.startsWith('osm-')) ...[
            _badge('OpenStreetMap', Colors.orange),
            const SizedBox(height: 8),
          ],
          _inlineInfo(Icons.location_on, station.address),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ─── Prezzi ────────────────────────────────────────────────────────────────

  Widget _prices(BuildContext context, GasStation station) {
    final profile =
        context.read<UserProfileBloc>().state.profileOrDefault(station.id);

    // Usa il GPS reale se disponibile, altrimenti il centro mappa passato dal widget
    final locState = context.read<LocationBloc>().state;
    final userLoc = locState is LocationLoaded ? locState.location : widget.userLocation;

    // Prezzo medio zona per il carburante preferito
    final mapState = context.read<MapBloc>().state;
    final nearbyStations = mapState is MapLoaded
        ? mapState.stations
        : mapState is MapLoading
            ? mapState.stations
            : <GasStation>[];
    final fuelType = profile.preferredFuelType;
    final areaAvgPrice = RealCostCalculator.areaAverage(nearbyStations
        .where((s) => s.id != station.id && s.prices.containsKey(fuelType))
        .map((s) => s.prices[fuelType]!));

    final fuelPrice = station.prices[fuelType];
    final distanceKm = userLoc != null
        ? station.getDistanceFromCoordinates(
            userLoc.latitude, userLoc.longitude)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Prezzi carburante'),
          const SizedBox(height: 16),
          if (station.prices.isEmpty)
            _noPricesBox(station)
          else ...[
            ..._sortedPrices(station.prices)
                .map((entry) => _priceRow(entry.key, entry.value)),
          ],
          if (station.lastUpdated != null) ...[
            const SizedBox(height: 12),
            Text(
              'Aggiornato: ${_formatTime(station.lastUpdated!)}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],

          // Costo reale personalizzato
          if (fuelPrice != null &&
              profile.fuelConsumption > 0 &&
              distanceKm > 0 &&
              areaAvgPrice > 0)
            RealCostWidget(
              distanceKm: distanceKm,
              fuelPrice: fuelPrice,
              areaAvgPrice: areaAvgPrice,
              profile: profile,
              fuelType: fuelType,
            ),

          // Trend previsione prezzi
          if (!station.id.startsWith('osm-') && station.prices.isNotEmpty)
            const PriceTrendWidget(),

          // Segnala prezzo (solo utenti registrati, solo se ci sono prezzi noti)
          if (station.prices.isNotEmpty &&
              !station.id.startsWith('osm-')) ...[
            const SizedBox(height: 12),
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, authState) {
                final isLoggedIn = authState is Authenticated &&
                    !authState.isAnonymous;
                if (!isLoggedIn) return const SizedBox.shrink();
                return SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Segnala prezzo aggiornato'),
                    onPressed: () => _showPriceReportSheet(
                        context, station, authState.userId),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _priceRow(String fuelType, double price) {
    final color = _fuelColor(fuelType);
    final icon = _fuelIcon(fuelType);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          fuelType,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        trailing: Text(
          '€ ${price.toStringAsFixed(3)}',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _noPricesBox(GasStation station) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 20),
          const SizedBox(height: 8),
          Text(
            station.id.startsWith('osm-')
                ? 'Dati da OpenStreetMap — prezzi non disponibili'
                : 'Prezzi non disponibili per questo distributore.',
            style: GoogleFonts.poppins(
                fontSize: 14, color: Colors.orange[800]),
          ),
          if (station.id.startsWith('osm-')) ...[
            const SizedBox(height: 8),
            Text(
              'Per i prezzi aggiornati contatta direttamente il distributore.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.orange[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Dettagli posizione ────────────────────────────────────────────────────

  Widget _details(GasStation station, UserLocation? userLocation) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Dati posizione'),
          const SizedBox(height: 16),
          _infoTile(
            Icons.place,
            'Indirizzo',
            station.address.isNotEmpty
                ? station.address
                : 'Indirizzo non disponibile',
          ),
          const SizedBox(height: 10),
          _infoTile(
            Icons.my_location,
            'Coordinate',
            '${station.latitude.toStringAsFixed(6)}, '
                '${station.longitude.toStringAsFixed(6)}',
          ),
          if (userLocation != null) ...[
            const SizedBox(height: 10),
            _infoTile(
              Icons.near_me,
              'Distanza',
              '${station.getDistanceFromCoordinates(
                userLocation.latitude,
                userLocation.longitude,
              ).toStringAsFixed(1)} km dalla tua posizione',
            ),
          ],
          if (station.openingHours != null &&
              station.openingHours!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _infoTile(Icons.schedule, 'Tipo impianto',
                station.openingHours!),
          ],
        ],
      ),
    );
  }

  // ─── Contatti ──────────────────────────────────────────────────────────────

  Widget _contacts(GasStation station) {
    final hasPhone = station.phoneNumber?.trim().isNotEmpty ?? false;
    final hasWebsite = station.website?.trim().isNotEmpty ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Contatti'),
          const SizedBox(height: 16),
          if (!hasPhone && !hasWebsite)
            _emptyText('Telefono e sito non disponibili.')
          else ...[
            if (hasPhone) _infoTile(Icons.phone, 'Telefono', station.phoneNumber!),
            if (hasPhone && hasWebsite) const SizedBox(height: 10),
            if (hasWebsite) _infoTile(Icons.language, 'Sito web', station.website!),
          ],
        ],
      ),
    );
  }

  // ─── Widget helpers ────────────────────────────────────────────────────────

  Widget _inlineInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondaryColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text.isNotEmpty ? text : 'Indirizzo non disponibile',
            style: GoogleFonts.poppins(
                fontSize: 14, color: AppTheme.textSecondaryColor),
          ),
        ),
      ],
    );
  }

  Widget _infoTile(IconData icon, String title, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryColor),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
              fontSize: 12, color: AppTheme.textSecondaryColor),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimaryColor,
      ),
    );
  }

  Widget _emptyText(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
          fontSize: 13, color: AppTheme.textSecondaryColor),
    );
  }

  String _formatTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min fa';
    if (diff.inHours < 24) return '${diff.inHours} ore fa';
    return '${diff.inDays} giorni fa';
  }
}