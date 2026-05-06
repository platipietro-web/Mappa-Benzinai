import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mappa_prezzi_benzina/domain/entities/price_prediction.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/price_prediction_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';

class PriceTrendWidget extends StatelessWidget {
  const PriceTrendWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PricePredictionBloc, PricePredictionState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Analisi trend prezzi...'),
              ],
            ),
          );
        }

        final prediction = state.prediction;
        if (prediction == null) return const SizedBox.shrink();

        if (!prediction.hasEnoughData) {
          return _insufficientDataRow(prediction.advice);
        }

        return _trendCard(prediction, state.fuelType ?? '');
      },
    );
  }

  Widget _insufficientDataRow(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.hourglass_empty_rounded,
              size: 14, color: AppTheme.textSecondaryColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppTheme.textSecondaryColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendCard(PricePrediction prediction, String fuelType) {
    final config = _trendConfig(prediction.trend);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(config.icon, size: 18, color: config.color),
              const SizedBox(width: 8),
              Text(
                'Previsione prezzi',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const Spacer(),
              _trendBadge(prediction, config),
            ],
          ),
          if (prediction.variationPct > 0.1) ...[
            const SizedBox(height: 6),
            Text(
              'Variazione stimata: ${prediction.trend == PriceTrend.rising ? '+' : '-'}'
              '${prediction.variationPct.toStringAsFixed(1)}%',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: config.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  size: 14, color: AppTheme.textSecondaryColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  prediction.advice,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trendBadge(PricePrediction prediction, _TrendConfig config) {
    final label = prediction.trend == PriceTrend.rising
        ? '↑ In salita'
        : prediction.trend == PriceTrend.falling
            ? '↓ In calo'
            : '→ Stabile';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: config.color,
        ),
      ),
    );
  }

  _TrendConfig _trendConfig(PriceTrend trend) {
    switch (trend) {
      case PriceTrend.rising:
        return _TrendConfig(
          icon: Icons.trending_up_rounded,
          color: Colors.red[600]!,
          bgColor: Colors.red.withOpacity(0.05),
          borderColor: Colors.red.withOpacity(0.25),
        );
      case PriceTrend.falling:
        return _TrendConfig(
          icon: Icons.trending_down_rounded,
          color: const Color(0xFF4CAF50),
          bgColor: const Color(0xFF4CAF50).withOpacity(0.05),
          borderColor: const Color(0xFF4CAF50).withOpacity(0.25),
        );
      case PriceTrend.stable:
        return _TrendConfig(
          icon: Icons.trending_flat_rounded,
          color: Colors.blue[600]!,
          bgColor: Colors.blue.withOpacity(0.05),
          borderColor: Colors.blue.withOpacity(0.25),
        );
    }
  }
}

class _TrendConfig {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  const _TrendConfig({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });
}
