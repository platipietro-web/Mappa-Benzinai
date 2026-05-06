import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mappa_prezzi_benzina/core/services/real_cost_calculator.dart';
import 'package:mappa_prezzi_benzina/domain/entities/real_cost_result.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_profile.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';

class RealCostWidget extends StatelessWidget {
  final double distanceKm;
  final double fuelPrice;
  final double areaAvgPrice;
  final UserProfile profile;
  final String fuelType;

  const RealCostWidget({
    Key? key,
    required this.distanceKm,
    required this.fuelPrice,
    required this.areaAvgPrice,
    required this.profile,
    required this.fuelType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Non mostrare se manca la distanza o il prezzo medio
    if (distanceKm <= 0 || areaAvgPrice <= 0) return const SizedBox.shrink();

    final result = RealCostCalculator.calculate(
      distanceKm: distanceKm,
      fuelPrice: fuelPrice,
      areaAvgPrice: areaAvgPrice,
      profile: profile,
    );

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: result.isWorthIt
            ? const Color(0xFF4CAF50).withOpacity(0.07)
            : Colors.orange.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.isWorthIt
              ? const Color(0xFF4CAF50).withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.isWorthIt
                    ? Icons.thumb_up_rounded
                    : Icons.info_outline_rounded,
                size: 16,
                color: result.isWorthIt
                    ? const Color(0xFF4CAF50)
                    : Colors.orange[700],
              ),
              const SizedBox(width: 6),
              Text(
                profile.vehicleName.isNotEmpty
                    ? 'Costo reale · ${profile.vehicleName}'
                    : 'Costo reale ($fuelType)',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const Spacer(),
              _badge(result),
            ],
          ),
          const SizedBox(height: 10),
          _row('Prezzo listato',
              '€ ${result.listedPrice.toStringAsFixed(3)}/L'),
          const SizedBox(height: 4),
          _row('Prezzo effettivo (con tragitto)',
              '€ ${result.effectivePrice.toStringAsFixed(3)}/L',
              bold: true),
          const SizedBox(height: 4),
          _row('Costo tragitto A/R',
              '€ ${result.tripFuelCost.toStringAsFixed(2)}'),
          const SizedBox(height: 6),
          _savingRow(result),
        ],
      ),
    );
  }

  Widget _badge(RealCostResult result) {
    final isWorth = result.isWorthIt;
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
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppTheme.textSecondaryColor,
          ),
        ),
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
    final color =
        isPositive ? const Color(0xFF4CAF50) : Colors.orange[700]!;
    final label = isPositive
        ? 'Risparmio netto sul pieno'
        : 'Costo aggiuntivo sul pieno';
    final value = isPositive
        ? '+ € ${saving.toStringAsFixed(2)}'
        : '- € ${saving.abs().toStringAsFixed(2)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
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
