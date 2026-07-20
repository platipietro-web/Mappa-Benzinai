import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mappa_prezzi_benzina/domain/entities/route_station_suggestion.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';
import 'package:mappa_prezzi_benzina/presentation/widgets/station_card.dart';

/// Card di un benzinaio suggerito lungo il percorso: wrappa [StationCard]
/// (stesso pattern di `_DesktopStationCard` in map_page.dart) aggiungendo
/// una fascia con la posizione in classifica, la deviazione dal percorso e
/// il prezzo effettivo calcolato da [RealCostCalculator]. Non passa
/// `userLocation` a [StationCard]: quella label significa "distanza da te",
/// che qui sarebbe fuorviante — la deviazione dal percorso è mostrata qui
/// con la sua etichetta corretta.
class RouteStationCard extends StatelessWidget {
  final RouteStationSuggestion suggestion;
  final int rank; // 1-based
  final bool isSelected;
  final bool isWaypoint;
  final VoidCallback onTap;
  final VoidCallback onAddWaypoint;
  final VoidCallback onRemoveWaypoint;

  const RouteStationCard({
    super.key,
    required this.suggestion,
    required this.rank,
    required this.isSelected,
    required this.isWaypoint,
    required this.onTap,
    required this.onAddWaypoint,
    required this.onRemoveWaypoint,
  });

  @override
  Widget build(BuildContext context) {
    final isRecommended = rank == 1;
    final saving = suggestion.netSaving;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: isRecommended
            ? Border.all(color: AppTheme.primaryColor, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isRecommended
                        ? AppTheme.primaryColor
                        : AppTheme.borderColor.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isRecommended ? '★ Consigliato' : '#$rank',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isRecommended
                          ? Colors.white
                          : AppTheme.textSecondaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.turn_slight_right_rounded,
                    size: 14, color: AppTheme.textSecondaryColor),
                const SizedBox(width: 2),
                Text(
                  '${suggestion.detourKm.toStringAsFixed(1)} km dal percorso',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '€ ${suggestion.effectivePrice.toStringAsFixed(3)}/L eff.',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: saving >= 0
                        ? const Color(0xFF2E7D32)
                        : Colors.orange[800],
                  ),
                ),
              ],
            ),
          ),
          StationCard(
            station: suggestion.station,
            isSelected: isSelected,
            onTap: onTap,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
            child: isWaypoint
                ? Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Tappa',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: onRemoveWaypoint,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Rimuovi',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ],
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: onAddWaypoint,
                      icon: const Icon(Icons.add_location_alt_outlined,
                          size: 15),
                      label: const Text('Aggiungi tappa'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(
                            color: AppTheme.primaryColor.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
