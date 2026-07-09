import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mappa_prezzi_benzina/core/utils/staleness.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';

/// Etichetta "Aggiornato X fa". Se il prezzo è vecchio (oltre
/// [stalePriceThreshold]) viene evidenziata per segnalare che potrebbe non
/// essere più attendibile.
class UpdatedAtLabel extends StatelessWidget {
  const UpdatedAtLabel({super.key, required this.lastUpdated, this.dense = false});

  final DateTime lastUpdated;

  /// true = versione compatta senza badge (usata nelle card piccole).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final stale = isPriceStale(lastUpdated);
    final label = 'Aggiornato ${timeAgo(lastUpdated)}';

    if (!stale) {
      return Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          color: AppTheme.textSecondaryColor,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withOpacity(0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.accentColor.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 13, color: AppTheme.accentColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '$label · prezzo non aggiornato di recente',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
