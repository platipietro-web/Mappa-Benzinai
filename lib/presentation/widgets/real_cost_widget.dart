import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mappa_prezzi_benzina/core/services/real_cost_calculator.dart';
import 'package:mappa_prezzi_benzina/domain/entities/real_cost_result.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';

class RealCostWidget extends StatelessWidget {
  final double distanceKm;
  final double fuelPrice;
  final double areaAvgPrice;
  final double consumption; // L/100km dichiarato dal veicolo
  final double tankSize; // litri
  final String vehicleLabel;
  final String fuelType;

  const RealCostWidget({
    Key? key,
    required this.distanceKm,
    required this.fuelPrice,
    required this.areaAvgPrice,
    required this.consumption,
    required this.tankSize,
    required this.vehicleLabel,
    required this.fuelType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (distanceKm <= 0 || areaAvgPrice <= 0) return const SizedBox.shrink();

    final result = RealCostCalculator.calculate(
      distanceKm: distanceKm,
      fuelPrice: fuelPrice,
      areaAvgPrice: areaAvgPrice,
      consumption: consumption,
      tankSize: tankSize,
    );

    final roundTripKm = distanceKm * 2;

    final isWorth = result.isWorthIt;
    final accentColor =
        isWorth ? const Color(0xFF4CAF50) : Colors.orange[700]!;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Intestazione ──────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.calculate_rounded, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  vehicleLabel.isNotEmpty
                      ? 'Stima costo reale · $vehicleLabel'
                      : 'Stima costo reale',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
              _badge(isWorth),
            ],
          ),
          const SizedBox(height: 5),
          // ── Ipotesi di calcolo ─────────────────────────────────────────────
          Text(
            '$fuelType · ${consumption.toStringAsFixed(1)} L/100km'
            ' · serbatoio ${tankSize.toStringAsFixed(0)} L'
            ' · distanza ${distanceKm.toStringAsFixed(1)} km',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppTheme.textSecondaryColor,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppTheme.borderColor),
          const SizedBox(height: 10),
          // ── Righe dettaglio ────────────────────────────────────────────────
          _row(
            'Costo per arrivare qui (A/R ~${roundTripKm.toStringAsFixed(1)} km)',
            '€ ${result.tripFuelCost.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 4),
          _row(
            'Prezzo $fuelType listato',
            '€ ${result.listedPrice.toStringAsFixed(3)}/L',
          ),
          const SizedBox(height: 4),
          _row(
            'Prezzo effettivo (tragitto incluso)',
            '€ ${result.effectivePrice.toStringAsFixed(3)}/L',
            bold: true,
          ),
          const SizedBox(height: 8),
          _savingRow(result),
        ],
      ),
    );
  }

  Widget _badge(bool isWorth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isWorth
            ? const Color(0xFF4CAF50).withOpacity(0.15)
            : Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isWorth ? 'Conviene' : 'Valuta bene',
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isWorth ? const Color(0xFF2E7D32) : Colors.orange[800],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ],
    );
  }

  Widget _savingRow(RealCostResult result) {
    final saving = result.netSaving;
    final isPositive = saving > 0;
    final color = isPositive ? const Color(0xFF4CAF50) : Colors.orange[700]!;
    final label = isPositive
        ? 'Risparmio netto sul pieno (vs media zona)'
        : 'Costo aggiuntivo sul pieno (vs media zona)';
    final value = isPositive
        ? '+ € ${saving.toStringAsFixed(2)}'
        : '- € ${saving.abs().toStringAsFixed(2)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
