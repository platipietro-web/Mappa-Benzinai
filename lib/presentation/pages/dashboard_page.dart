import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mappa_prezzi_benzina/domain/entities/dashboard_stats.dart';
import 'package:mappa_prezzi_benzina/features/vehicles/vehicle_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/bloc/dashboard_bloc.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({Key? key}) : super(key: key);

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
          'La tua dashboard',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = state.stats;

          if (!stats.hasData) {
            return _emptyState();
          }

          final vehicleName =
              context.watch<VehicleBloc>().state.defaultVehicle?.name ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Riepilogo'),
                if (vehicleName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.directions_car_rounded,
                          size: 14, color: AppTheme.textSecondaryColor),
                      const SizedBox(width: 4),
                      Text(
                        vehicleName,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                _kpiRow(stats),
                const SizedBox(height: 24),
                _sectionTitle('Spesa mensile (ultimi 6 mesi)'),
                const SizedBox(height: 12),
                _BarChart(monthlyHistory: stats.monthlyHistory),
                const SizedBox(height: 24),
                _sectionTitle('Prezzi medi'),
                const SizedBox(height: 12),
                _priceComparison(stats),
                if (stats.topSuggestion != null) ...[
                  const SizedBox(height: 24),
                  _suggestionCard(stats.topSuggestion!),
                ],
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Empty state ───────────────────────────────────────────────────────────

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 64, color: AppTheme.borderColor),
            const SizedBox(height: 16),
            Text(
              'Nessun dato ancora',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra il tuo primo rifornimento aprendo il dettaglio di un distributore.',
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

  // ─── KPI row ───────────────────────────────────────────────────────────────

  Widget _kpiRow(DashboardStats stats) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            icon: Icons.local_gas_station_rounded,
            label: 'Rifornimenti',
            value: '${stats.refuelingCount}',
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            icon: Icons.euro_rounded,
            label: 'Spesa totale',
            value: '€ ${stats.totalSpent.toStringAsFixed(0)}',
            color: Colors.blue[600]!,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            icon: Icons.savings_rounded,
            label: 'Risparmiato',
            value: stats.totalSaved >= 0
                ? '€ ${stats.totalSaved.toStringAsFixed(0)}'
                : '-€ ${stats.totalSaved.abs().toStringAsFixed(0)}',
            color: stats.totalSaved >= 0
                ? const Color(0xFF4CAF50)
                : Colors.orange[700]!,
          ),
        ),
      ],
    );
  }

  // ─── Price comparison ──────────────────────────────────────────────────────

  Widget _priceComparison(DashboardStats stats) {
    if (stats.avgPriceChosen == 0) return const SizedBox.shrink();

    final diff = stats.avgPriceArea - stats.avgPriceChosen;
    final isBelow = diff > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          _comparisonRow(
            'Prezzo medio scelto',
            '€ ${stats.avgPriceChosen.toStringAsFixed(3)}/L',
            AppTheme.primaryColor,
          ),
          const SizedBox(height: 8),
          _comparisonRow(
            'Prezzo medio zona',
            '€ ${stats.avgPriceArea.toStringAsFixed(3)}/L',
            AppTheme.textSecondaryColor,
          ),
          if (stats.avgPriceArea > 0) ...[
            const Divider(height: 20, color: AppTheme.borderColor),
            _comparisonRow(
              isBelow ? 'Stai pagando meno della media' : 'Stai pagando più della media',
              isBelow
                  ? '- € ${diff.abs().toStringAsFixed(3)}/L'
                  : '+ € ${diff.abs().toStringAsFixed(3)}/L',
              isBelow ? const Color(0xFF4CAF50) : Colors.orange[700]!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _comparisonRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // ─── Suggestion card ───────────────────────────────────────────────────────

  Widget _suggestionCard(String suggestion) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppTheme.primaryColor.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_rounded,
              color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              suggestion,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimaryColor,
        ),
      );
}

// ─── KPI Card ─────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bar Chart (CustomPainter) ────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  final List<MonthlySpend> monthlyHistory;

  const _BarChart({required this.monthlyHistory});

  @override
  Widget build(BuildContext context) {
    if (monthlyHistory.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _BarChartPainter(monthlyHistory),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: monthlyHistory
                .map(
                  (m) => Text(
                    m.label,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          // Legenda
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(AppTheme.primaryColor, 'Spesa'),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFF4CAF50), 'Risparmio'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<MonthlySpend> data;

  _BarChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxVal = data.fold(0.0, (m, d) => m > d.amount ? m : d.amount);
    if (maxVal == 0) return;

    final barWidth = (size.width / data.length) * 0.35;
    final gap = (size.width / data.length) * 0.15;
    final groupWidth = size.width / data.length;

    final spendPaint = Paint()
      ..color = AppTheme.primaryColor.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final savingPaint = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final baselinePaint = Paint()
      ..color = AppTheme.borderColor
      ..strokeWidth = 1;

    // Baseline
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      baselinePaint,
    );

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final centerX = groupWidth * i + groupWidth / 2;

      // Barra spesa
      final spendH = (item.amount / maxVal) * (size.height - 10);
      final spendLeft = centerX - barWidth - gap / 2;
      final spendRect = Rect.fromLTWH(
        spendLeft,
        size.height - spendH,
        barWidth,
        spendH,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(spendRect,
            topLeft: const Radius.circular(3),
            topRight: const Radius.circular(3)),
        spendPaint,
      );

      // Barra risparmio (solo se positivo)
      if (item.savedAmount > 0) {
        final saveH = (item.savedAmount / maxVal) * (size.height - 10);
        final saveLeft = centerX + gap / 2;
        final saveRect = Rect.fromLTWH(
          saveLeft,
          size.height - saveH,
          barWidth,
          saveH,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(saveRect,
              topLeft: const Radius.circular(3),
              topRight: const Radius.circular(3)),
          savingPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => old.data != data;
}
