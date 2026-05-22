import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mappa_prezzi_benzina/core/constants/app_constants.dart';
import 'package:mappa_prezzi_benzina/domain/entities/car_wash.dart';
import 'package:mappa_prezzi_benzina/domain/entities/user_location.dart';
import 'package:mappa_prezzi_benzina/presentation/theme/app_theme.dart';

const _kCarWashColor = Color(0xFF0891B2); // cyan-600

class CarWashMap extends StatelessWidget {
  final MapController mapController;
  final List<CarWash> washes;
  final CarWash? selectedWash;
  final UserLocation? userLocation;
  final bool isAddMode;
  final void Function(CarWash) onMarkerTap;
  final void Function(LatLng)? onMapTap;

  const CarWashMap({
    Key? key,
    required this.mapController,
    required this.washes,
    required this.onMarkerTap,
    this.selectedWash,
    this.userLocation,
    this.isAddMode = false,
    this.onMapTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: userLocation != null
              ? LatLng(userLocation!.latitude, userLocation!.longitude)
              : const LatLng(
                  AppConstants.defaultLatitude, AppConstants.defaultLongitude),
          initialZoom: userLocation != null ? 13 : AppConstants.defaultZoom,
          maxZoom: 18,
          minZoom: 5,
          onTap: isAddMode && onMapTap != null
              ? (_, latLng) => onMapTap!(latLng)
              : null,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
            userAgentPackageName: 'it.mappabenzinai.app',
          ),
          RichAttributionWidget(
            attributions: [
              TextSourceAttribution('© OpenStreetMap contributors'),
            ],
          ),
          if (userLocation != null)
            MarkerLayer(markers: [_userMarker(userLocation!)]),
          MarkerLayer(
            markers: washes.map(_washMarker).toList(),
          ),
        ],
      ),
    );
  }

  Marker _userMarker(UserLocation loc) => Marker(
        point: LatLng(loc.latitude, loc.longitude),
        width: 44,
        height: 44,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.4),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 20),
        ),
      );

  Marker _washMarker(CarWash wash) {
    final isSelected = selectedWash?.id == wash.id;
    return Marker(
      point: LatLng(wash.latitude, wash.longitude),
      width: isSelected ? 48 : 40,
      height: isSelected ? 48 : 40,
      child: GestureDetector(
        onTap: () => onMarkerTap(wash),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentColor : _kCarWashColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: isSelected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isSelected ? AppTheme.accentColor : _kCarWashColor)
                    .withOpacity(0.5),
                blurRadius: isSelected ? 14 : 6,
                spreadRadius: isSelected ? 3 : 1,
              ),
            ],
          ),
          child: Icon(
            Icons.local_car_wash,
            color: Colors.white,
            size: isSelected ? 22 : 18,
          ),
        ),
      ),
    );
  }
}
