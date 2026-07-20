import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';   

import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/core/services/geocoding_service.dart';
import 'package:mappa_prezzi_benzina/core/services/service_error_logger.dart';
import 'package:mappa_prezzi_benzina/core/services/service_locator.dart';
import 'package:mappa_prezzi_benzina/domain/entities/car_wash.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';
import 'package:mappa_prezzi_benzina/features/carwash/carwash_bloc.dart';
import 'package:mappa_prezzi_benzina/features/carwash/carwash_map.dart';
import 'package:mappa_prezzi_benzina/features/carwash/carwash_service.dart';
import 'package:mappa_prezzi_benzina/features/carwash/carwash_favorites_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/auth_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/location_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';

const _kCarWashColor = Color(0xFF0891B2);
const _kDesktopBreakpoint = 768.0;

class CarWashScreen extends StatefulWidget {
  const CarWashScreen({Key? key}) : super(key: key);

  @override
  State<CarWashScreen> createState() => _CarWashScreenState();
}

class _CarWashScreenState extends State<CarWashScreen> {
  final MapController _mapController = MapController();
  final ScrollController _listScrollController = ScrollController();
  final ScrollController _mobileScrollController = ScrollController();
  Timer? _refreshTimer;
  LatLng? _lastLoadedCenter;
  bool _isImporting = false;

  // Search
  bool _searchActive = false;
  final TextEditingController _searchController = TextEditingController();
  List<GeocodingResult> _searchResults = [];
  Timer? _searchDebounce;
  bool _searchLoading = false;

  // List panel filter: 'all' | 'self' | 'auto' | 'vacuum'
  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLocation());
  }

  void _initLocation() {
    final locationState = context.read<LocationBloc>().state;
    if (locationState is LocationLoaded) {
      _lastLoadedCenter = LatLng(
        locationState.location.latitude,
        locationState.location.longitude,
      );
      final cwState = context.read<CarWashBloc>().state;
      if (cwState is CarWashInitial) {
        context.read<CarWashBloc>().add(LoadNearbyCarWashesEvent(
              location: locationState.location,
              radiusKm: AppConstants.stationSearchRadius,
              isGpsLocation: true,
            ));
        _silentOsmImport(
          LatLng(locationState.location.latitude,
              locationState.location.longitude),
          AppConstants.stationSearchRadius,
        );
      }
    } else if (locationState is! LocationLoading) {
      context.read<LocationBloc>().add(const RequestLocationPermissionEvent());
    }
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (mounted) {
        context.read<CarWashBloc>().add(const RefreshCarWashesEvent());
      }
    });
  }

  // ─── Search zone ───────────────────────────────────────────────────────────

  void _activateSearch() => setState(() {
        _searchActive = true;
        _searchResults = [];
        _searchLoading = false;
      });

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
    final loc = UserLocation(
      latitude: result.lat,
      longitude: result.lon,
      timestamp: DateTime.now(),
    );
    context.read<CarWashBloc>().add(
          LoadNearbyCarWashesEvent(location: loc, radiusKm: 15.0),
        );
    _silentOsmImport(target, 15.0);
  }

  Future<void> _silentOsmImport(LatLng center, double radiusKm) async {
    if (_isImporting) return;
    setState(() => _isImporting = true);
    try {
      final washes = await getIt<CarWashService>().importFromOsm(
        center.latitude,
        center.longitude,
        radiusKm,
      );
      if (!mounted) return;
      if (washes.isNotEmpty) {
        context.read<CarWashBloc>().add(AddMultipleCarWashesEvent(washes));
      }
    } on DioException catch (e) {
      // Silent per l'utente — non disturbarlo se OSM è temporaneamente
      // non disponibile — ma logga per accorgerci se inizia a bloccarci.
      ServiceErrorLogger.log('overpass',
          detail: e.response?.statusCode?.toString() ?? e.type.name);
    } catch (_) {
      // Silent — don't bother the user if OSM is temporarily unavailable
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
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
    final radius = _getVisibleRadiusKm();
    context.read<CarWashBloc>().add(LoadNearbyCarWashesEvent(
          location: UserLocation(
            latitude: center.latitude,
            longitude: center.longitude,
            timestamp: DateTime.now(),
          ),
          radiusKm: radius,
        ));
    _silentOsmImport(center, radius);
  }

  Future<void> _openMaps(double lat, double lon) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile aprire Maps')),
        );
      }
    }
  }

  Future<void> _confirmOpenMaps(double lat, double lon, String address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apri in Maps'),
        content: Text(address.isNotEmpty
            ? address
            : 'Vuoi aprire la posizione in Google Maps?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apri Maps'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _openMaps(lat, lon);
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'MappaBenzinai/1.0 (plati.pietro@gmail.com)',
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>?;
      if (addr == null) return null;
      final road = (addr['road'] ?? addr['pedestrian'] ?? addr['footway'] ?? '')
          as String;
      final number = (addr['house_number'] ?? '') as String;
      final city = (addr['city'] ??
          addr['town'] ??
          addr['village'] ??
          addr['municipality'] ??
          '') as String;
      final line1 = [road, number].where((s) => s.isNotEmpty).join(' ');
      return [line1, city].where((s) => s.isNotEmpty).join(', ');
    } catch (_) {
      return null;
    }
  }

  void _onMarkerTap(CarWash wash) {
    context.read<CarWashBloc>().add(SelectCarWashEvent(wash));
    try {
      _mapController.move(
          LatLng(wash.latitude, wash.longitude), _mapController.camera.zoom);
    } catch (_) {}
    _showWashDetails(wash);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
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
          BlocListener<LocationBloc, LocationState>(
            listener: (context, state) {
              if (state is LocationLoaded) {
                _lastLoadedCenter = LatLng(
                  state.location.latitude,
                  state.location.longitude,
                );
                final cwState = context.read<CarWashBloc>().state;
                if (cwState is CarWashInitial) {
                  context.read<CarWashBloc>().add(LoadNearbyCarWashesEvent(
                        location: state.location,
                        radiusKm: AppConstants.stationSearchRadius,
                        isGpsLocation: true,
                      ));
                }
              }
            },
            child: BlocConsumer<CarWashBloc, CarWashState>(
              listenWhen: (_, curr) => curr is CarWashError,
              listener: (context, state) {
                if (state is CarWashError) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(state.message),
                    backgroundColor: AppTheme.errorColor,
                  ));
                }
              },
              builder: (context, state) {
                if (state is CarWashInitial ||
                    (state is CarWashLoading && _lastLoadedCenter == null)) {
                  return _buildSplash();
                }
                if (state is CarWashError && _lastLoadedCenter == null) {
                  return _buildError(state.message);
                }

                final CarWashLoaded loaded;
                if (state is CarWashLoaded) {
                  loaded = state;
                } else if (state is CarWashLoading) {
                  loaded = CarWashLoaded(
                    washes: state.washes,
                    selectedWash: state.selectedWash,
                    userLocation: state.userLocation,
                  );
                } else {
                  // CarWashError with _lastLoadedCenter set — show empty map,
                  // snackbar is handled by the listener above.
                  loaded = const CarWashLoaded(washes: []);
                }

                final isDesktop =
                    MediaQuery.of(context).size.width >= _kDesktopBreakpoint;
                final filteredWashes =
                    _applyFiltersAndSort(loaded.washes, loaded.userLocation);
                return isDesktop
                    ? _buildDesktopLayout(loaded, filteredWashes)
                    : _buildMobileLayout(loaded, filteredWashes);
              },
            ),
          ),
        ],
      ),
    );
  }

  List<CarWash> _applyFiltersAndSort(
      List<CarWash> washes, UserLocation? userLocation) {
    var result = washes.where((w) {
      switch (_filterType) {
        case 'self':
          return w.type != 'automatic';
        case 'auto':
          return w.type != 'self-only';
        case 'vacuum':
          return w.hasVacuum == true;
        default:
          return true;
      }
    }).toList();
    if (userLocation != null) {
      result.sort((a, b) => a
          .getDistanceFromCoordinates(
              userLocation.latitude, userLocation.longitude)
          .compareTo(b.getDistanceFromCoordinates(
              userLocation.latitude, userLocation.longitude)));
    }
    return result;
  }

  // ─── Desktop layout ────────────────────────────────────────────────────────

  Widget _buildDesktopLayout(CarWashLoaded state, List<CarWash> washes) {
    return Column(
      children: [
        _buildAppBar(state),
        Expanded(
          child: Row(
            children: [
              Container(
                width: 380,
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceColor,
                  border:
                      Border(right: BorderSide(color: AppTheme.borderColor)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      decoration: const BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: AppTheme.borderColor)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_car_wash,
                                  size: 15, color: _kCarWashColor),
                              const SizedBox(width: 8),
                              Text(
                                '${washes.length} autolavaggi',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Tap per dettaglio →',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppTheme.borderColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildFilterBar(),
                        ],
                      ),
                    ),
                    Expanded(
                      child: washes.isEmpty
                          ? _buildEmptyList()
                          : ListView.builder(
                              controller: _listScrollController,
                              padding: const EdgeInsets.all(12),
                              itemCount: washes.length,
                              itemBuilder: (context, i) {
                                final wash = washes[i];
                                final isSelected =
                                    state.selectedWash?.id == wash.id;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _CarWashCard(
                                    wash: wash,
                                    userLocation: state.userLocation,
                                    isSelected: isSelected,
                                    onTap: () => _onMarkerTap(wash),
                                    onAddressTap:
                                        (wash.address?.isNotEmpty ?? false)
                                            ? () => _confirmOpenMaps(
                                                  wash.latitude,
                                                  wash.longitude,
                                                  wash.address ?? '',
                                                )
                                            : null,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CarWashMap(
                        mapController: _mapController,
                        washes: state.washes,
                        selectedWash: state.selectedWash,
                        userLocation: state.userLocation,
                        onMarkerTap: _onMarkerTap,
                      ),
                    ),
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

  // ─── Mobile layout ─────────────────────────────────────────────────────────

  Widget _buildMobileLayout(CarWashLoaded state, List<CarWash> washes) {
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
                  child: CarWashMap(
                    mapController: _mapController,
                    washes: state.washes,
                    selectedWash: state.selectedWash,
                    userLocation: state.userLocation,
                    onMarkerTap: _onMarkerTap,
                  ),
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
                  child: _buildMobileBottomPanel(state, washes, bottomInset),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBottomPanel(
      CarWashLoaded state, List<CarWash> washes, double bottomInset) {
    return Container(
      height: 280 + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
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
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _filterChip('all', 'Tutti', Icons.local_car_wash_outlined),
                const SizedBox(width: 6),
                _filterChip('self', 'Self-service', Icons.handyman_outlined),
                const SizedBox(width: 6),
                _filterChip('auto', 'Rulli', Icons.settings_outlined),
                const SizedBox(width: 6),
                _filterChip('vacuum', 'Aspirapolvere', Icons.air),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
            child: Row(
              children: [
                Icon(Icons.local_car_wash,
                    size: 13, color: _kCarWashColor.withOpacity(0.7)),
                const SizedBox(width: 6),
                Text(
                  '${washes.length} autolavaggi nell\'area',
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
            child: washes.isEmpty
                ? _buildEmptyList()
                : ListView.builder(
                    controller: _mobileScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.fromLTRB(12, 4, 12, 14 + bottomInset),
                    itemCount: washes.length,
                    itemBuilder: (context, i) {
                      final wash = washes[i];
                      final isSelected = state.selectedWash?.id == wash.id;
                      return SizedBox(
                        width: 260,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _CarWashCard(
                            wash: wash,
                            userLocation: state.userLocation,
                            isSelected: isSelected,
                            onTap: () => _onMarkerTap(wash),
                            onAddressTap: (wash.address?.isNotEmpty ?? false)
                                ? () => _confirmOpenMaps(
                                      wash.latitude,
                                      wash.longitude,
                                      wash.address ?? '',
                                    )
                                : null,
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

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('all', 'Tutti', Icons.local_car_wash_outlined),
          const SizedBox(width: 6),
          _filterChip('self', 'Self-service', Icons.handyman_outlined),
          const SizedBox(width: 6),
          _filterChip('auto', 'Rulli', Icons.settings_outlined),
          const SizedBox(width: 6),
          _filterChip('vacuum', 'Aspirapolvere', Icons.air),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, IconData icon) {
    final selected = _filterType == value;
    return GestureDetector(
      onTap: () => setState(() => _filterType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? _kCarWashColor : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _kCarWashColor : AppTheme.borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: selected ? Colors.white : AppTheme.textSecondaryColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyList() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 32, color: AppTheme.borderColor),
          const SizedBox(height: 8),
          Text(
            'Nessun autolavaggio\nnell\'area visibile',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppTheme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar(CarWashLoaded state) {
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
                    color: _kCarWashColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_car_wash,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Autolavaggio',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const Spacer(),
                _iconBtn(Icons.search_rounded, 'Cerca zona', _activateSearch),
                if (_isImporting)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kCarWashColor),
                    ),
                  ),
                _iconBtn(Icons.refresh_rounded, 'Aggiorna', () {
                  context
                      .read<CarWashBloc>()
                      .add(const RefreshCarWashesEvent());
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
            onSubmitted: (_) {
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
            onTap: () => setState(() {
              _searchController.clear();
              _searchResults = [];
              _searchLoading = false;
            }),
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
                size: 20, color: _kCarWashColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(result.name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimaryColor,
                      )),
                  if (result.subtitle.isNotEmpty)
                    Text(result.subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Widgets ───────────────────────────────────────────────────────────────

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
            const Icon(Icons.search_rounded, size: 15, color: _kCarWashColor),
            const SizedBox(width: 6),
            Text(
              'Cerca in questa zona',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kCarWashColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                color: _kCarWashColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.local_car_wash,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'Autolavaggio',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Caricamento in corso...',
              style: GoogleFonts.poppins(
                  fontSize: 14, color: AppTheme.textSecondaryColor),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: _kCarWashColor),
          ],
        ),
      ),
    );
  }

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
              onPressed: _initLocation,
              child: const Text('Riprova'),
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

  // ─── Bottom sheets ─────────────────────────────────────────────────────────

  void _showWashDetails(CarWash wash) {
    String? resolvedAddress = (wash.address != null && wash.address!.isNotEmpty)
        ? wash.address
        : null;
    bool isGeocoding = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          if (resolvedAddress == null && !isGeocoding) {
            isGeocoding = true;
            _reverseGeocode(wash.latitude, wash.longitude).then((addr) {
              if (!mounted) return;
              setSheetState(() {
                resolvedAddress = addr ?? '';
                isGeocoding = false;
              });
              if (addr != null && addr.isNotEmpty) {
                final updated = CarWash(
                  id: wash.id,
                  name: wash.name,
                  address: addr,
                  latitude: wash.latitude,
                  longitude: wash.longitude,
                  type: wash.type,
                  hasVacuum: wash.hasVacuum,
                  paymentType: wash.paymentType,
                  createdAt: wash.createdAt,
                );
                context.read<CarWashBloc>().add(UpdateCarWashEvent(updated));
              }
            });
          }

          return BlocBuilder<CarWashFavoritesBloc, CarWashFavoritesState>(
            builder: (ctx, favState) {
              final authState = ctx.read<AuthBloc>().state;
              final isLoggedIn =
                  authState is Authenticated && !authState.isAnonymous;
              final isFav = favState.isFavorite(wash.id);

              final addressText = isGeocoding
                  ? 'Recupero indirizzo...'
                  : (resolvedAddress != null && resolvedAddress!.isNotEmpty
                      ? resolvedAddress!
                      : 'Indirizzo non disponibile');

              return Container(
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.all(24),
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
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _kCarWashColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_car_wash,
                              color: _kCarWashColor, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            wash.name,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                        ),
                        if (isLoggedIn)
                          IconButton(
                            icon: Icon(
                              isFav
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isFav
                                  ? Colors.red
                                  : AppTheme.textSecondaryColor,
                            ),
                            tooltip: isFav
                                ? 'Rimuovi dai preferiti'
                                : 'Aggiungi ai preferiti',
                            onPressed: () {
                              ctx.read<CarWashFavoritesBloc>().add(
                                    ToggleCarWashFavoriteEvent(
                                      userId: authState.userId,
                                      carWash: wash,
                                    ),
                                  );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AppTheme.borderColor),
                    const SizedBox(height: 12),
                    _detailRow(
                      Icons.place_outlined,
                      addressText,
                      'Indirizzo',
                      onTap: isGeocoding
                          ? null
                          : () => _confirmOpenMaps(
                                wash.latitude,
                                wash.longitude,
                                resolvedAddress ?? '',
                              ),
                    ),
                    const SizedBox(height: 10),
                    if (wash.type == 'unknown' ||
                        wash.hasVacuum == null ||
                        wash.paymentType == 'unknown') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 16, color: Color(0xFFD97706)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Dati non verificati — le informazioni mostrate sono indicative. Aiutaci a tenerle aggiornate!',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _detailRow(
                      Icons.handyman_rounded,
                      wash.type != 'automatic'
                          ? 'Disponibile'
                          : 'Non disponibile',
                      'Self-service',
                    ),
                    const SizedBox(height: 10),
                    _detailRow(
                      Icons.settings_rounded,
                      wash.type != 'self-only'
                          ? 'Disponibile'
                          : 'Non disponibile',
                      'Automatico (rulli)',
                    ),
                    const SizedBox(height: 10),
                    _detailRow(
                      Icons.air,
                      wash.hasVacuum == false
                          ? 'Non disponibile'
                          : 'Disponibile',
                      'Aspirapolvere',
                    ),
                    const SizedBox(height: 10),
                    _detailRow(
                      Icons.payment,
                      _paymentLabel(wash.paymentType),
                      'Pagamento',
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: (wash.type == 'unknown' ||
                              wash.hasVacuum == null ||
                              wash.paymentType == 'unknown')
                          ? ElevatedButton.icon(
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text(
                                  'Verifica e segnala aggiornamento'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD97706),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _showReportForm(wash);
                              },
                            )
                          : OutlinedButton.icon(
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Segnala aggiornamento'),
                              onPressed: () {
                                Navigator.pop(context);
                                _showReportForm(wash);
                              },
                            ),
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _detailRow(IconData icon, String value, String label,
      {VoidCallback? onTap, bool isUnknown = false}) {
    final content = Row(
      children: [
        Icon(icon,
            size: 18,
            color: isUnknown
                ? AppTheme.textSecondaryColor.withOpacity(0.4)
                : AppTheme.textSecondaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppTheme.textSecondaryColor)),
              Text(value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isUnknown
                        ? AppTheme.textSecondaryColor.withOpacity(0.5)
                        : onTap != null
                            ? AppTheme.primaryColor
                            : AppTheme.textPrimaryColor,
                    fontStyle: isUnknown ? FontStyle.italic : FontStyle.normal,
                  )),
            ],
          ),
        ),
        if (onTap != null)
          Icon(Icons.navigation_rounded,
              size: 16, color: AppTheme.primaryColor),
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: content,
      ),
    );
  }

  void _showReportForm(CarWash wash) {
    bool hasSelfService =
        wash.type == 'unknown' ? true : wash.type != 'automatic';
    bool hasAutomatic =
        wash.type == 'unknown' ? true : wash.type != 'self-only';
    bool hasVacuum = wash.hasVacuum ?? true;
    String paymentType =
        wash.paymentType == 'unknown' ? 'both' : wash.paymentType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
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
                'Segnala aggiornamento',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              Text(
                wash.name,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Self-service',
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppTheme.textPrimaryColor)),
                value: hasSelfService,
                onChanged: (v) => setSheetState(() => hasSelfService = v),
                activeColor: AppTheme.primaryColor,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Automatico (rulli)',
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppTheme.textPrimaryColor)),
                value: hasAutomatic,
                onChanged: (v) => setSheetState(() => hasAutomatic = v),
                activeColor: AppTheme.primaryColor,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Aspirapolvere',
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: AppTheme.textPrimaryColor)),
                value: hasVacuum,
                onChanged: (v) => setSheetState(() => hasVacuum = v),
                activeColor: AppTheme.primaryColor,
              ),
              DropdownButtonFormField<String>(
                value: paymentType,
                decoration: const InputDecoration(labelText: 'Pagamento'),
                items: const [
                  DropdownMenuItem(value: 'coins', child: Text('Monete')),
                  DropdownMenuItem(value: 'card', child: Text('Carta')),
                  DropdownMenuItem(
                      value: 'both', child: Text('Monete e carta')),
                ],
                onChanged: (v) =>
                    setSheetState(() => paymentType = v ?? paymentType),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final computedType = hasSelfService && hasAutomatic
                        ? 'both'
                        : hasAutomatic
                            ? 'automatic'
                            : hasSelfService
                                ? 'self-only'
                                : 'both'; // entrambi OFF → default both
                    final updated = CarWash(
                      id: wash.id,
                      name: wash.name,
                      address: wash.address,
                      latitude: wash.latitude,
                      longitude: wash.longitude,
                      type: computedType,
                      hasVacuum: hasVacuum,
                      paymentType: paymentType,
                      createdAt: wash.createdAt,
                    );
                    context
                        .read<CarWashBloc>()
                        .add(UpdateCarWashEvent(updated));
                    Navigator.pop(sheetCtx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Aggiornamento inviato, grazie!'),
                          backgroundColor: AppTheme.secondaryColor,
                        ),
                      );
                    }
                  },
                  child: const Text('Invia segnalazione'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Label helpers ─────────────────────────────────────────────────────────

  String _paymentLabel(String paymentType) {
    switch (paymentType) {
      case 'card':
        return 'Carta';
      case 'both':
        return 'Monete e carta';
      case 'unknown':
        return 'Monete e carta';
      default:
        return 'Monete';
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _mapController.dispose();
    _listScrollController.dispose();
    _mobileScrollController.dispose();
    super.dispose();
  }
}

class _CarWashCard extends StatelessWidget {
  final CarWash wash;
  final VoidCallback onTap;
  final bool isSelected;
  final UserLocation? userLocation;
  final VoidCallback? onAddressTap;

  const _CarWashCard({
    required this.wash,
    required this.onTap,
    this.isSelected = false,
    this.userLocation,
    this.onAddressTap,
  });

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final favState = context.watch<CarWashFavoritesBloc>().state;
    final isLoggedIn = authState is Authenticated && !authState.isAnonymous;
    final isFav = favState.isFavorite(wash.id);

    final isUnknownType = wash.type == 'unknown';
    final hasSelf = isUnknownType || wash.type != 'automatic';
    final hasAuto = isUnknownType || wash.type != 'self-only';
    final isAnyUnknown = isUnknownType ||
        wash.hasVacuum == null ||
        wash.paymentType == 'unknown';

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: isSelected ? 6 : 0,
        color: isSelected
            ? _kCarWashColor.withOpacity(0.1)
            : AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? _kCarWashColor : AppTheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      wash.name,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isLoggedIn) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        context.read<CarWashFavoritesBloc>().add(
                              ToggleCarWashFavoriteEvent(
                                userId: authState.userId,
                                carWash: wash,
                              ),
                            );
                      },
                      child: Icon(
                        isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 20,
                        color: isFav ? Colors.red : AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              if (wash.address != null && wash.address!.isNotEmpty)
                GestureDetector(
                  onTap: onAddressTap,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          wash.address!,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: onAddressTap != null
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondaryColor,
                            decoration: onAddressTap != null
                                ? TextDecoration.underline
                                : TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onAddressTap != null) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.open_in_new,
                            size: 12, color: AppTheme.primaryColor),
                      ],
                    ],
                  ),
                ),
              if (userLocation != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${wash.getDistanceFromCoordinates(userLocation!.latitude, userLocation!.longitude).toStringAsFixed(1)} km da te',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kCarWashColor,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 5,
                runSpacing: 4,
                children: [
                  if (hasSelf)
                    _badge(
                        'Self-service', Icons.handyman_rounded, _kCarWashColor),
                  if (hasAuto)
                    _badge('Rulli', Icons.settings_rounded,
                        const Color(0xFF0E7490)),
                  if (wash.hasVacuum != false)
                    _badge('Aspirapolvere', Icons.air, const Color(0xFF6B7280)),
                  _paymentBadge(wash.paymentType),
                ],
              ),
              if (isAnyUnknown) ...[
                const SizedBox(height: 8),
                _unverifiedChip(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _unverifiedChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.help_outline_rounded,
              size: 11, color: Color(0xFFD97706)),
          const SizedBox(width: 4),
          Text(
            'Dati non verificati',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF92400E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentBadge(String paymentType) {
    final label = paymentType == 'card'
        ? 'Carta'
        : paymentType == 'coins'
            ? 'Monete'
            : 'Monete/Carta';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.borderColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.payment_rounded,
              size: 11, color: AppTheme.textSecondaryColor),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryColor)),
        ],
      ),
    );
  }
}
