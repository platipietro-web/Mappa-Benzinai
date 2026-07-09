import 'package:flutter/material.dart';

import 'package:mappa_prezzi_benzina/core/constants/brand_assets.dart';

/// Pin a goccia per i distributori sulla mappa.
///
/// La sagoma (cornice + punta) è sempre in un colore neutro, mai nel colore
/// del brand: il brand compare solo dentro lo slot bianco centrale (logo),
/// così la gerarchia resta leggibile anche con tanti brand diversi insieme.
/// Geometria basata su un viewBox logico 36x36 (vedi [StationPin._pinPath]).
class StationPin extends StatelessWidget {
  const StationPin({
    super.key,
    required this.brand,
    this.selected = false,
    this.size = 32,
    this.priceColor,
  });

  final String? brand;
  final bool selected;

  /// Diametro "nominale" del pin (senza il margine extra per anello/ombra
  /// dello stato selezionato). 32 = standard, 48 = selezionato.
  final double size;

  /// Colore della sagoma in base al prezzo rispetto alla media zona
  /// (verde/giallo/rosso). Se null usa il colore neutro di default.
  final Color? priceColor;

  static const double _viewBox = 36;
  static const double _contentRadius = 6.6;

  double get _pad => selected ? size * 0.2 : size * 0.12;
  double get _box => size + _pad * 2;

  /// Valore da passare a `Marker.alignment` (flutter_map) perché sia la
  /// PUNTA del pin, non il centro del riquadro, ad ancorarsi alla coordinata
  /// geografica. flutter_map definisce `alignment` come la posizione del
  /// riquadro rispetto al punto: l'ancora effettiva è quindi il lato opposto,
  /// da cui il segno invertito qui sotto.
  Alignment get markerAlignment {
    final tipY = _pad + size * (33 / _viewBox);
    final anchorY = (tipY / _box) * 2 - 1;
    return Alignment(0, -anchorY);
  }

  double get boxSize => _box;

  @override
  Widget build(BuildContext context) {
    final logoAsset = BrandAssets.logoAssetFor(brand);
    final contentSize = size * (_contentRadius * 2 / _viewBox);

    return SizedBox(
      width: _box,
      height: _box,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _PinShellPainter(
                pad: _pad,
                size: size,
                selected: selected,
                shellColor: priceColor ?? _PinShellPainter.ink,
              ),
            ),
          ),
          // Alla scala "puntino" (< 24) lo slot non ospita dettagli
          // leggibili: il painter disegna già un nucleo pieno, senza logo.
          if (size >= 24)
            Positioned(
              left: (_box - contentSize) / 2,
              top: _pad + size * (13.5 / _viewBox) - contentSize / 2,
              width: contentSize,
              height: contentSize,
              child: logoAsset != null
                  ? Image.asset(logoAsset, fit: BoxFit.contain)
                  : Icon(Icons.local_gas_station, color: _PinShellPainter.ink, size: contentSize),
            ),
        ],
      ),
    );
  }
}

class _PinShellPainter extends CustomPainter {
  const _PinShellPainter({
    required this.pad,
    required this.size,
    required this.selected,
    required this.shellColor,
  });

  final double pad;
  final double size;
  final bool selected;
  final Color shellColor;

  static const Color ink = Color(0xFF1F2937);
  static const Color slot = Colors.white;
  static const Color selectionRing = Color(0xFFF59E0B);

  static const double _viewBox = 36;

  static final Path _pinPath = Path()
    ..moveTo(18, 3)
    ..cubicTo(12.195, 3, 7.5, 7.695, 7.5, 13.5)
    ..cubicTo(7.5, 21.375, 18, 33, 18, 33)
    ..cubicTo(18, 33, 28.5, 21.375, 28.5, 13.5)
    ..cubicTo(28.5, 7.695, 23.805, 3, 18, 3)
    ..close();

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final scale = size / _viewBox;
    canvas.save();
    canvas.translate(pad, pad);
    canvas.scale(scale);

    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(18, 34.5),
        width: selected ? 18 : 14,
        height: selected ? 5.2 : 4,
      ),
      Paint()
        ..color = const Color(0x47101828)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
    );

    if (selected) {
      canvas.drawCircle(
        const Offset(18, 13.5),
        14.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = selectionRing.withOpacity(0.18),
      );
      canvas.drawCircle(
        const Offset(18, 13.5),
        14.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..color = selectionRing,
      );
    }

    canvas.drawPath(_pinPath, Paint()..color = shellColor);

    if (size >= 24) {
      canvas.drawCircle(const Offset(18, 13.5), 8.5, Paint()..color = slot);
    } else {
      // Alla scala "puntino" lo slot non ospita dettagli leggibili: un
      // nucleo pieno basta a segnalare la presenza di un distributore.
      canvas.drawCircle(const Offset(18, 13.5), 4.6, Paint()..color = slot);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PinShellPainter oldDelegate) =>
      oldDelegate.selected != selected ||
      oldDelegate.size != size ||
      oldDelegate.pad != pad ||
      oldDelegate.shellColor != shellColor;
}
