import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/core/services/real_cost_calculator.dart';
import 'package:mappa_prezzi_benzina/domain/entities/gas_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/refueling_log.dart';
import 'package:mappa_prezzi_benzina/domain/entities/vehicle.dart';
import 'package:mappa_prezzi_benzina/features/vehicles/vehicle_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/auth_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/dashboard_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/map_bloc.dart'
    show MapBloc, MapLoaded, MapLoading;
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';

/// Bottom sheet condiviso per registrare un rifornimento, usato sia dalla
/// scheda di un distributore (con `station` valorizzato: prezzo e confronto
/// zona automatici) sia dalla sezione Auto (`station` null: prezzo manuale,
/// nessun confronto zona). In entrambi i casi produce un solo [RefuelingLog]
/// che alimenta sia la Dashboard "risparmio vs zona" sia lo storico/consumo
/// del veicolo selezionato — un solo flusso, due punti di ingresso.
Future<void> showRefuelingSheet(
  BuildContext context, {
  GasStation? station,
  Vehicle? initialVehicle,
}) {
  final authState = context.read<AuthBloc>().state;
  if (authState is! Authenticated) return Future.value();

  final vehicles = context.read<VehicleBloc>().state.vehicles;
  Vehicle? selectedVehicle =
      initialVehicle ?? context.read<VehicleBloc>().state.defaultVehicle;

  String selectedFuel = station != null
      ? (station.prices.containsKey(selectedVehicle?.fuelType)
          ? selectedVehicle!.fuelType
          : station.prices.keys.first)
      : (selectedVehicle?.fuelType ?? AppConstants.fuelTypes.first);

  final litersCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final odometerCtrl = TextEditingController(
    text: selectedVehicle?.lastOdometerKm?.toString() ?? '',
  );

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          final price = station != null
              ? (station.prices[selectedFuel] ?? 0)
              : (double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0);
          final liters =
              double.tryParse(litersCtrl.text.replaceAll(',', '.')) ?? 0;
          final total = price * liters;
          final odometerKm = int.tryParse(odometerCtrl.text.trim());

          double areaAvg = 0;
          double saved = 0;
          if (station != null) {
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
            areaAvg = nearbyPrices.isNotEmpty
                ? RealCostCalculator.areaAverage(nearbyPrices)
                : price;
            saved = (areaAvg - price) * liters;
          }

          final needsOdometer = selectedVehicle != null;
          final canSave = liters > 0 &&
              price > 0 &&
              (!needsOdometer || (odometerKm != null && odometerKm > 0));

          return Padding(
            padding: EdgeInsets.fromLTRB(
                24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
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
                  if (station != null)
                    Text(
                      station.name,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (vehicles.isNotEmpty) ...[
                    _label('Auto'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      value: selectedVehicle?.id,
                      decoration: _sheetInputDecoration(),
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppTheme.textPrimaryColor),
                      items: [
                        ...vehicles.map((v) => DropdownMenuItem(
                              value: v.id,
                              child: Text(v.name),
                            )),
                        const DropdownMenuItem(
                            value: null, child: Text('Nessun veicolo')),
                      ],
                      onChanged: (id) {
                        setSheet(() {
                          selectedVehicle = id == null
                              ? null
                              : vehicles.firstWhere((v) => v.id == id);
                          odometerCtrl.text =
                              selectedVehicle?.lastOdometerKm?.toString() ?? '';
                          if (station == null && selectedVehicle != null) {
                            selectedFuel = selectedVehicle!.fuelType;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (needsOdometer) ...[
                    _label('Chilometraggio attuale'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: odometerCtrl,
                      decoration: _sheetInputDecoration(hint: 'es. 54200'),
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.poppins(fontSize: 13),
                      onChanged: (_) => setSheet(() {}),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _label('Carburante'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedFuel,
                    decoration: _sheetInputDecoration(),
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppTheme.textPrimaryColor),
                    items: (station != null
                            ? station.prices.keys
                            : AppConstants.fuelTypes)
                        .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSheet(() => selectedFuel = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (station == null) ...[
                    _label('Prezzo al litro'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: priceCtrl,
                      decoration: _sheetInputDecoration(hint: 'es. 1.899'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.poppins(fontSize: 13),
                      onChanged: (_) => setSheet(() {}),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _label('Litri riforniti'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: litersCtrl,
                    decoration: _sheetInputDecoration(hint: 'es. 40'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.poppins(fontSize: 13),
                    onChanged: (_) => setSheet(() {}),
                  ),
                  const SizedBox(height: 16),
                  if (price > 0) ...[
                    _sheetRow(
                        'Prezzo al litro', '€ ${price.toStringAsFixed(3)}'),
                    const SizedBox(height: 4),
                    _sheetRow('Totale stimato', '€ ${total.toStringAsFixed(2)}',
                        bold: true),
                    if (areaAvg > 0 && saved.abs() > 0.01) ...[
                      const SizedBox(height: 4),
                      _sheetRow(
                        saved >= 0 ? 'Risparmio vs zona' : 'Extra vs zona',
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
                      onPressed: canSave
                          ? () {
                              final log = RefuelingLog(
                                id: const Uuid().v4(),
                                userId: authState.userId,
                                stationId: station?.id ?? '',
                                stationName: station?.name ?? '',
                                fuelType: selectedFuel,
                                pricePerLiter: price,
                                liters: liters,
                                totalCost: total,
                                savedVsArea: saved,
                                areaAvgPrice: areaAvg,
                                timestamp: DateTime.now(),
                                vehicleId: selectedVehicle?.id,
                                odometerKm: odometerKm,
                              );
                              context
                                  .read<DashboardBloc>()
                                  .add(LogRefuelingEvent(log));
                              if (log.vehicleId != null) {
                                context
                                    .read<VehicleBloc>()
                                    .add(RefuelingLoggedEvent(log));
                              }
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
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _label(String text) => Text(
      text,
      style:
          GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondaryColor),
    );

InputDecoration _sheetInputDecoration({String? hint}) => InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppTheme.borderColor),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
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
