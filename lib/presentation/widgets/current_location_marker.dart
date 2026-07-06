import 'package:flutter/material.dart';

import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';

/// Indicatore "la mia posizione", in stile puntino (come Google/Apple Maps):
/// un alone soffuso attorno a un pallino pieno con bordo bianco, invece del
/// vecchio cerchio con icona omino.
class CurrentLocationMarker extends StatelessWidget {
  const CurrentLocationMarker({super.key, this.size = 28});

  /// Diametro complessivo del marker, alone incluso.
  final double size;

  @override
  Widget build(BuildContext context) {
    final dotSize = size * 0.5;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor.withOpacity(0.16),
            ),
          ),
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
