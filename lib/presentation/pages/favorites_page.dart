import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/core/services/service_locator.dart';
import 'package:mappa_prezzi_benzina/domain/entities/gas_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/saved_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/auth_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/favorites_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/map_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';

Color _fuelColor(String fuelType) {
  const exact = {
    'benzina speciale 100': Color(0xFF388E3C),
    'benzina servita':      Color(0xFF8BC34A),
    'benzina':              Color(0xFF4CAF50),
    'diesel+':              Color(0xFF1976D2),
    'diesel servito':       Color(0xFF42A5F5),
    'diesel hvo':           Color(0xFF0D47A1),
    'diesel':               Color(0xFF2196F3),
    'hvo':                  Color(0xFF1B5E20),
    'gpl':                  Color(0xFFFF9800),
    'metano':               Color(0xFF9C27B0),
    'gnc':                  Color(0xFF7B1FA2),
    'gnl':                  Color(0xFF4A148C),
    'idrogeno':             Color(0xFF00BCD4),
  };
  final n = fuelType.toLowerCase();
  // Chiave più lunga prima per match specifico
  final sortedKeys = exact.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final key in sortedKeys) {
    if (n.contains(key)) return exact[key]!;
  }
  return const Color(0xFF607D8B);
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
          'Preferiti',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ),
      body: BlocBuilder<FavoritesBloc, FavoritesState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.stations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border_rounded,
                        size: 64, color: AppTheme.borderColor),
                    const SizedBox(height: 16),
                    Text(
                      'Nessuna stazione preferita',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tocca il cuore su una stazione per aggiungerla ai preferiti.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.stations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final s = state.stations[index];
              return _FavoriteCard(
                station: s,
                onRemove: () {
                  final authState = context.read<AuthBloc>().state;
                  if (authState is Authenticated) {
                    context.read<FavoritesBloc>().add(RemoveFavoriteEvent(
                          userId: authState.userId,
                          stationId: s.id,
                        ));
                  }
                },
                onTap: () => _openOnMap(context, s),
              );
            },
          );
        },
      ),
    );
  }

  void _openOnMap(BuildContext context, SavedStation s) {
    final gasStation = GasStation(
      id: s.id,
      name: s.name,
      address: s.address,
      latitude: s.latitude,
      longitude: s.longitude,
      prices: s.prices,
      brand: s.brand,
    );

    // Segnala alla MapPage quale stazione centrare/selezionare al ritorno.
    // Deve essere impostato PRIMA di LoadNearbyStationsEvent perché il BlocListener
    // di MapPage si attiva sul passaggio MapLoading→MapLoaded.
    context.read<MapBloc>().add(SetPendingHighlightStationEvent(gasStation));
    context.read<MapBloc>().add(LoadNearbyStationsEvent(
      location: UserLocation(
        latitude: s.latitude,
        longitude: s.longitude,
        timestamp: DateTime.now(),
      ),
      radiusKm: AppConstants.stationSearchRadius,
    ));

    // Switcha sul tab mappa e torna a MainScreen (bottom nav bar intatta).
    getIt<ValueNotifier<int>>(instanceName: 'mainTabIndex').value = 0;
    Navigator.popUntil(context, (route) => route.isFirst);
  }
}

class _FavoriteCard extends StatelessWidget {
  final SavedStation station;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _FavoriteCard({
    required this.station,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            // Icona stazione
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_gas_station,
                  color: AppTheme.secondaryColor, size: 22),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station.name,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
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
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (station.addedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Aggiunto il ${_formatDate(station.addedAt!)}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppTheme.borderColor,
                      ),
                    ),
                  ],
                  if (station.prices.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: station.prices.entries.map((e) {
                          final color = _fuelColor(e.key);
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: color.withOpacity(0.3)),
                            ),
                            child: Text(
                              '${e.key}  €${e.value.toStringAsFixed(3)}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
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
            ),

            // Rimuovi
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.favorite_rounded,
                  color: Colors.red, size: 22),
              tooltip: 'Rimuovi dai preferiti',
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}
