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
import 'package:mappa_prezzi_benzina/core/services/geocoding_service.dart';

const _kDesktopBreakpoint = 768.0;
const _kCardSpacing = 10.0;

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final ScrollController _listScrollController = ScrollController();

  List<String> _selectedFuelTypes = ['Benzina', 'Diesel'];
  List<String> _selectedBrands = [];
  String _sortBy = 'distance';

  Timer? _refreshTimer;
  LatLng? _lastLoadedCenter;

  final Map<String, GlobalKey> _stationKeys = {};

  bool _searchActive = false;
  final TextEditingController _searchController = TextEditingController();
  List<GeocodingResult> _searchResults = [];
  Timer? _searchDebounce;
  bool _searchLoading = false;

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

  double _getVisibleRadiusKm() {
    try {
      final bounds = _mapController.camera.visibleBounds;
      final radiusMeters = const Distance().as(
            LengthUnit.Meter,
            bounds.northWest,
            bounds.southEast,
          ) /
          2;
      return (radiusMeters / 1000).clamp(5.0, 200.0);
    } catch (_) {
      return AppConstants.stationSearchRadius;
    }
  }

  void _searchThisArea() {
    final center = _mapController.camera.center;
    _lastLoadedCenter = center;
    context.read<MapBloc>().add(LoadNearbyStationsEvent(
          location: UserLocation(
            latitude: center.latitude,
            longitude: center.longitude,
            timestamp: DateTime.now(),
          ),
          radiusKm: _getVisibleRadiusKm(),
        ));
  }

  /// Click sul marker della mappa:
  /// - seleziona stazione nel bloc
  /// - scrolla la lista alla card corrispondente
  /// - NON apre il dettaglio
  void _onMarkerTap(GasStation station, List<GasStation> filteredStations) {
    context.read<MapBloc>().add(SelectStationEvent(station));

    // Centra mappa sul marker
    _mapController.move(
      LatLng(station.latitude, station.longitude),
      _mapController.camera.zoom,
    );

    // Scrolla la lista esattamente sulla card, indipendentemente dall'altezza
    final key = _stationKeys[station.id];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  /// Click sulla card nella lista:
  /// 1. Pinna il marker sulla mappa (seleziona + centra)
  /// 2. Apre dettaglio full screen
  void _onCardTap(BuildContext context, GasStation station, MapLoaded state) {
    // Seleziona nel bloc → marker diventa ambra
    context.read<MapBloc>().add(SelectStationEvent(station));

    // Centra la mappa sul marker con zoom ravvicinato
    try {
      _mapController.move(
        LatLng(station.latitude, station.longitude),
        15.0,
      );
    } catch (_) {}

    // Apre il dettaglio full screen
    Navigator.pushNamed(
      context,
      '/station-detail',
      arguments: {
        'station': station,
        'userLocation': state.userLocation,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= _kDesktopBreakpoint;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          BlocListener<LocationBloc, LocationState>(
            listener: (context, state) {
              if (state is LocationLoaded) {
                _lastLoadedCenter =
                    LatLng(state.location.latitude, state.location.longitude);
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
                if (state is MapInitial ||
                    (state is MapLoading && _lastLoadedCenter == null)) {
                  return _buildSplash();
                }
                if (state is MapError && _lastLoadedCenter == null) {
                  return _buildError(state.message);
                }
                final loaded = state is MapLoaded
                    ? state
                    : MapLoaded(
                        stations: (state as MapLoading).stations,
                        userLocation: state.userLocation,
                        selectedStation: state.selectedStation,
                      );
                return isDesktop
                    ? _buildDesktopLayout(loaded)
                    : _buildMobileLayout(loaded);
              },
            ),
          ),
          if (_searchActive) ...[
            Positioned.fill(
              top: 56,
              child: GestureDetector(
                onTap: _deactivateSearch,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
            if (_searchResults.isNotEmpty || _searchLoading)
              Positioned(
                top: 60,
                left: 8,
                right: 8,
                child: _buildSearchResults(),
              ),
          ],
        ],
      ),
    );
  }

  // ─── Splash ────────────────────────────────────────────────────────────────

  Widget _buildSplash() {
    return Container(
      color: AppTheme.backgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Image.asset(
                'assets/icons/logo.png',
                width: 36,
                height: 36,
                fit: BoxFit.contain,
              ),

            ),
            const SizedBox(height: 20),
            Text(AppConstants.appName,
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor)),
            const SizedBox(height: 8),
            Text('Caricamento in corso...',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: AppTheme.textSecondaryColor)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }

  // ─── Error ─────────────────────────────────────────────────────────────────

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 16, color: AppTheme.textPrimaryColor)),
            const SizedBox(height: 24),
            ElevatedButton(
                onPressed: _requestLocationAndLoadStations,
                child: const Text('Riprova')),
          ],
        ),
      ),
    );
  }

  // ─── DESKTOP layout ────────────────────────────────────────────────────────

  Widget _buildDesktopLayout(MapLoaded state) {
    final stations = _filterAndSortStations(state.stations);

    return Column(
      children: [
        _buildAppBar(state, stations.length),
        Expanded(
          child: Row(
            children: [
              // ── Lista sinistra ──────────────────────────────────────────
              Container(
                width: 380,
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceColor,
                  border:
                      Border(right: BorderSide(color: AppTheme.borderColor)),
                ),
                child: Column(
                  children: [
                    // Header lista
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      decoration: const BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: AppTheme.borderColor)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.format_list_bulleted,
                              size: 15, color: AppTheme.textSecondaryColor),
                          const SizedBox(width: 8),
                          Text(
                            '${stations.length} distributori',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          const Spacer(),
                          // Hint: click card = dettaglio
                          Text(
                            'Tap per dettaglio →',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppTheme.borderColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Lista scrollabile verticalmente
                    Expanded(
                      child: stations.isEmpty
                          ? _buildEmptyList()
                          : ListView.builder(
                              controller: _listScrollController,
                              padding: const EdgeInsets.all(12),
                              itemCount: stations.length,
                              itemBuilder: (context, index) {
                                final station = stations[index];
                                final isSelected =
                                    state.selectedStation?.id == station.id;
                                final key = _stationKeys.putIfAbsent(
                                    station.id, () => GlobalKey());
                                return Padding(
                                  key: key,
                                  padding: const EdgeInsets.only(
                                      bottom: _kCardSpacing),
                                  child: _DesktopStationCard(
                                    station: station,
                                    userLocation: state.userLocation,
                                    isSelected: isSelected,
                                    onTap: () =>
                                        _onCardTap(context, station, state),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),

              // ── Mappa destra ────────────────────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    _buildMap(state, stations),
                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Center(child: _buildSearchAreaButton()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── MOBILE layout ─────────────────────────────────────────────────────────

  Widget _buildMobileLayout(MapLoaded state) {
    final stations = _filterAndSortStations(state.stations);

    return Column(
      children: [
        _buildAppBar(state, stations.length),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                bottom: 260,
                child: _buildMap(state, stations),
              ),
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(child: _buildSearchAreaButton()),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildMobileBottomList(state, stations),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar(MapLoaded state, int count) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _searchActive
          ? _buildSearchField()
          : Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    'assets/icons/logo.png',
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  AppConstants.appName,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const Spacer(),
                if (count > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppTheme.secondaryColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      '$count trovati',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                _iconBtn(Icons.search_rounded, 'Cerca zona', _activateSearch),
                _iconBtn(Icons.tune_rounded, 'Filtri', _showFilterBottomSheet),
                _iconBtn(Icons.refresh_rounded, 'Aggiorna', () {
                  context.read<MapBloc>().add(const RefreshStationsEvent());
                }),
                if (state.userLocation != null)
                  _iconBtn(Icons.my_location_rounded, 'La mia posizione', () {
                    final loc = state.userLocation!;
                    _mapController.move(
                        LatLng(loc.latitude, loc.longitude), 14);
                  }),
              ],
            ),
    );
  }

  // ─── Ricerca zona ───────────────────────────────────────────────────────────

  void _activateSearch() {
    setState(() {
      _searchActive = true;
      _searchResults = [];
      _searchLoading = false;
    });
  }

  void _deactivateSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchActive = false;
      _searchResults = [];
      _searchLoading = false;
    });
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _searchLoading = false;
      });
      return;
    }
    setState(() => _searchLoading = true);
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await GeocodingService.search(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _searchLoading = false;
        });
      }
    });
  }

  void _onResultSelected(GeocodingResult result) {
    _deactivateSearch();
    final target = LatLng(result.lat, result.lon);
    _lastLoadedCenter = target;
    try {
      _mapController.move(target, 13.0);
    } catch (_) {}
    context.read<MapBloc>().add(LoadNearbyStationsEvent(
          location: UserLocation(
            latitude: result.lat,
            longitude: result.lon,
            timestamp: DateTime.now(),
          ),
          radiusKm: 15.0,
        ));
  }

  Widget _buildSearchField() {
    return Row(
      children: [
        const Icon(Icons.search_rounded,
            size: 20, color: AppTheme.textSecondaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: _onSearchChanged,
            onSubmitted: (v) {
              if (_searchResults.isNotEmpty) {
                _onResultSelected(_searchResults.first);
              }
            },
            decoration: InputDecoration(
              hintText: 'Cerca una zona...',
              hintStyle: GoogleFonts.poppins(
                  fontSize: 14, color: AppTheme.textSecondaryColor),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: GoogleFonts.poppins(
                fontSize: 14, color: AppTheme.textPrimaryColor),
            textInputAction: TextInputAction.search,
          ),
        ),
        const SizedBox(width: 8),
        if (_searchLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (_searchController.text.isNotEmpty)
          GestureDetector(
            onTap: () {
              _searchController.clear();
              setState(() {
                _searchResults = [];
                _searchLoading = false;
              });
            },
            child: const Icon(Icons.clear_rounded,
                size: 18, color: AppTheme.textSecondaryColor),
          ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _deactivateSearch,
          child: Text(
            'Annulla',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: AppTheme.surfaceColor,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_searchLoading && _searchResults.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ..._searchResults.map(_buildResultTile),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTile(GeocodingResult result) {
    return InkWell(
      onTap: () => _onResultSelected(result),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined,
                size: 20, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    result.name,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  if (result.subtitle.isNotEmpty)
                    Text(
                      result.subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: AppTheme.textSecondaryColor),
        ),
      ),
    );
  }

  // ─── Mappa ─────────────────────────────────────────────────────────────────

  Widget _buildMap(MapLoaded state, List<GasStation> stations) {
    final userLocation = state.userLocation;
    return ClipRect(
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: userLocation != null
              ? LatLng(userLocation.latitude, userLocation.longitude)
              : const LatLng(
                  AppConstants.defaultLatitude, AppConstants.defaultLongitude),
          initialZoom: userLocation != null ? 13 : AppConstants.defaultZoom,
          maxZoom: 18,
          minZoom: 5,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
          if (userLocation != null)
            MarkerLayer(markers: [
              Marker(
                point: LatLng(userLocation.latitude, userLocation.longitude),
                width: 44,
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child:
                      const Icon(Icons.person, color: Colors.white, size: 20),
                ),
              ),
            ]),
          MarkerLayer(
            markers: stations.map((station) {
              final isSelected = state.selectedStation?.id == station.id;
              return Marker(
                point: LatLng(station.latitude, station.longitude),
                width: isSelected ? 48 : 40,
                height: isSelected ? 48 : 40,
                child: GestureDetector(
                  // Click marker → evidenzia nella lista, NON apre dettaglio
                  onTap: () => _onMarkerTap(station, stations),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accentColor
                          : AppTheme.secondaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: isSelected ? 3 : 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isSelected
                                  ? AppTheme.accentColor
                                  : AppTheme.secondaryColor)
                              .withOpacity(0.5),
                          blurRadius: isSelected ? 14 : 6,
                          spreadRadius: isSelected ? 3 : 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.local_gas_station,
                      color: Colors.white,
                      size: isSelected ? 22 : 18,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Mobile bottom list ────────────────────────────────────────────────────

  Widget _buildMobileBottomList(MapLoaded state, List<GasStation> stations) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                const Spacer(),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.local_gas_station,
                    size: 13, color: AppTheme.textSecondaryColor),
                const SizedBox(width: 6),
                Text(
                  '${stations.length} distributori nell\'area',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: stations.isEmpty
                ? _buildEmptyList()
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: stations.length,
                    itemBuilder: (context, index) {
                      final station = stations[index];
                      final isSelected =
                          state.selectedStation?.id == station.id;
                      return SizedBox(
                        width: 280,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: StationCard(
                            station: station,
                            userLocation: state.userLocation,
                            isSelected: isSelected,
                            // Su mobile: click card → dettaglio
                            onTap: () => _onCardTap(context, station, state),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildEmptyList() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 32, color: AppTheme.borderColor),
          const SizedBox(height: 8),
          Text(
            'Nessun distributore\nnell\'area visibile',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppTheme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAreaButton() {
    return GestureDetector(
      onTap: _searchThisArea,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 15, color: AppTheme.primaryColor),
            const SizedBox(width: 6),
            Text('Cerca in questa zona',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor)),
          ],
        ),
      ),
    );
  }

  // 'Diesel HVO' nel filtro copre anche stazioni con prezzo 'HVO' puro
  static List<String> _expandFuelTypes(List<String> selected) => [
        for (final ft in selected)
          ...({'Diesel HVO': ['Diesel HVO', 'HVO']}[ft] ?? [ft]),
      ];

  List<GasStation> _filterAndSortStations(List<GasStation> stations) {
    final effectiveTypes = _expandFuelTypes(_selectedFuelTypes);

    final filtered = stations.where((s) {
      final fuelMatch = s.prices.isEmpty ||
          effectiveTypes.any((ft) => s.prices.containsKey(ft));
      final brandMatch = _selectedBrands.isEmpty ||
          (s.brand != null && _selectedBrands.contains(s.brand));
      return fuelMatch && brandMatch;
    }).toList();

    switch (_sortBy) {
      case 'price':
        filtered.sort((a, b) {
          final pa = _relevantPrice(a, effectiveTypes);
          final pb = _relevantPrice(b, effectiveTypes);
          return pa.compareTo(pb);
        });
        break;
      case 'rating':
        filtered.sort(
            (a, b) => (b.averageRating ?? 0).compareTo(a.averageRating ?? 0));
        break;
      default:
        break;
    }
    return filtered;
  }

  /// Calcola il prezzo rilevante per l'ordinamento in base ai filtri attivi.
  ///
  /// - 1 tipo selezionato  → prezzo esatto di quel tipo
  /// - N tipi selezionati  → minore tra i tipi selezionati presenti
  /// - Nessun tipo selezionato → prezzo medio di tutti i carburanti disponibili
  ///   (logica neutra: non privilegia né benzina né diesel)
  double _relevantPrice(GasStation station, List<String> selectedFuels) {
    if (station.prices.isEmpty) return double.infinity;

    if (selectedFuels.isEmpty) {
      // Nessun filtro → media di tutti i prezzi
      final values = station.prices.values.toList();
      return values.reduce((a, b) => a + b) / values.length;
    }

    // Prezzi dei soli carburanti selezionati e presenti in questa stazione
    final relevant = selectedFuels
        .where((ft) => station.prices.containsKey(ft))
        .map((ft) => station.prices[ft]!)
        .toList();

    if (relevant.isEmpty) return double.infinity;

    // Se è selezionato un solo tipo → quel prezzo esatto
    // Se sono selezionati più tipi → il più basso tra quelli selezionati
    return relevant.reduce((a, b) => a < b ? a : b);
  }

  void _loadNearbyStations(UserLocation location) {
    context.read<MapBloc>().add(LoadNearbyStationsEvent(
          location: location,
          radiusKm: AppConstants.stationSearchRadius,
        ));
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
        content: const Text('Attiva i servizi di posizione per continuare.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppTheme.errorColor,
    ));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }
}

// ─── Card desktop con freccia "apri dettaglio" ─────────────────────────────────
// Wrapper di StationCard che aggiunge un hint visivo che indica
// che il click apre il dettaglio completo

class _DesktopStationCard extends StatelessWidget {
  final GasStation station;
  final UserLocation? userLocation;
  final bool isSelected;
  final VoidCallback onTap;

  const _DesktopStationCard({
    required this.station,
    required this.userLocation,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StationCard(
          station: station,
          userLocation: userLocation,
          isSelected: isSelected,
          onTap: onTap,
        ),
        // Badge "dettaglio →" sempre visibile — evidenziato quando selezionata
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Dettaglio',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.arrow_forward,
                    size: 10,
                    color: isSelected ? Colors.white : AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
