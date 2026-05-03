import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mappa_prezzi_benzina/domain/entities/gas_station.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';

// Colore per tipo carburante (benzina=verde, diesel=blu)
Color _fuelColor(String fuelType) {
  final n = fuelType.toLowerCase();
  if (n.contains('benzina')) return const Color(0xFF4CAF50);
  if (n.contains('gasolio') || n.contains('diesel')) return const Color(0xFF2196F3);
  if (n.contains('hvo')) return const Color(0xFF00796B);
  if (n.contains('gpl')) return const Color(0xFFFF9800);
  if (n.contains('metano') || n.contains('gnc') || n.contains('gnl')) {
    return const Color(0xFF9C27B0);
  }
  if (n.contains('idrogeno')) return const Color(0xFF00BCD4);
  return const Color(0xFF607D8B);
}

class StationCard extends StatelessWidget {
  final GasStation station;
  final VoidCallback onTap;
  final bool isSelected;
  final UserLocation? userLocation;

  const StationCard({
    Key? key,
    required this.station,
    required this.onTap,
    this.isSelected = false,
    this.userLocation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: isSelected ? 8 : 0,
        color: isSelected
            ? AppTheme.primaryColor.withOpacity(0.1)
            : AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // non occupa più spazio del necessario
            children: [
              // ── Nome + rating ──────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      station.name,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (station.averageRating != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star,
                              size: 13, color: AppTheme.accentColor),
                          const SizedBox(width: 3),
                          Text(
                            station.averageRating!.toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 6),

              // ── Indirizzo ──────────────────────────────────────────────
              Text(
                station.address.isNotEmpty
                    ? station.address
                    : 'Indirizzo non disponibile',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // ── Distanza ───────────────────────────────────────────────
              if (userLocation != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${station.getDistanceFromCoordinates(
                    userLocation!.latitude,
                    userLocation!.longitude,
                  ).toStringAsFixed(1)} km da te',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // ── Prezzi ─────────────────────────────────────────────────
              if (station.prices.isEmpty)
                Text(
                  'Prezzi non disponibili',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                )
              else
                // SingleChildScrollView orizzontale senza altezza fissa
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: station.prices.entries.map((entry) {
                      final color = _fuelColor(entry.key);
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: color.withOpacity(0.3)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              entry.key,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '€ ${entry.value.toStringAsFixed(3)}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // ── Aggiornamento ──────────────────────────────────────────
              if (station.lastUpdated != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Aggiornato ${_timeAgo(station.lastUpdated!)}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min fa';
    if (diff.inHours < 24) return '${diff.inHours} ore fa';
    return '${diff.inDays} giorni fa';
  }
}