import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/core/utils/price_level.dart';
import 'package:mappa_prezzi_benzina/domain/entities/gas_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/saved_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/auth_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/favorites_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/location_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';
import 'package:mappa_prezzi_benzina/presentation/widgets/current_location_marker.dart';
import 'package:mappa_prezzi_benzina/presentation/widgets/station_card.dart';
import 'package:mappa_prezzi_benzina/presentation/widgets/station_pin.dart';

const _kDesktopBreakpoint = 768.0;
const _kCardSpacing = 10.0;

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final MapController _mapController = MapController();
  final ScrollController _listScrollController = ScrollController();
  final ScrollController _mobileScrollController = ScrollController();
  final Map<String, GlobalKey> _stationKeys = {};
  GasStation? _selectedStation;

  @override
  void dispose() {
    _mapController.dispose();
    _listScrollController.dispose();
    _mobileScrollController.dispose();
    super.dispose();
  }

  GasStation _toStation(SavedStation s) => GasStation(
        id: s.id,
        name: s.name,
        address: s.address,
        latitude: s.latitude,
        longitude: s.longitude,
        prices: s.prices,
        brand: s.brand,
      );

  void _onMarkerTap(GasStation station, List<GasStation> stations) {
    setState(() => _selectedStation = station);
    try {
      _mapController.move(
        LatLng(station.latitude, station.longitude),
        _mapController.camera.zoom,
      );
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToStation(station.id, stations);
    });
  }

  void _onCardTap(
      BuildContext context, GasStation station, UserLocation? userLoc) {
    setState(() => _selectedStation = station);
    try {
      _mapController.move(LatLng(station.latitude, station.longitude), 15.0);
    } catch (_) {}
    Navigator.pushNamed(
      context,
      '/station-detail',
      arguments: {'station': station, 'userLocation': userLoc},
    );
  }

  void _scrollToStation(String stationId, List<GasStation> stations) {
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
      final index = stations.indexWhere((s) => s.id == stationId);
      if (index < 0) return;
      const cardWidth = 290.0;
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

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isLoggedIn = authState is Authenticated && !authState.isAnonymous;

    if (!isLoggedIn) return const _GuestFavoritesView();

    final locState = context.watch<LocationBloc>().state;
    final userLocation = locState is LocationLoaded ? locState.location : null;

    return BlocBuilder<FavoritesBloc, FavoritesState>(
      builder: (context, favState) {
        final stations = favState.stations.map(_toStation).toList();
        final isDesktop =
            MediaQuery.of(context).size.width >= _kDesktopBreakpoint;

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: SafeArea(
            top: true,
            bottom: false,
            child: Column(
              children: [
                _buildAppBar(stations),
                Expanded(
                  child: favState.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : isDesktop
                          ? _buildDesktopLayout(context, stations, userLocation)
                          : _buildMobileLayout(context, stations, userLocation),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar(List<GasStation> stations) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppTheme.textPrimaryColor, size: 20),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          const Icon(Icons.favorite_rounded, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Text(
            'Preferiti',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          if (stations.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${stations.length}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Desktop ───────────────────────────────────────────────────────────────

  Widget _buildDesktopLayout(BuildContext context, List<GasStation> stations,
      UserLocation? userLocation) {
    return Row(
      children: [
        // Lista verticale sinistra
        Container(
          width: 380,
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(right: BorderSide(color: AppTheme.borderColor)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: AppTheme.borderColor)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.favorite_rounded,
                        size: 14, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      '${stations.length} stazioni preferite',
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
              ),
              Expanded(
                child: stations.isEmpty
                    ? _buildEmptyList()
                    : ListView(
                        controller: _listScrollController,
                        padding: const EdgeInsets.all(12),
                        children: stations.map((station) {
                          final isSelected = _selectedStation?.id == station.id;
                          final key = _stationKeys.putIfAbsent(
                              station.id, () => GlobalKey());
                          return Padding(
                            key: key,
                            padding:
                                const EdgeInsets.only(bottom: _kCardSpacing),
                            child: _FavDesktopCard(
                              station: station,
                              userLocation: userLocation,
                              isSelected: isSelected,
                              onTap: () =>
                                  _onCardTap(context, station, userLocation),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),

        // Mappa destra
        Expanded(child: _buildMap(stations, userLocation)),
      ],
    );
  }

  // ─── Mobile ────────────────────────────────────────────────────────────────

  Widget _buildMobileLayout(BuildContext context, List<GasStation> stations,
      UserLocation? userLocation) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomSheetHeight = 280.0 + bottomInset;

    return SafeArea(
      top: true,
      bottom: false,
      child: Stack(
        children: [
          Positioned.fill(
            bottom: bottomSheetHeight,
            child: _buildMap(stations, userLocation),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildMobileBottomList(
                context, stations, userLocation, bottomInset),
          ),
        ],
      ),
    );
  }

  // ─── Mappa ─────────────────────────────────────────────────────────────────

  Widget _buildMap(List<GasStation> stations, UserLocation? userLocation) {
    // Con almeno un preferito, la camera si posiziona/adatta per contenere
    // tutte le stazioni salvate (non solo la prima), così si "arriva" già
    // sui benzinai preferiti invece che sulla posizione dell'utente.
    final cameraFit = stations.isNotEmpty
        ? CameraFit.coordinates(
            coordinates: stations
                .map((s) => LatLng(s.latitude, s.longitude))
                .toList(),
            padding: const EdgeInsets.all(60),
            maxZoom: 15,
          )
        : null;
    final initialCenter = stations.isNotEmpty
        ? LatLng(stations.first.latitude, stations.first.longitude)
        : userLocation != null
            ? LatLng(userLocation.latitude, userLocation.longitude)
            : const LatLng(
                AppConstants.defaultLatitude, AppConstants.defaultLongitude);

    return ClipRect(
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: initialCenter,
          initialZoom: stations.isNotEmpty ? 12 : AppConstants.defaultZoom,
          initialCameraFit: cameraFit,
          maxZoom: 18,
          minZoom: 5,
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
                width: 28,
                height: 28,
                child: const CurrentLocationMarker(),
              ),
            ]),
          MarkerLayer(
            markers: _buildStationMarkers(stations),
          ),
        ],
      ),
    );
  }

  /// Prezzo rappresentativo di una stazione: media di tutti i carburanti
  /// disponibili (qui non c'è un filtro per tipo come nella mappa
  /// principale).
  double _representativePrice(GasStation station) {
    if (station.prices.isEmpty) return double.infinity;
    final values = station.prices.values;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Colora ogni pin in base al prezzo rispetto alla media dei soli
  /// preferiti: verde = più conveniente, giallo = in linea, rosso = più caro.
  List<Marker> _buildStationMarkers(List<GasStation> stations) {
    final areaAverage =
        averageOfFinite(stations.map(_representativePrice));

    return stations.map((station) {
      final isSelected = _selectedStation?.id == station.id;
      final priceLevel = classifyPriceLevel(
          _representativePrice(station), areaAverage);
      final pin = StationPin(
        brand: station.brand,
        selected: isSelected,
        size: isSelected ? 68 : 46,
        priceColor: _priceLevelColor(priceLevel),
      );
      return Marker(
        point: LatLng(station.latitude, station.longitude),
        width: pin.boxSize,
        height: pin.boxSize,
        alignment: pin.markerAlignment,
        child: GestureDetector(
          onTap: () => _onMarkerTap(station, stations),
          child: pin,
        ),
      );
    }).toList();
  }

  Color? _priceLevelColor(PriceLevel? level) {
    switch (level) {
      case PriceLevel.cheap:
        return AppTheme.secondaryColor;
      case PriceLevel.expensive:
        return AppTheme.errorColor;
      case PriceLevel.average:
        return AppTheme.accentColor;
      case null:
        return null;
    }
  }

  // ─── Lista mobile (orizzontale) ────────────────────────────────────────────

  Widget _buildMobileBottomList(BuildContext context, List<GasStation> stations,
      UserLocation? userLocation, double bottomInset) {
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
                const Icon(Icons.favorite_rounded, size: 13, color: Colors.red),
                const SizedBox(width: 6),
                Text(
                  '${stations.length} stazioni preferite',
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
                    controller: _mobileScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.fromLTRB(12, 4, 12, 14 + bottomInset),
                    itemCount: stations.length,
                    itemBuilder: (context, index) {
                      final station = stations[index];
                      final isSelected = _selectedStation?.id == station.id;
                      return SizedBox(
                        width: 280,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: StationCard(
                            station: station,
                            userLocation: userLocation,
                            isSelected: isSelected,
                            onTap: () =>
                                _onCardTap(context, station, userLocation),
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

  // ─── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyList() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border_rounded,
              size: 32, color: AppTheme.borderColor),
          const SizedBox(height: 8),
          Text(
            'Nessuna stazione preferita.\nTocca ♥ su un distributore per aggiungerlo.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppTheme.textSecondaryColor),
          ),
        ],
      ),
    );
  }
}

// ─── Card desktop con badge "Dettaglio" ────────────────────────────────────

class _FavDesktopCard extends StatelessWidget {
  final GasStation station;
  final UserLocation? userLocation;
  final bool isSelected;
  final VoidCallback onTap;

  const _FavDesktopCard({
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
        Positioned(
          bottom: 8,
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

// ─── Schermata invito per utenti non registrati ────────────────────────────

class _GuestFavoritesView extends StatelessWidget {
  const _GuestFavoritesView();

  static const _benefits = [
    (Icons.favorite_rounded, 'Salva le stazioni con i prezzi migliori'),
    (Icons.bolt_rounded, 'Raggiungi i tuoi preferiti con un tocco'),
    (Icons.price_change_rounded, 'Tieni d\'occhio i prezzi nel tempo'),
    (Icons.directions_car_rounded, 'Calcola il costo reale per il tuo veicolo'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Preferiti',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_rounded,
                    size: 52, color: Colors.red),
              ),
              const SizedBox(height: 28),
              Text(
                'Salva le tue stazioni preferite',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Crea un account gratuito e accedi ai tuoi benzinai preferiti con un tap, ovunque tu sia.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.5,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 36),
              ...(_benefits.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(b.$1,
                              size: 18, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              b.$2,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ))),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context
                      .read<AuthBloc>()
                      .add(const SignOutEvent(signUpMode: true)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Crea account gratuito',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      context.read<AuthBloc>().add(const SignOutEvent()),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                        color: AppTheme.primaryColor.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Hai già un account? Accedi',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
