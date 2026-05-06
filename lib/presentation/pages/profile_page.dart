import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/domain/entities/saved_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/vehicle_profile.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/auth_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/favorites_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/user_profile_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';
import 'package:uuid/uuid.dart';

Color _fuelColor(String fuelType) {
  final n = fuelType.toLowerCase();
  if (n.contains('benzina')) return const Color(0xFF4CAF50);
  if (n.contains('diesel') || n.contains('gasolio')) return const Color(0xFF2196F3);
  if (n.contains('hvo')) return const Color(0xFF00796B);
  if (n.contains('gpl')) return const Color(0xFFFF9800);
  if (n.contains('metano') || n.contains('gnc') || n.contains('gnl')) return const Color(0xFF9C27B0);
  if (n.contains('idrogeno')) return const Color(0xFF00BCD4);
  return const Color(0xFF607D8B);
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final favState = context.watch<FavoritesBloc>().state;

    final isAnonymous =
        authState is Authenticated ? authState.isAnonymous : true;
    final userId =
        authState is Authenticated ? authState.userId : null;

    context.watch<UserProfileBloc>();

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
        title: Text(
          'Profilo',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isAnonymous
                    ? AppTheme.borderColor
                    : AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAnonymous ? Icons.person_outline : Icons.person,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),

            // Tipo account
            Text(
              isAnonymous ? 'Ospite' : 'Account registrato',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            if (!isAnonymous && userId != null) ...[
              const SizedBox(height: 4),
              Text(
                userId,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Sezione preferiti (solo utenti registrati)
            if (!isAnonymous) ...[
              _FavoritesPreview(
                stations: favState.stations,
                count: favState.ids.length,
                isLoading: favState.isLoading,
                onViewAll: () => Navigator.pushNamed(context, '/favorites'),
              ),
              const SizedBox(height: 12),

              // Dashboard link
              _InfoCard(
                icon: Icons.bar_chart_rounded,
                iconColor: AppTheme.primaryColor,
                title: 'La tua dashboard',
                value: '',
                onTap: () => Navigator.pushNamed(context, '/dashboard'),
              ),
              const SizedBox(height: 24),

              // Veicoli
              const _VehiclesSection(),
              const SizedBox(height: 12),
            ],

            // Sezione ospite: invito a registrarsi
            if (isAnonymous) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: AppTheme.primaryColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Account ospite',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Registrati per salvare le tue stazioni preferite e accedere alla tua area personale.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          context.read<AuthBloc>().add(const SignOutEvent());
                        },
                        child: Text('Crea un account',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Logout
            _InfoCard(
              icon: Icons.logout_rounded,
              iconColor: AppTheme.errorColor,
              title: 'Esci',
              value: '',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Esci',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600)),
                    content: Text(
                      'Sei sicuro di voler uscire?',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Annulla'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorColor),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                          context
                              .read<AuthBloc>()
                              .add(const SignOutEvent());
                        },
                        child: const Text('Esci'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesPreview extends StatelessWidget {
  final List<SavedStation> stations;
  final int count;
  final bool isLoading;
  final VoidCallback onViewAll;

  const _FavoritesPreview({
    required this.stations,
    required this.count,
    required this.isLoading,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: onViewAll,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.favorite_rounded, color: Colors.red, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Stazioni preferite',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ),
                  if (count > 0)
                    Text(
                      '$count',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.textSecondaryColor, size: 20),
                ],
              ),
            ),
          ),

          // Lista preview (max 3)
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (stations.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'Nessuna stazione preferita ancora.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            )
          else ...[
            const Divider(height: 1, color: AppTheme.borderColor),
            ...stations.take(3).map((s) => _StationPreviewRow(station: s)),
            if (stations.length > 3) ...[
              const Divider(height: 1, color: AppTheme.borderColor),
              InkWell(
                onTap: onViewAll,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text(
                      'Vedi tutti (${stations.length})',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StationPreviewRow extends StatelessWidget {
  final SavedStation station;
  const _StationPreviewRow({required this.station});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            station.name,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            station.address,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppTheme.textSecondaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (station.prices.isNotEmpty) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: station.prices.entries.map((e) {
                  final color = _fuelColor(e.key);
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${e.key}  €${e.value.toStringAsFixed(3)}',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Multi-vehicle section ──────────────────────────────────────────────────

class _VehiclesSection extends StatelessWidget {
  const _VehiclesSection();

  @override
  Widget build(BuildContext context) {
    final profileState = context.watch<UserProfileBloc>().state;
    final profile = profileState.profile;
    final vehicles = profile?.vehicles ?? [];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.directions_car_rounded,
                    color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'I tuoi veicoli',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
                if (profileState.isSaving)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderColor),

          if (vehicles.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Nessun veicolo aggiunto.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            )
          else
            ...vehicles.map(
              (v) => _VehicleCard(
                vehicle: v,
                isActive: v.id == profile?.activeVehicleId,
                onSetActive: () => context
                    .read<UserProfileBloc>()
                    .add(SetActiveVehicleEvent(v.id)),
                onEdit: () => _showVehicleForm(context, existing: v),
                onDelete: () => _confirmDelete(context, v),
              ),
            ),

          const Divider(height: 1, color: AppTheme.borderColor),
          InkWell(
            onTap: () => _showVehicleForm(context),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded,
                      color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Aggiungi veicolo',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, VehicleProfile vehicle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Elimina veicolo',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'Vuoi eliminare "${vehicle.name}"?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<UserProfileBloc>()
                  .add(RemoveVehicleEvent(vehicle.id));
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  void _showVehicleForm(BuildContext context, {VehicleProfile? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<UserProfileBloc>(),
        child: _VehicleFormSheet(existing: existing),
      ),
    );
  }
}

// ─── Single vehicle card ────────────────────────────────────────────────────

class _VehicleCard extends StatelessWidget {
  final VehicleProfile vehicle;
  final bool isActive;
  final VoidCallback onSetActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VehicleCard({
    required this.vehicle,
    required this.isActive,
    required this.onSetActive,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _fuelColor(vehicle.preferredFuelType);
    return InkWell(
      onTap: isActive ? null : onSetActive,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryColor.withOpacity(0.06)
              : Colors.transparent,
          border: const Border(
              bottom: BorderSide(color: AppTheme.borderColor)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.directions_car_rounded,
                  color: color, size: 18),
            ),
            const SizedBox(width: 12),
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
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isActive)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ATTIVO',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${vehicle.preferredFuelType} · '
                    '${vehicle.fuelConsumption.toStringAsFixed(1)} L/100km · '
                    '${vehicle.tankSize.toStringAsFixed(0)} L',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: AppTheme.textSecondaryColor),
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 18, color: AppTheme.errorColor.withOpacity(0.7)),
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add / Edit vehicle form ────────────────────────────────────────────────

class _VehicleFormSheet extends StatefulWidget {
  final VehicleProfile? existing;
  const _VehicleFormSheet({this.existing});

  @override
  State<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends State<_VehicleFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _consumoCtrl;
  late final TextEditingController _serbatoioCtrl;
  late String _fuelType;

  @override
  void initState() {
    super.initState();
    final v = widget.existing;
    _nameCtrl = TextEditingController(text: v?.name ?? '');
    _consumoCtrl = TextEditingController(
        text: v?.fuelConsumption.toStringAsFixed(1) ?? '10.0');
    _serbatoioCtrl = TextEditingController(
        text: v?.tankSize.toStringAsFixed(0) ?? '50');
    _fuelType = v?.preferredFuelType ?? AppConstants.fuelTypes.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _consumoCtrl.dispose();
    _serbatoioCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final consumo =
        double.tryParse(_consumoCtrl.text.replaceAll(',', '.')) ?? 10.0;
    final serbatoio =
        double.tryParse(_serbatoioCtrl.text.replaceAll(',', '.')) ?? 50.0;

    final vehicle = VehicleProfile(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: name,
      fuelConsumption: consumo.clamp(1.0, 40.0),
      tankSize: serbatoio.clamp(10.0, 200.0),
      preferredFuelType: _fuelType,
    );

    if (widget.existing != null) {
      context.read<UserProfileBloc>().add(UpdateVehicleEvent(vehicle));
    } else {
      context.read<UserProfileBloc>().add(AddVehicleEvent(vehicle));
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
            isEdit ? 'Modifica veicolo' : 'Nuovo veicolo',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 16),

          // Nome
          _label('Nome veicolo'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameCtrl,
            decoration: _inputDec(hint: 'es. Fiat Panda'),
            style: GoogleFonts.poppins(fontSize: 13),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),

          // Carburante
          _label('Carburante preferito'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _fuelType,
            decoration: _inputDec(),
            style: GoogleFonts.poppins(
                fontSize: 13, color: AppTheme.textPrimaryColor),
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
                    _label('Consumo (L/100km)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _consumoCtrl,
                      decoration: _inputDec(hint: 'es. 7.5'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
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
              onPressed: _save,
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
        style: GoogleFonts.poppins(
            fontSize: 12, color: AppTheme.textSecondaryColor),
      );

  InputDecoration _inputDec({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.poppins(fontSize: 13, color: AppTheme.borderColor),
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
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}
