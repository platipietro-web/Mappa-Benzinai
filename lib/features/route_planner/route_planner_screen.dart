import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/core/services/geocoding_service.dart';
import 'package:mappa_prezzi_benzina/domain/entities/gas_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/route_station_suggestion.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';
import 'package:mappa_prezzi_benzina/features/route_planner/route_planner_bloc.dart';
import 'package:mappa_prezzi_benzina/features/route_planner/route_station_card.dart';
import 'package:mappa_prezzi_benzina/features/vehicles/vehicle_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/location_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';
import 'package:mappa_prezzi_benzina/presentation/widgets/station_pin.dart';

const double _kDesktopBreakpoint = 768.0;

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  final MapController _mapController = MapController();
  final ScrollController _listScrollController = ScrollController();
  final Map<String, GlobalKey> _cardKeys = {};

  // ── Origine ──────────────────────────────────────────────────────────────
  bool _useCurrentLocation = true;
  GeocodingResult? _originResult;
  final TextEditingController _originController = TextEditingController();
  List<GeocodingResult> _originResults = [];
  Timer? _originDebounce;
  bool _originLoading = false;

  // ── Destinazione ─────────────────────────────────────────────────────────
  GeocodingResult? _destResult;
  final TextEditingController _destController = TextEditingController();
  List<GeocodingResult> _destResults = [];
  Timer? _destDebounce;
  bool _destLoading = false;

  String _fuelType = 'Benzina';
  List<String> _selectedBrands = [];
  bool _showForm = true;
  String? _selectedStationId;

  // Origine usata nell'ultimo calcolo, come fallback per il dettaglio
  // stazione se il GPS non è disponibile.
  UserLocation? _lastOrigin;

  @override
  void dispose() {
    _originDebounce?.cancel();
    _destDebounce?.cancel();
    _originController.dispose();
    _destController.dispose();
    _mapController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  // ─── Ricerca luoghi ──────────────────────────────────────────────────────

  void _onOriginChanged(String query) {
    _originDebounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _originResults = []);
      return;
    }
    setState(() => _originLoading = true);
    _originDebounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await GeocodingService.search(query);
      if (!mounted) return;
      setState(() {
        _originResults = results;
        _originLoading = false;
      });
    });
  }

  void _onDestChanged(String query) {
    _destDebounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _destResults = []);
      return;
    }
    setState(() => _destLoading = true);
    _destDebounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await GeocodingService.search(query);
      if (!mounted) return;
      setState(() {
        _destResults = results;
        _destLoading = false;
      });
    });
  }

  // ─── Calcolo percorso ────────────────────────────────────────────────────

  void _calculate() {
    final destination = _destResult;
    if (destination == null) {
      _showSnack('Inserisci una destinazione dai risultati di ricerca');
      return;
    }

    double originLat;
    double originLon;
    String originLabel;

    if (_useCurrentLocation) {
      final locState = context.read<LocationBloc>().state;
      if (locState is LocationLoaded) {
        originLat = locState.location.latitude;
        originLon = locState.location.longitude;
        originLabel = 'La mia posizione';
      } else {
        context
            .read<LocationBloc>()
            .add(const RequestLocationPermissionEvent());
        _showSnack(
            'Recupero la posizione, riprova tra un istante o cerca un punto di partenza');
        return;
      }
    } else if (_originResult != null) {
      originLat = _originResult!.lat;
      originLon = _originResult!.lon;
      originLabel = _originResult!.name;
    } else {
      _showSnack('Inserisci un punto di partenza dai risultati di ricerca');
      return;
    }

    _lastOrigin = UserLocation(
      latitude: originLat,
      longitude: originLon,
      timestamp: DateTime.now(),
    );

    final vehicle = context.read<VehicleBloc>().state.defaultVehicle;

    context.read<RoutePlannerBloc>().add(CalculateRouteEvent(
          originLat: originLat,
          originLon: originLon,
          originLabel: originLabel,
          destLat: destination.lat,
          destLon: destination.lon,
          destLabel: destination.name,
          fuelType: _fuelType,
          consumption: vehicle?.declaredConsumptionL100km ?? 10.0,
          tankSize: vehicle?.tankSizeLiters ?? 50.0,
        ));

    setState(() {
      _showForm = false;
      _selectedStationId = null;
      _selectedBrands = [];
    });
  }

  void _editSearch() {
    setState(() => _showForm = true);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _fitRouteBounds(List<LatLng> points) {
    if (points.isEmpty) return;
    try {
      _mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
      ));
    } catch (_) {}
  }

  void _onSuggestionTap(GasStation station) {
    setState(() => _selectedStationId = station.id);
    try {
      _mapController.move(
        LatLng(station.latitude, station.longitude),
        13.0,
      );
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _cardKeys[station.id];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
    });
  }

  void _openStationDetail(GasStation station) {
    Navigator.pushNamed(
      context,
      '/station-detail',
      arguments: {
        'station': station,
        'userLocation': _lastOrigin,
      },
    );
  }

  void _addWaypoint(GasStation station) {
    setState(() => _selectedStationId = null);
    context.read<RoutePlannerBloc>().add(AddWaypointEvent(station));
  }

  void _removeWaypoint() {
    setState(() => _selectedStationId = null);
    context.read<RoutePlannerBloc>().add(const RemoveWaypointEvent());
  }

  List<RouteStationSuggestion> _applyBrandFilter(
      List<RouteStationSuggestion> all) {
    if (_selectedBrands.isEmpty) return all;
    return all
        .where((s) =>
            s.station.brand != null && _selectedBrands.contains(s.station.brand))
        .toList();
  }

  void _showBrandFilterSheet(List<RouteStationSuggestion> allSuggestions) {
    final availableBrands = allSuggestions
        .map((s) => s.station.brand)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    if (availableBrands.isEmpty) {
      _showSnack('Nessun brand disponibile tra i distributori trovati');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var tempSelected = List<String>.from(_selectedBrands)
          ..removeWhere((b) => !availableBrands.contains(b));
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) => Container(
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filtra per brand',
                          style: GoogleFonts.poppins(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (tempSelected.isNotEmpty)
                          TextButton(
                            onPressed: () =>
                                setSheetState(() => tempSelected.clear()),
                            child: const Text('Tutti'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableBrands.map((brand) {
                        final isSelected = tempSelected.contains(brand);
                        return FilterChip(
                          label: Text(brand),
                          selected: isSelected,
                          onSelected: (selected) => setSheetState(() {
                            if (selected) {
                              tempSelected.add(brand);
                            } else {
                              tempSelected.remove(brand);
                            }
                          }),
                          backgroundColor: AppTheme.backgroundColor,
                          selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                          checkmarkColor: AppTheme.primaryColor,
                          labelStyle: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textPrimaryColor,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _selectedBrands = tempSelected);
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('Applica'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: _showForm
            ? Column(
                children: [
                  _buildHeader(null),
                  Expanded(child: _buildForm()),
                ],
              )
            : BlocBuilder<RoutePlannerBloc, RoutePlannerState>(
                builder: (context, state) => Column(
                  children: [
                    _buildHeader(state),
                    Expanded(child: _buildResults(state)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(RoutePlannerState? state) {
    final loaded = state is RoutePlannerLoaded ? state : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Icon(Icons.alt_route_rounded, color: AppTheme.primaryColor, size: 22),
          const SizedBox(width: 10),
          Text(
            'Percorso',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const Spacer(),
          if (loaded != null) ...[
            _filterButton(
              active: _selectedBrands.isNotEmpty,
              onTap: () => _showBrandFilterSheet(loaded.suggestions),
            ),
            const SizedBox(width: 4),
          ],
          if (!_showForm)
            TextButton.icon(
              onPressed: _editSearch,
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Modifica'),
            ),
        ],
      ),
    );
  }

  Widget _filterButton({required bool active, required VoidCallback onTap}) {
    return Tooltip(
      message: 'Filtra per brand',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: active
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondaryColor,
                ),
              ),
              if (active)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Form ────────────────────────────────────────────────────────────────

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trova il benzinaio più conveniente lungo il tuo tragitto: '
              'calcoliamo il percorso reale e confrontiamo i prezzi tenendo '
              'conto di quanto ti devi scostare dalla strada.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel('Da'),
            const SizedBox(height: 8),
            _buildOriginField(),
            const SizedBox(height: 18),
            _sectionLabel('A'),
            const SizedBox(height: 8),
            _buildPlaceField(
              controller: _destController,
              hint: 'Cerca una destinazione...',
              results: _destResults,
              loading: _destLoading,
              onChanged: _onDestChanged,
              onSelected: (r) {
                setState(() {
                  _destResult = r;
                  _destController.text = r.name;
                  _destResults = [];
                });
              },
            ),
            const SizedBox(height: 20),
            _sectionLabel('Carburante'),
            const SizedBox(height: 10),
            _buildFuelChips(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.alt_route_rounded),
                label: const Text('Calcola percorso'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimaryColor,
        ),
      );

  Widget _buildOriginField() {
    if (_useCurrentLocation) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.my_location_rounded,
                size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'La mia posizione',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _useCurrentLocation = false),
              child: const Text('Cambia'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPlaceField(
          controller: _originController,
          hint: 'Cerca un punto di partenza...',
          results: _originResults,
          loading: _originLoading,
          onChanged: _onOriginChanged,
          onSelected: (r) {
            setState(() {
              _originResult = r;
              _originController.text = r.name;
              _originResults = [];
            });
          },
        ),
        TextButton.icon(
          onPressed: () => setState(() {
            _useCurrentLocation = true;
            _originResult = null;
            _originController.clear();
            _originResults = [];
          }),
          icon: const Icon(Icons.my_location_rounded, size: 16),
          label: const Text('Usa la mia posizione'),
        ),
      ],
    );
  }

  /// Campo di ricerca luogo con debounce + lista risultati, riusato per i
  /// campi "Da" (ricerca libera) e "A" — stesso pattern di
  /// map_page.dart (`_buildSearchField`/`_buildSearchResults`).
  Widget _buildPlaceField({
    required TextEditingController controller,
    required String hint,
    required List<GeocodingResult> results,
    required bool loading,
    required ValueChanged<String> onChanged,
    required ValueChanged<GeocodingResult> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              const Icon(Icons.search_rounded,
                  size: 18, color: AppTheme.textSecondaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.poppins(
                        fontSize: 14, color: AppTheme.textSecondaryColor),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        if (results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: results
                  .map((r) => InkWell(
                        onTap: () => onSelected(r),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 18, color: AppTheme.primaryColor),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(r.name,
                                        style: GoogleFonts.poppins(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w500)),
                                    if (r.subtitle.isNotEmpty)
                                      Text(r.subtitle,
                                          style: GoogleFonts.poppins(
                                              fontSize: 11.5,
                                              color: AppTheme
                                                  .textSecondaryColor)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildFuelChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppConstants.fuelTypes.map((ft) {
        final isSelected = _fuelType == ft;
        return ChoiceChip(
          label: Text(
              '${AppConstants.fuelTypeIcons[ft] ?? ''} $ft'.trim()),
          selected: isSelected,
          onSelected: (_) => setState(() => _fuelType = ft),
          backgroundColor: AppTheme.backgroundColor,
          selectedColor: AppTheme.primaryColor.withOpacity(0.15),
          labelStyle: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color:
                isSelected ? AppTheme.primaryColor : AppTheme.textPrimaryColor,
          ),
          side: BorderSide(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
          ),
        );
      }).toList(),
    );
  }

  // ─── Risultati ───────────────────────────────────────────────────────────

  Widget _buildResults(RoutePlannerState state) {
    if (state is RoutePlannerLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Calcolo del percorso migliore...',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: AppTheme.textSecondaryColor)),
          ],
        ),
      );
    }

    if (state is RoutePlannerError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 12),
              Text(state.message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: _calculate, child: const Text('Riprova')),
            ],
          ),
        ),
      );
    }

    if (state is RoutePlannerLoaded) {
      final points = state.activeRoute.points
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitRouteBounds(points);
      });

      final isDesktop =
          MediaQuery.of(context).size.width >= _kDesktopBreakpoint;
      final filtered = _applyBrandFilter(state.suggestions);

      return Column(
        children: [
          _buildSummaryBar(state, filtered),
          _buildAlternativesRow(state),
          if (state.isRecalculating) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: isDesktop
                ? Row(
                    children: [
                      SizedBox(
                        width: 380,
                        child: _buildSuggestionsList(state, filtered),
                      ),
                      Expanded(child: _buildMap(state, points, filtered)),
                    ],
                  )
                : Column(
                    children: [
                      SizedBox(
                          height: 260,
                          child: _buildMap(state, points, filtered)),
                      Expanded(child: _buildSuggestionsList(state, filtered)),
                    ],
                  ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSummaryBar(
      RoutePlannerLoaded state, List<RouteStationSuggestion> filtered) {
    final waypoint = state.waypointStation;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: AppTheme.surfaceColor,
      child: waypoint == null
          ? Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 14,
              runSpacing: 4,
              children: [
                _summaryChip(Icons.directions_car_rounded,
                    '${state.activeRoute.distanceKm.toStringAsFixed(0)} km'),
                _summaryChip(Icons.schedule_rounded,
                    '${state.activeRoute.durationMin.round()} min'),
                _summaryChip(Icons.local_gas_station_rounded,
                    '${filtered.length} distributori lungo il percorso'),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${state.originLabel} → ⛽ ${waypoint.name} → ${state.destLabel}',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      _summaryChip(Icons.directions_car_rounded,
                          '${state.activeRoute.distanceKm.toStringAsFixed(0)} km'),
                      _summaryChip(Icons.schedule_rounded,
                          '${state.activeRoute.durationMin.round()} min'),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _removeWaypoint,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Rimuovi tappa'),
                  style:
                      TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
                ),
              ],
            ),
    );
  }

  /// Chip delle alternative stradali proposte da OSRM per lo stesso viaggio
  /// Partenza → Destinazione. Nascosta quando c'è una sola route o quando è
  /// impostata una tappa (in quel caso la route è unica, vincolata).
  Widget _buildAlternativesRow(RoutePlannerLoaded state) {
    if (state.routes.length <= 1 || state.waypointStation != null) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      color: AppTheme.surfaceColor,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(state.routes.length, (i) {
            final route = state.routes[i];
            final isSelected = i == state.selectedRouteIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  '${i == 0 ? "Percorso più veloce" : "Alternativa $i"} · '
                  '${route.distanceKm.toStringAsFixed(0)} km · '
                  '${route.durationMin.round()} min',
                ),
                selected: isSelected,
                onSelected: (_) {
                  if (isSelected) return;
                  setState(() => _selectedStationId = null);
                  context
                      .read<RoutePlannerBloc>()
                      .add(SelectRouteAlternativeEvent(i));
                },
                backgroundColor: AppTheme.backgroundColor,
                selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                labelStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textPrimaryColor,
                ),
                side: BorderSide(
                  color:
                      isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _summaryChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppTheme.textSecondaryColor),
        const SizedBox(width: 4),
        Text(text,
            style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryColor)),
      ],
    );
  }

  Widget _buildMap(RoutePlannerLoaded state, List<LatLng> points,
      List<RouteStationSuggestion> suggestions) {
    final origin = points.first;
    final dest = points.last;
    return ClipRect(
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: origin,
          initialZoom: 12,
          maxZoom: 18,
          minZoom: 5,
        ),
        children: [
          TileLayer(
            urlTemplate: AppConstants.tileUrlTemplate,
            subdomains: AppConstants.tileSubdomains,
            evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
            userAgentPackageName: 'it.mappabenzinai.app',
          ),
          RichAttributionWidget(
            attributions: [
              TextSourceAttribution(AppConstants.tileAttribution),
            ],
          ),
          PolylineLayer(polylines: [
            Polyline(
              points: points,
              strokeWidth: 4,
              color: AppTheme.primaryColor,
            ),
          ]),
          MarkerLayer(markers: [
            Marker(
              point: origin,
              width: 24,
              height: 24,
              child: const _EndpointDot(color: AppTheme.primaryColor),
            ),
            Marker(
              point: dest,
              width: 24,
              height: 24,
              child: const _EndpointDot(color: AppTheme.errorColor),
            ),
            ...List.generate(suggestions.length, (i) {
              final s = suggestions[i];
              final isSelected = _selectedStationId == s.station.id;
              final pin = StationPin(
                brand: s.station.brand,
                selected: isSelected || i == 0,
                size: isSelected || i == 0 ? 56 : 40,
              );
              return Marker(
                point: LatLng(s.station.latitude, s.station.longitude),
                width: pin.boxSize,
                height: pin.boxSize,
                alignment: pin.markerAlignment,
                child: GestureDetector(
                  onTap: () => _onSuggestionTap(s.station),
                  child: pin,
                ),
              );
            }),
          ]),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(
      RoutePlannerLoaded state, List<RouteStationSuggestion> suggestions) {
    if (state.suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 32, color: AppTheme.borderColor),
              const SizedBox(height: 8),
              Text(
                'Nessun distributore trovato entro '
                '${AppConstants.routeCorridorKm.toStringAsFixed(0)} km dal percorso '
                'per il carburante scelto.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 12.5, color: AppTheme.textSecondaryColor),
              ),
            ],
          ),
        ),
      );
    }

    if (suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_alt_off_outlined,
                  size: 32, color: AppTheme.borderColor),
              const SizedBox(height: 8),
              Text(
                'Nessun distributore di questi brand lungo il percorso.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 12.5, color: AppTheme.textSecondaryColor),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _selectedBrands = []),
                child: const Text('Rimuovi filtro brand'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _listScrollController,
      padding: const EdgeInsets.all(12),
      itemCount: suggestions.length,
      itemBuilder: (ctx, index) {
        final suggestion = suggestions[index];
        final key =
            _cardKeys.putIfAbsent(suggestion.station.id, () => GlobalKey());
        return Padding(
          key: key,
          padding: const EdgeInsets.only(bottom: 10),
          child: RouteStationCard(
            suggestion: suggestion,
            rank: index + 1,
            isSelected: _selectedStationId == suggestion.station.id,
            isWaypoint: state.waypointStation?.id == suggestion.station.id,
            onTap: () => _openStationDetail(suggestion.station),
            onAddWaypoint: () => _addWaypoint(suggestion.station),
            onRemoveWaypoint: _removeWaypoint,
          ),
        );
      },
    );
  }
}

class _EndpointDot extends StatelessWidget {
  final Color color;
  const _EndpointDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 4),
        ],
      ),
    );
  }
}
