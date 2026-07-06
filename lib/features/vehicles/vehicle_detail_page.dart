import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:mappa_prezzi_benzina/domain/entities/refueling_log.dart';
import 'package:mappa_prezzi_benzina/domain/entities/vehicle.dart';
import 'package:mappa_prezzi_benzina/domain/entities/vehicle_cost_entry.dart';
import 'package:mappa_prezzi_benzina/domain/entities/vehicle_stats.dart';
import 'package:mappa_prezzi_benzina/features/vehicles/vehicle_bloc.dart';
import 'package:mappa_prezzi_benzina/features/vehicles/vehicles_screen.dart'
    show showVehicleFormSheet;
import 'package:mappa_prezzi_benzina/presentation/bloc/auth_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';
import 'package:mappa_prezzi_benzina/presentation/widgets/refueling_sheet.dart';

class VehicleDetailPage extends StatelessWidget {
  final String vehicleId;
  const VehicleDetailPage({Key? key, required this.vehicleId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VehicleBloc, VehicleState>(
      builder: (context, state) {
        final vehicle = state.vehicleById(vehicleId);
        if (vehicle == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Auto non trovata')),
          );
        }

        final stats = state.statsByVehicle[vehicleId] ?? const VehicleStats();
        final fuelLogs = state.fuelLogsByVehicle[vehicleId] ?? [];
        final costEntries = state.costEntriesByVehicle[vehicleId] ?? [];

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            backgroundColor: AppTheme.surfaceColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppTheme.textPrimaryColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(vehicle.name,
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor)),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    showVehicleFormSheet(context, existing: vehicle);
                  } else if (value == 'delete') {
                    _confirmDelete(context, vehicle);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Modifica')),
                  PopupMenuItem(value: 'delete', child: Text('Elimina')),
                ],
              ),
            ],
          ),
          floatingActionButton: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.extended(
                heroTag: 'add_cost',
                onPressed: () => _showCostEntryForm(context, vehicle),
                icon: const Icon(Icons.receipt_long_rounded),
                label: Text('Spesa',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                backgroundColor: AppTheme.textSecondaryColor,
              ),
              const SizedBox(width: 12),
              FloatingActionButton.extended(
                heroTag: 'add_refuel',
                onPressed: () =>
                    showRefuelingSheet(context, initialVehicle: vehicle),
                icon: const Icon(Icons.local_gas_station_rounded),
                label: Text('Rifornimento',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          body: state.isDetailLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kpiRow(stats),
                      const SizedBox(height: 24),
                      _sectionTitle('Costi totali'),
                      const SizedBox(height: 12),
                      _costBreakdown(stats),
                      const SizedBox(height: 24),
                      _sectionTitle('Consumo reale'),
                      const SizedBox(height: 12),
                      _consumptionSection(stats),
                      const SizedBox(height: 24),
                      _sectionTitle('Rifornimenti'),
                      const SizedBox(height: 12),
                      if (fuelLogs.isEmpty)
                        _emptyText('Nessun rifornimento registrato.')
                      else
                        ...fuelLogs.map((log) => _fuelLogTile(log)),
                      const SizedBox(height: 24),
                      _sectionTitle('Spese'),
                      const SizedBox(height: 12),
                      if (costEntries.isEmpty)
                        _emptyText('Nessuna spesa registrata.')
                      else
                        ...costEntries.map(
                          (e) => _costEntryTile(context, e),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Vehicle vehicle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Elimina auto',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'Vuoi eliminare "${vehicle.name}"? Rifornimenti e spese collegati '
          'non verranno eliminati dallo storico generale.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              context.read<VehicleBloc>().add(DeleteVehicleEvent(vehicle));
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  void _showCostEntryForm(BuildContext context, Vehicle vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<VehicleBloc>(),
        child: _CostEntryFormSheet(vehicle: vehicle),
      ),
    );
  }

  // ─── Sections ──────────────────────────────────────────────────────────────

  Widget _kpiRow(VehicleStats stats) {
    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            icon: Icons.local_gas_station_rounded,
            label: 'Rifornimenti',
            value: '${stats.refuelingCount}',
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _kpiCard(
            icon: Icons.speed_rounded,
            label: 'Consumo medio',
            value: stats.averageConsumptionL100km != null
                ? '${stats.averageConsumptionL100km!.toStringAsFixed(1)} L/100km'
                : '—',
            color: Colors.blue[600]!,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _kpiCard(
            icon: Icons.euro_rounded,
            label: 'Costo totale',
            value: '€ ${stats.totalCost.toStringAsFixed(0)}',
            color: Colors.orange[700]!,
          ),
        ),
      ],
    );
  }

  Widget _kpiCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
                fontSize: 10, color: AppTheme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _costBreakdown(VehicleStats stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          _costRow('Carburante', stats.fuelCost),
          const SizedBox(height: 8),
          _costRow('Assicurazione', stats.insuranceCost),
          const SizedBox(height: 8),
          _costRow('Bollo', stats.roadTaxCost),
          const SizedBox(height: 8),
          _costRow('Manutenzione', stats.maintenanceCost),
          const SizedBox(height: 8),
          _costRow('Altro', stats.otherCost),
          const Divider(height: 20, color: AppTheme.borderColor),
          _costRow('Totale', stats.totalCost, bold: true),
        ],
      ),
    );
  }

  Widget _costRow(String label, double amount, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: AppTheme.textSecondaryColor,
            )),
        Text('€ ${amount.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            )),
      ],
    );
  }

  Widget _consumptionSection(VehicleStats stats) {
    if (stats.consumptionHistory.isEmpty) {
      return _emptyText(
          'Registra almeno due rifornimenti con chilometraggio per calcolare il consumo reale.');
    }
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: stats.consumptionHistory.reversed.map((s) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${DateFormat('dd/MM/yy').format(s.fromDate)} → ${DateFormat('dd/MM/yy').format(s.toDate)}',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppTheme.textSecondaryColor),
                ),
                Text(
                  '${s.consumptionL100km.toStringAsFixed(1)} L/100km · ${s.distanceKm.toStringAsFixed(0)} km',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _fuelLogTile(RefuelingLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_gas_station_rounded,
              size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${log.liters.toStringAsFixed(1)} L · €${log.totalCost.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor),
                ),
                Text(
                  DateFormat('dd/MM/yyyy').format(log.timestamp) +
                      (log.odometerKm != null ? ' · ${log.odometerKm} km' : ''),
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppTheme.textSecondaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _costEntryTile(BuildContext context, VehicleCostEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_rounded,
              size: 18, color: AppTheme.textSecondaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.category.label} · €${entry.amount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor),
                ),
                Text(
                  DateFormat('dd/MM/yyyy').format(entry.date),
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppTheme.textSecondaryColor),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 18, color: AppTheme.errorColor.withOpacity(0.7)),
            visualDensity: VisualDensity.compact,
            onPressed: () => context
                .read<VehicleBloc>()
                .add(DeleteCostEntryEvent(entry)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: GoogleFonts.poppins(
            fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
      );

  Widget _emptyText(String text) => Text(
        text,
        style: GoogleFonts.poppins(
            fontSize: 13, color: AppTheme.textSecondaryColor),
      );
}

// ─── Add cost entry form ────────────────────────────────────────────────────

class _CostEntryFormSheet extends StatefulWidget {
  final Vehicle vehicle;
  const _CostEntryFormSheet({required this.vehicle});

  @override
  State<_CostEntryFormSheet> createState() => _CostEntryFormSheetState();
}

class _CostEntryFormSheetState extends State<_CostEntryFormSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  VehicleCostCategory _category = VehicleCostCategory.insurance;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) return;

    final entry = VehicleCostEntry(
      id: const Uuid().v4(),
      vehicleId: widget.vehicle.id,
      userId: authState.userId,
      category: _category,
      amount: amount,
      date: _date,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      createdAt: DateTime.now(),
    );
    context.read<VehicleBloc>().add(AddCostEntryEvent(entry));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nuova spesa · ${widget.vehicle.name}',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryColor),
          ),
          const SizedBox(height: 16),
          Text('Categoria',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondaryColor)),
          const SizedBox(height: 6),
          DropdownButtonFormField<VehicleCostCategory>(
            value: _category,
            items: VehicleCostCategory.values
                .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                .toList(),
            onChanged: (c) {
              if (c != null) setState(() => _category = c);
            },
          ),
          const SizedBox(height: 12),
          Text('Importo (€)',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondaryColor)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'es. 350'),
          ),
          const SizedBox(height: 12),
          Text('Data',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondaryColor)),
          const SizedBox(height: 6),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(),
              child: Text(DateFormat('dd/MM/yyyy').format(_date)),
            ),
          ),
          const SizedBox(height: 12),
          Text('Nota (opzionale)',
              style: GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondaryColor)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _noteCtrl,
            decoration: const InputDecoration(hintText: 'es. Tagliando 40.000 km'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              child: Text('Salva spesa',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
