import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/domain/entities/vehicle.dart';
import 'package:mappa_prezzi_benzina/features/vehicles/vehicle_bloc.dart';
import 'package:mappa_prezzi_benzina/features/vehicles/vehicle_detail_page.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/auth_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';
import 'package:mappa_prezzi_benzina/presentation/widgets/refueling_sheet.dart';

Color _fuelColor(String fuelType) {
  final n = fuelType.toLowerCase();
  if (n.contains('benzina')) return const Color(0xFF4CAF50);
  if (n.contains('diesel') || n.contains('gasolio')) return const Color(0xFF2196F3);
  if (n.contains('gpl')) return const Color(0xFFFF9800);
  if (n.contains('metano')) return const Color(0xFF9C27B0);
  return const Color(0xFF607D8B);
}

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({Key? key}) : super(key: key);

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  @override
  void initState() {
    super.initState();
    // Rete di sicurezza: se il caricamento avviato dal listener globale in
    // main.dart (alla transizione ad Authenticated) fallisce silenziosamente
    // per un errore di rete/permessi transitorio subito dopo un reload della
    // pagina, qui riproviamo appena questa scheda viene costruita, evitando
    // che l'utente resti bloccato con la sezione Auto vuota nonostante il
    // login sia ancora valido.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authState = context.read<AuthBloc>().state;
      if (authState is Authenticated && !authState.isAnonymous) {
        context.read<VehicleBloc>().add(LoadVehiclesEvent(authState.userId));
      }
    });
  }

  Future<void> _refresh(BuildContext context) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated && !authState.isAnonymous) {
      context.read<VehicleBloc>().add(LoadVehiclesEvent(authState.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isLoggedIn = authState is Authenticated && !authState.isAnonymous;

    if (!isLoggedIn) return const _GuestVehiclesView();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Auto',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppTheme.primaryColor),
            tooltip: 'Aggiungi auto',
            onPressed: () => showVehicleFormSheet(context),
          ),
        ],
      ),
      body: BlocBuilder<VehicleBloc, VehicleState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.vehicles.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => _refresh(context),
              child: ListView(
                children: [
                  _EmptyVehicles(onAdd: () => showVehicleFormSheet(context)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => _refresh(context),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.vehicles.length,
              itemBuilder: (ctx, i) {
                final vehicle = state.vehicles[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _VehicleCard(vehicle: vehicle),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ─── Guest view ─────────────────────────────────────────────────────────────

class _GuestVehiclesView extends StatelessWidget {
  const _GuestVehiclesView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Auto',
            style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_car_rounded,
                  size: 64, color: AppTheme.borderColor),
              const SizedBox(height: 16),
              Text(
                'Accedi per gestire le tue auto',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Registra i rifornimenti, il consumo reale e le spese '
                '(assicurazione, bollo, manutenzione) della tua auto.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  context.read<AuthBloc>().add(const SignOutEvent());
                },
                child: Text('Accedi',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ────────────────────────────────────────────────────────────

class _EmptyVehicles extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyVehicles({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_car_rounded,
                size: 64, color: AppTheme.borderColor),
            const SizedBox(height: 16),
            Text(
              'Aggiungi la tua auto',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra i rifornimenti per vedere quanto spendi e quanto '
              'consuma davvero, oltre ai costi di assicurazione, bollo e manutenzione.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text('Aggiungi auto',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Vehicle card ───────────────────────────────────────────────────────────

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  const _VehicleCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final color = _fuelColor(vehicle.fuelType);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        context.read<VehicleBloc>().add(LoadVehicleDetailEvent(vehicle.id));
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => VehicleDetailPage(vehicleId: vehicle.id)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.directions_car_rounded, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          vehicle.name,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (vehicle.isDefault)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'PREDEFINITA',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      vehicle.fuelType,
                      if (vehicle.plate != null && vehicle.plate!.isNotEmpty)
                        vehicle.plate!,
                      if (vehicle.lastOdometerKm != null)
                        '${vehicle.lastOdometerKm} km',
                    ].join(' · '),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.local_gas_station_rounded,
                  color: AppTheme.primaryColor),
              tooltip: 'Registra rifornimento',
              onPressed: () =>
                  showRefuelingSheet(context, initialVehicle: vehicle),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: AppTheme.errorColor.withOpacity(0.7)),
              tooltip: 'Elimina auto',
              onPressed: () => _confirmDeleteVehicle(context, vehicle),
            ),
          ],
        ),
      ),
    );
  }
}

void _confirmDeleteVehicle(BuildContext context, Vehicle vehicle) {
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
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
          onPressed: () {
            Navigator.pop(ctx);
            context.read<VehicleBloc>().add(DeleteVehicleEvent(vehicle));
          },
          child: const Text('Elimina'),
        ),
      ],
    ),
  );
}

// ─── Add / edit vehicle form ────────────────────────────────────────────────

void showVehicleFormSheet(BuildContext context, {Vehicle? existing}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => BlocProvider.value(
      value: context.read<VehicleBloc>(),
      child: _VehicleFormSheet(existing: existing),
    ),
  );
}

class _VehicleFormSheet extends StatefulWidget {
  final Vehicle? existing;
  const _VehicleFormSheet({this.existing});

  @override
  State<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends State<_VehicleFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _plateCtrl;
  late final TextEditingController _consumoCtrl;
  late final TextEditingController _serbatoioCtrl;
  late String _fuelType;

  @override
  void initState() {
    super.initState();
    final v = widget.existing;
    _nameCtrl = TextEditingController(text: v?.name ?? '');
    _plateCtrl = TextEditingController(text: v?.plate ?? '');
    _consumoCtrl = TextEditingController(
        text: v?.declaredConsumptionL100km?.toStringAsFixed(1) ?? '10.0');
    _serbatoioCtrl = TextEditingController(
        text: v?.tankSizeLiters?.toStringAsFixed(0) ?? '50');
    _fuelType = v?.fuelType ?? AppConstants.fuelTypes.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _plateCtrl.dispose();
    _consumoCtrl.dispose();
    _serbatoioCtrl.dispose();
    super.dispose();
  }

  void _save(BuildContext context) {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    final consumo =
        double.tryParse(_consumoCtrl.text.replaceAll(',', '.')) ?? 10.0;
    final serbatoio =
        double.tryParse(_serbatoioCtrl.text.replaceAll(',', '.')) ?? 50.0;
    final plate = _plateCtrl.text.trim();
    final vehicles = context.read<VehicleBloc>().state.vehicles;

    final vehicle = Vehicle(
      id: widget.existing?.id ?? const Uuid().v4(),
      userId: authState.userId,
      name: name,
      plate: plate.isEmpty ? null : plate,
      fuelType: _fuelType,
      tankSizeLiters: serbatoio.clamp(10.0, 200.0),
      declaredConsumptionL100km: consumo.clamp(1.0, 40.0),
      lastOdometerKm: widget.existing?.lastOdometerKm,
      isDefault: widget.existing?.isDefault ?? vehicles.isEmpty,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    if (widget.existing != null) {
      context.read<VehicleBloc>().add(UpdateVehicleEvent(vehicle));
    } else {
      context.read<VehicleBloc>().add(AddVehicleEvent(vehicle));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
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
          const SizedBox(height: 20),
          Text(
            isEdit ? 'Modifica auto' : 'Nuova auto',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 16),
          _label('Nome auto'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameCtrl,
            decoration: _inputDec(hint: 'es. Fiat Panda'),
            style: GoogleFonts.poppins(fontSize: 13),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          _label('Targa (opzionale)'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _plateCtrl,
            decoration: _inputDec(hint: 'es. AB123CD'),
            style: GoogleFonts.poppins(fontSize: 13),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          _label('Carburante'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _fuelType,
            decoration: _inputDec(),
            style:
                GoogleFonts.poppins(fontSize: 13, color: AppTheme.textPrimaryColor),
            items: AppConstants.fuelTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _fuelType = v);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Consumo dichiarato (L/100km)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _consumoCtrl,
                      decoration: _inputDec(hint: 'es. 7.5'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Serbatoio (litri)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _serbatoioCtrl,
                      decoration: _inputDec(hint: 'es. 50'),
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _save(context),
              child: Text(
                isEdit ? 'Aggiorna' : 'Aggiungi',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style:
            GoogleFonts.poppins(fontSize: 12, color: AppTheme.textSecondaryColor),
      );

  InputDecoration _inputDec({String? hint}) => InputDecoration(
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
}
