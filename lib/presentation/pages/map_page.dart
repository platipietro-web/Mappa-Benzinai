import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/domain/entities/gas_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/map_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/location_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';
import 'package:mappa_prezzi_benzina/presentation/widgets/station_card.dart';
import 'package:mappa_prezzi_benzina/presentation/widgets/filter_bottom_sheet.dart';

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();

  List<String> _selectedFuelTypes = ['Benzina', 'Diesel'];
  List<String> _selectedBrands = [];
  String _sortBy = 'distance';

  Timer? _refreshTimer;
  Timer? _mapMoveDebounce;

  // Ultima posizione del centro mappa usata per caricare stazioni
  LatLng? _lastLoadedCenter;

  @override
  void initState() {
    super.initState();
    _requestLocationAndLoadStations();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      context.read<MapBloc>().add(const RefreshStationsEvent());
    });
  }

  void _requestLocationAndLoadStations() {
    context.read<LocationBloc>().add(const RequestLocationPermissionEvent());
  }

  /// Calcola il raggio in km che copre i bounds visibili della mappa
  double _getVisibleRadiusKm() {
    try {
      final bounds = _mapController.camera.visibleBounds;
      final distance = const Distance();
      final radiusMeters = distance.as(
        LengthUnit.Meter,
        bounds.northWest,
        bounds.southEast,
      ) / 2;
      // Minimo 5 km, massimo 200 km
      return (radiusMeters / 1000).clamp(5.0, 200.0);
    } catch (_) {
      return AppConstants.stationSearchRadius;
    }
  }

  /// Carica stazioni centrate sul punto visibile della mappa
  void _loadStationsAtCenter(LatLng center) {
    // Evita ricariche se ci si è spostati meno di 1 km
    if (_lastLoadedCenter != null) {
      final dist = const Distance().as(
        LengthUnit.Kilometer,
        _lastLoadedCenter!,
        center,
      );
      if (dist < 1.0) return;
    }

    _lastLoadedCenter = center;
    final radius = _getVisibleRadiusKm();

    context.read<MapBloc>().add(
          LoadNearbyStationsEvent(
            location: UserLocation(
              latitude: center.latitude,
              longitude: center.longitude,
              timestamp: DateTime.now(),
            ),
            radiusKm: radius,
          ),
        );
  }

  /// Callback chiamato ogni volta che la mappa finisce di muoversi
  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd ||
        event is MapEventScrollWheelZoom ||
        event is MapEventDoubleTapZoom ||
        event is MapEventFlingAnimationEnd) {
      // Debounce: aspetta 600ms prima di caricare (evita troppe chiamate)
      _mapMoveDebounce?.cancel();
      _mapMoveDebounce = Timer(const Duration(milliseconds: 600), () {
        final center = _mapController.camera.center;
        _loadStationsAtCenter(center);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppConstants.appName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showFilterBottomSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<MapBloc>().add(const RefreshStationsEvent());
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocListener<LocationBloc, LocationState>(
        listener: (context, state) {
          if (state is LocationLoaded) {
            _lastLoadedCenter = LatLng(
              state.location.latitude,
              state.location.longitude,
            );
            _loadNearbyStations(state.location);
          } else if (state is LocationPermissionDenied) {
            _showLocationDeniedDialog();
          } else if (state is LocationServiceDisabled) {
            _showLocationDisabledDialog();
          } else if (state is LocationError) {
            _showErrorSnackbar(state.message);
          }
        },
        child: BlocBuilder<MapBloc, MapState>(
          builder: (context, state) {
            if (state is MapLoading && _lastLoadedCenter == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is MapError && _lastLoadedCenter == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: AppTheme.errorColor),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _requestLocationAndLoadStations,
                      child: const Text('Riprova'),
                    ),
                  ],
                ),
              );
            }

            if (state is MapLoaded) {
              return _buildMapView(state);
            }

            // Stato iniziale / loading dopo primo caricamento
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Widget _buildMapView(MapLoaded state) {
    final userLocation = state.userLocation;
    final stations = _filterAndSortStations(state.stations);

    return Stack(
      children: [
        // ── Mappa ──────────────────────────────────────────────────────────
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: userLocation != null
                ? LatLng(userLocation.latitude, userLocation.longitude)
                : const LatLng(
                    AppConstants.defaultLatitude,
                    AppConstants.defaultLongitude,
                  ),
            initialZoom: userLocation != null ? 13 : AppConstants.defaultZoom,
            maxZoom: 18,
            minZoom: 5,
            // Carica nuove stazioni ad ogni fine movimento
            onMapEvent: _onMapEvent,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            ),
            // Marker posizione utente
            if (userLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(
                        userLocation.latitude, userLocation.longitude),
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppTheme.primaryColor.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.location_on,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            // Marker distributori
            MarkerLayer(
              markers: stations.map((station) {
                final isSelected =
                    state.selectedStation?.id == station.id;
                return Marker(
                  point: LatLng(station.latitude, station.longitude),
                  width: 44,
                  height: 44,
                  child: GestureDetector(
                    onTap: () {
                      context
                          .read<MapBloc>()
                          .add(SelectStationEvent(station));
                      Navigator.pushNamed(
                        context,
                        '/station-detail',
                        arguments: {
                          'station': station,
                          'userLocation': state.userLocation,
                        },
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accentColor
                            : AppTheme.secondaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isSelected
                                    ? AppTheme.accentColor
                                    : AppTheme.secondaryColor)
                                .withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.local_gas_station,
                          color: Colors.white, size: 20),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // ── Indicatore caricamento in overlay (non blocca la mappa) ────────
        if (state is MapLoading)
          const Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Card(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Caricamento stazioni...'),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ── Bottom sheet stazioni ───────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    spreadRadius: 1),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Contatore stazioni
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Text(
                        '${stations.length} distributori nell\'area',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 260,
                  child: stations.isEmpty
                      ? Center(
                          child: Text(
                            'Nessun distributore trovato\nSposta la mappa per cercare',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                              16, 0, 16, 16),
                          itemCount: stations.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final station = stations[index];
                            return StationCard(
                              station: station,
                              userLocation: state.userLocation,
                              isSelected: state.selectedStation?.id ==
                                  station.id,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/station-detail',
                                  arguments: {
                                    'station': station,
                                    'userLocation': state.userLocation,
                                  },
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<GasStation> _filterAndSortStations(List<GasStation> stations) {
    final filtered = stations.where((station) {
      final fuelMatch = station.prices.isEmpty ||
          _selectedFuelTypes
              .any((ft) => station.prices.containsKey(ft));
      final brandMatch = _selectedBrands.isEmpty ||
          (station.brand != null &&
              _selectedBrands.contains(station.brand));
      return fuelMatch && brandMatch;
    }).toList();

    switch (_sortBy) {
      case 'price':
        filtered.sort((a, b) {
          final pa = a.prices.values.isNotEmpty
              ? a.prices.values.reduce((v, e) => v < e ? v : e)
              : double.infinity;
          final pb = b.prices.values.isNotEmpty
              ? b.prices.values.reduce((v, e) => v < e ? v : e)
              : double.infinity;
          return pa.compareTo(pb);
        });
        break;
      case 'rating':
        filtered.sort((a, b) =>
            (b.averageRating ?? 0).compareTo(a.averageRating ?? 0));
        break;
      case 'distance':
      default:
        break;
    }

    return filtered;
  }

  void _loadNearbyStations(UserLocation location) {
    context.read<MapBloc>().add(
          LoadNearbyStationsEvent(
            location: location,
            radiusKm: AppConstants.stationSearchRadius,
          ),
        );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => FilterBottomSheet(
        selectedFuelTypes: _selectedFuelTypes,
        selectedBrands: _selectedBrands,
        sortBy: _sortBy,
        onApply: (fuelTypes, brands, sortBy) {
          setState(() {
            _selectedFuelTypes = fuelTypes;
            _selectedBrands = brands;
            _sortBy = sortBy;
          });
        },
      ),
    );
  }

  void _showLocationDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permesso posizione'),
        content: const Text(
            'Il permesso di posizione è necessario per mostrare i distributori vicini.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _requestLocationAndLoadStations();
            },
            child: const Text('Riprova'),
          ),
        ],
      ),
    );
  }

  void _showLocationDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Posizione disabilitata'),
        content: const Text(
            'Attiva i servizi di posizione per continuare.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK')),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapMoveDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }
}