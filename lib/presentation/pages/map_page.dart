import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/domain/entities/gas_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/auth_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/favorites_bloc.dart';
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
  Timer? _panDebounce;
  LatLng? _lastLoadedCenter;
  // Raggio dell'ultima query effettuata (km). Usato per sapere se il viewport
  // corrente è già coperto dai dati in cache senza bisogno di ricaricare.
  double _lastLoadedRadiusKm = 0;

  final Map<String, GlobalKey> _stationKeys = {};
  final ScrollController _mobileScrollController = ScrollController();

  // Stazione da evidenziare/centrare solo quando si naviga dai preferiti.
  // null in tutti gli altri casi → il BlocListener non sposta la telecamera.
  GasStation? _pendingHighlightStation;

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
    // Ricarica preferiti al mount della mappa (gestisce il refresh pagina web
    // in cui l'auth è già ripristinata prima che il BlocListener in main scatti)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Leggi stazione da evidenziare passata dai preferiti
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final pending = args?['highlightStation'] as GasStation?;
      if (pending != null) {
        setState(() => _pendingHighlightStation = pending);
      }

      // Ricarica preferiti (gestisce il refresh pagina web in cui
      // l'auth è già ripristinata prima che il BlocListener in main scatti)
      final authState = context.read<AuthBloc>().state;
      if (authState is Authenticated && !authState.isAnonymous) {
        final favState = context.read<FavoritesBloc>().state;
        if (favState.ids.isEmpty && !favState.isLoading) {
          context
              .read<FavoritesBloc>()
              .add(LoadFavoritesEvent(authState.userId));
        }
      }
    });
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
    final radius = _getVisibleRadiusKm();
    _lastLoadedCenter = center;
    _lastLoadedRadiusKm = radius;
    context.read<MapBloc>().add(LoadNearbyStationsEvent(
          location: UserLocation(
            latitude: center.latitude,
            longitude: center.longitude,
            timestamp: DateTime.now(),
          ),
          radiusKm: radius,
        ));
  }

  // ── Verifica copertura viewport ──────────────────────────────────────────
  // Controlla se tutti e 4 gli angoli del viewport corrente sono già coperti
  // dall'ultima query eseguita (centro + raggio). Se anche un solo angolo è
  // fuori → i dati potrebbero mancare → ricarica necessaria.
  // Buffer 15%: inizia a ricaricare un po' prima di toccare il bordo assoluto.
  bool _isViewportCovered() {
    if (_lastLoadedCenter == null || _lastLoadedRadiusKm <= 0) return false;
    try {
      final bounds = _mapController.camera.visibleBounds;
      const dist = Distance();
      final corners = [
        bounds.northWest,
        bounds.northEast,
        bounds.southWest,
        bounds.southEast,
      ];
      for (final corner in corners) {
        final d = dist.as(LengthUnit.Kilometer, _lastLoadedCenter!, corner);
        if (d > _lastLoadedRadiusKm * 0.85) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Auto-search al movimento della mappa ─────────────────────────────────
  // Intercetta solo eventi utente (drag/fling/zoom), ignora mosse programmatiche.
  // Guards: debounce 800ms + zoom minimo 8 + viewport coverage check.
  void _onMapEvent(MapEvent event) {
    // 1. Ignora mosse programmatiche (marker tap, geocoding, highlight preferiti)
    if (event.source == MapEventSource.mapController) return;

    // 2. Intercetta solo fine-movimento (non ogni frame del pan)
    final isEndEvent = event is MapEventMoveEnd ||
        event is MapEventFlingAnimationEnd ||
        event is MapEventDoubleTapZoomEnd ||
        event is MapEventScrollWheelZoom;
    if (!isEndEvent) return;

    // 3. Debounce: annulla il timer precedente e riparte
    _panDebounce?.cancel();
    _panDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      // 4. Guard zoom: sotto 8 l'area è troppo grande, saltiamo
      final zoom = _mapController.camera.zoom;
      if (zoom < 8.0) return;

      // 5. Guard viewport: se tutti gli angoli sono già coperti dai dati
      //    in cache, non serve fare una nuova query
      if (_isViewportCovered()) return;

      // 6. Viewport scoperto → carica le stazioni nella nuova area
      _searchThisArea();
    });
  }

  /// Click sul marker della mappa:
  /// - seleziona stazione nel bloc
  /// - scrolla la lista alla card corrispondente
  /// - NON apre il dettaglio
  void _onMarkerTap(GasStation station) {
    context.read<MapBloc>().add(SelectStationEvent(station));

    // Centra mappa sul marker
    _mapController.move(
      LatLng(station.latitude, station.longitude),
      _mapController.camera.zoom,
    );
    // Lo scroll nella lista è gestito dal BlocListener su MapBloc,
    // che scatta dopo che il nuovo stato è propagato e la lista ricostruita.
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
          MultiBlocListener(
            listeners: [
              BlocListener<LocationBloc, LocationState>(
                listener: (context, state) {
                  if (state is LocationLoaded) {
                    _lastLoadedCenter = LatLng(
                        state.location.latitude, state.location.longitude);
                    _lastLoadedRadiusKm = AppConstants.stationSearchRadius;
                    _loadNearbyStations(state.location);
                  } else if (state is LocationPermissionDenied) {
                    _showLocationDeniedDialog();
                  } else if (state is LocationServiceDisabled) {
                    _showLocationDisabledDialog();
                  } else if (state is LocationError) {
                    _showErrorSnackbar(state.message);
                  }
                },
              ),
              BlocListener<MapBloc, MapState>(
                listenWhen: (prev, curr) {
                  // Preferiti (via MapBloc): caricamento completato con stazione pending
                  if (prev is MapLoading &&
                      curr is MapLoaded &&
                      curr.pendingHighlightStation != null) {
                    return true;
                  }
                  // Preferiti (via route args, percorso legacy): locale pending + load completato
                  if (_pendingHighlightStation != null &&
                      prev is MapLoading &&
                      curr is MapLoaded) {
                    return true;
                  }
                  // Tap marker/selezione: selectedStation cambiato tra due MapLoaded
                  if (prev is MapLoaded && curr is MapLoaded) {
                    return curr.selectedStation != null &&
                        prev.selectedStation?.id != curr.selectedStation?.id;
                  }
                  return false;
                },
                listener: (context, state) {
                  final loaded = state as MapLoaded;

                  // ── Preferiti: seleziona + camera move ──────────────────
                  final station = loaded.pendingHighlightStation ??
                      _pendingHighlightStation;
                  if (station != null) {
                    setState(() => _pendingHighlightStation = null);
                    context
                        .read<MapBloc>()
                        .add(const ClearPendingHighlightStationEvent());
                    context.read<MapBloc>().add(SelectStationEvent(station));
                    try {
                      _mapController.move(
                        LatLng(station.latitude, station.longitude),
                        14.0,
                      );
                    } catch (_) {}
                    return;
                  }

                  // ── Tap marker / dopo SelectStationEvent preferiti ──────
                  final stationId = loaded.selectedStation?.id;
                  if (stationId == null) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToStationInList(
                      stationId,
                      _filterAndSortStations(loaded.stations,
                          userLocation: loaded.userLocation),
                    );
                  });
                },
              ),
            ],
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
    final stations = _filterAndSortStations(state.stations,
        userLocation: state.userLocation);

    return Column(
      children: [
        _buildAppBar(state),
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
                    // Lista scrollabile verticalmente — ListView non-lazy
                    // così ogni GlobalKey ha sempre un context valido
                    // e Scrollable.ensureVisible funziona sempre
                    Expanded(
                      child: stations.isEmpty
                          ? _buildEmptyList()
                          : ListView.builder(
                              controller: _listScrollController,
                              padding: const EdgeInsets.all(12),
                              itemCount: stations.length,
                              itemBuilder: (ctx, index) {
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
                      child: Center(child: _buildAutoLoadIndicator(state)),
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
    final stations = _filterAndSortStations(state.stations,
        userLocation: state.userLocation);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomSheetHeight = 280.0 + bottomInset;

    return SafeArea(
      top: true,
      bottom: false,
      child: Column(
        children: [
          _buildAppBar(state),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  bottom: bottomSheetHeight,
                  child: _buildMap(state, stations),
                ),

                // ── Indicatore auto-load (top center) ────────────────────────
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildAutoLoadIndicator(state)),
                ),

                // ── FAB controlli mappa (destra) ──────────────────────────────
                Positioned(
                  right: 12,
                  bottom: bottomSheetHeight + 16,
                  child: _buildMapControls(state),
                ),

                // ── Bottom sheet stazioni ─────────────────────────────────────
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildMobileBottomList(state, stations, bottomInset),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControls(MapLoaded state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Zoom +
        _mapFab(
          icon: Icons.add_rounded,
          tooltip: 'Zoom avanti',
          onTap: () {
            final z = (_mapController.camera.zoom + 1).clamp(5.0, 18.0);
            _mapController.move(_mapController.camera.center, z);
          },
        ),
        const SizedBox(height: 8),
        // Zoom −
        _mapFab(
          icon: Icons.remove_rounded,
          tooltip: 'Zoom indietro',
          onTap: () {
            final z = (_mapController.camera.zoom - 1).clamp(5.0, 18.0);
            _mapController.move(_mapController.camera.center, z);
          },
        ),
        const SizedBox(height: 8),
        // La mia posizione
        if (state.userLocation != null)
          _mapFab(
            icon: Icons.my_location_rounded,
            tooltip: 'La mia posizione',
            color: AppTheme.primaryColor,
            iconColor: Colors.white,
            onTap: () {
              final loc = state.userLocation!;
              _mapController.move(LatLng(loc.latitude, loc.longitude), 14);
            },
          ),
      ],
    );
  }

  Widget _mapFab({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = Colors.white,
    Color iconColor = const Color(0xFF374151),
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar(MapLoaded state) {
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
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Profilo',
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
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
    _lastLoadedRadiusKm = 15.0;
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
          onMapEvent: _onMapEvent,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
            userAgentPackageName: 'it.mappabenzinai.app',
          ),
          RichAttributionWidget(
            attributions: [
              TextSourceAttribution('© OpenStreetMap contributors'),
            ],
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
                  onTap: () => _onMarkerTap(station),
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

  Widget _buildMobileBottomList(
      MapLoaded state, List<GasStation> stations, double bottomInset) {
    return Container(
      height: 280 + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Drag handle ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // ── Header con contatore ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: BlocBuilder<MapBloc, MapState>(
              buildWhen: (p, c) => (p is MapLoading) != (c is MapLoading),
              builder: (ctx, mapState) {
                final loading = mapState is MapLoading;
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: loading
                            ? AppTheme.borderColor
                            : AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: loading
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Caricamento...',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_gas_station,
                                    size: 12, color: AppTheme.primaryColor),
                                const SizedBox(width: 5),
                                Text(
                                  '${stations.length} distributori',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const Spacer(),
                    Text(
                      'Scorri per vedere altri →',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppTheme.textSecondaryColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // ── Lista card orizzontale ─────────────────────────────────────
          Expanded(
            child: BlocBuilder<MapBloc, MapState>(
              buildWhen: (p, c) => (p is MapLoading) != (c is MapLoading),
              builder: (ctx, mapState) {
                final loading = mapState is MapLoading && stations.isEmpty;
                if (loading) {
                  return _buildSkeletonList();
                }
                if (stations.isEmpty) {
                  return _buildEmptyList();
                }
                return ListView.builder(
                  controller: _mobileScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.fromLTRB(12, 4, 12, 14 + bottomInset),
                  itemCount: stations.length,
                  itemBuilder: (context, index) {
                    final station = stations[index];
                    final isSelected = state.selectedStation?.id == station.id;
                    return SizedBox(
                      width: 280,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: StationCard(
                          station: station,
                          userLocation: state.userLocation,
                          isSelected: isSelected,
                          onTap: () => _onCardTap(context, station, state),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: 4,
      itemBuilder: (ctx, _) => SizedBox(
        width: 280,
        child: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: _SkeletonCard(),
        ),
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

  // Indicatore sottile visibile solo durante il caricamento automatico.
  // In stato MapLoading mostra uno spinner + label; altrimenti scompare
  // senza occupare spazio (SizedBox.shrink).
  Widget _buildAutoLoadIndicator(MapLoaded state) {
    // Usiamo il BlocBuilder già presente nel parent: qui riceviamo MapLoaded,
    // ma vogliamo mostrare l'indicatore anche durante MapLoading.
    // Soluzione: avvolgiamo in un BlocBuilder locale leggero.
    return BlocBuilder<MapBloc, MapState>(
      buildWhen: (prev, curr) => (prev is MapLoading) != (curr is MapLoading),
      builder: (context, mapState) {
        final isLoading = mapState is MapLoading;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: isLoading
              ? Container(
                  key: const ValueKey('loading'),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.10), blurRadius: 8),
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Aggiornamento area...',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('idle')),
        );
      },
    );
  }

  // 'Diesel HVO' nel filtro copre anche stazioni con prezzo 'HVO' puro
  static List<String> _expandFuelTypes(List<String> selected) => [
        for (final ft in selected)
          ...({
                'Diesel HVO': ['Diesel HVO', 'HVO']
              }[ft] ??
              [ft]),
      ];

  List<GasStation> _filterAndSortStations(
    List<GasStation> stations, {
    UserLocation? userLocation,
  }) {
    final effectiveTypes = _expandFuelTypes(_selectedFuelTypes);

    // ── Viewport filter ───────────────────────────────────────────────────
    List<GasStation> inView = stations;
    try {
      final bounds = _mapController.camera.visibleBounds;
      inView = stations
          .where((s) => bounds.contains(LatLng(s.latitude, s.longitude)))
          .toList();
    } catch (_) {}

    // ── Fuel / brand filter ───────────────────────────────────────────────
    final filtered = inView.where((s) {
      final fuelMatch = s.prices.isEmpty ||
          effectiveTypes.any((ft) => s.prices.containsKey(ft));
      final brandMatch = _selectedBrands.isEmpty ||
          (s.brand != null && _selectedBrands.contains(s.brand));
      return fuelMatch && brandMatch;
    }).toList();

    // ── Sort ──────────────────────────────────────────────────────────────
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
        // Ordinamento per distanza: pre-calcola UNA SOLA VOLTA per stazione
        // invece di chiamare Haversine O(n log n) volte nel comparator.
        if (userLocation != null) {
          final ulat = userLocation.latitude;
          final ulon = userLocation.longitude;
          final distCache = <String, double>{
            for (final s in filtered)
              s.id: s.getDistanceFromCoordinates(ulat, ulon),
          };
          filtered.sort(
              (a, b) => (distCache[a.id] ?? 0).compareTo(distCache[b.id] ?? 0));
        }
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

  /// Scrolla la lista alla card della stazione selezionata.
  /// Desktop: lista verticale con GlobalKey + Scrollable.ensureVisible.
  /// Mobile:  lista orizzontale con ScrollController + animateTo per indice.
  /// Logica condivisa di scroll: desktop usa GlobalKey + ensureVisible,
  /// mobile usa il controller della lista orizzontale + animateTo per indice.
  /// Deve essere chiamato dentro addPostFrameCallback per garantire che il
  /// BlocBuilder abbia già ricostruito la lista col nuovo stato.
  void _scrollToStationInList(
      String stationId, List<GasStation> visibleStations) {
    final isDesktop = MediaQuery.of(context).size.width >= _kDesktopBreakpoint;

    if (isDesktop) {
      final key = _stationKeys[stationId];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
    } else {
      if (!_mobileScrollController.hasClients) return;
      final index = visibleStations.indexWhere((s) => s.id == stationId);
      if (index < 0) return;
      const cardWidth = 290.0; // 280 card + 10 padding destro
      const leadingPadding = 12.0;
      final target = (leadingPadding + index * cardWidth).clamp(
        0.0,
        _mobileScrollController.position.maxScrollExtent,
      );
      _mobileScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _loadNearbyStations(UserLocation location) {
    context.read<MapBloc>().add(LoadNearbyStationsEvent(
          location: location,
          radiusKm: AppConstants.stationSearchRadius,
          isGpsLocation: true,
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
    _panDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    _listScrollController.dispose();
    _mobileScrollController.dispose();
    super.dispose();
  }
}

// ─── Skeleton card (loading placeholder) ──────────────────────────────────────
// Mostra una card grigia animata mentre le stazioni vengono caricate,
// eliminando il "salto" dal vuoto alla lista.

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, _) {
        final base = AppTheme.borderColor.withOpacity(_anim.value);
        return Card(
          elevation: 0,
          color: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nome
                Container(
                  height: 14,
                  width: 160,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 10),
                // Indirizzo
                Container(
                  height: 10,
                  width: 200,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(height: 6),
                // Distanza
                Container(
                  height: 10,
                  width: 80,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(height: 14),
                // Chip prezzi
                Row(
                  children: List.generate(
                    3,
                    (i) => Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 60,
                      height: 38,
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
