import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:trailzap/utils/constants.dart';
import 'package:trailzap/utils/polyline_utils.dart';

/// Widget for displaying a map with a route polyline
class MapPolylineWidget extends StatelessWidget {
  final List<LatLng>? points;
  final String? encodedPolyline;
  final LatLng? currentPosition;
  final double zoom;
  final bool showCurrentLocation;
  final bool interactive;
  final MapController? controller;
  final double height;

  const MapPolylineWidget({
    super.key,
    this.points,
    this.encodedPolyline,
    this.currentPosition,
    this.zoom = 15.0,
    this.showCurrentLocation = true,
    this.interactive = true,
    this.controller,
    this.height = 300,
  });

  @override
  Widget build(BuildContext context) {
    // Decode polyline if provided
    List<LatLng> routePoints = points ?? [];
    if (encodedPolyline != null && encodedPolyline!.isNotEmpty) {
      final decoded = PolylineUtils.decode(encodedPolyline!);
      routePoints = decoded.map((c) => LatLng(c[0], c[1])).toList();
    }

    // Determine map center
    LatLng center;
    if (currentPosition != null) {
      center = currentPosition!;
    } else if (routePoints.isNotEmpty) {
      center = routePoints.last;
    } else {
      // Default to a central location (Davao City as fallback)
      center = const LatLng(7.0731, 125.6128);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: center,
            initialZoom: zoom,
            interactionOptions: InteractionOptions(
              flags: interactive
                  ? InteractiveFlag.all
                  : InteractiveFlag.none,
            ),
            backgroundColor: AppColors.darkCard,
          ),
          children: [
            // CartoDB Dark Matter - high detail dark mode tiles
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.trailzap.app',
              maxZoom: 20,
              // No filter needed - tiles are already dark themed
            ),

            // Route polyline
            if (routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    color: AppColors.primaryGreen,
                    strokeWidth: 4.0,
                    borderColor: AppColors.primaryGreen.withAlpha(100),
                    borderStrokeWidth: 2.0,
                  ),
                ],
              ),

            // Markers
            MarkerLayer(
              markers: [
                // Start marker
                if (routePoints.isNotEmpty)
                  Marker(
                    point: routePoints.first,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(50),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),

                // Current location marker
                if (showCurrentLocation && currentPosition != null)
                  Marker(
                    point: currentPosition!,
                    width: 32,
                    height: 32,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withAlpha(100),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.navigation,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),

                // End marker (if route is complete and different from current)
                if (routePoints.length > 1 && currentPosition == null)
                  Marker(
                    point: routePoints.last,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(50),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.flag,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini map preview for activity cards
class MiniMapPreview extends StatelessWidget {
  final String? encodedPolyline;
  final double height;
  final double width;

  const MiniMapPreview({
    super.key,
    this.encodedPolyline,
    this.height = 100,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    if (encodedPolyline == null || encodedPolyline!.isEmpty) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(
            Icons.map_outlined,
            color: AppColors.textMuted,
            size: 32,
          ),
        ),
      );
    }

    final decoded = PolylineUtils.decode(encodedPolyline!);
    final points = decoded.map((c) => LatLng(c[0], c[1])).toList();

    // Calculate bounds center
    LatLng center;
    if (points.isNotEmpty) {
      double avgLat = 0, avgLng = 0;
      for (final p in points) {
        avgLat += p.latitude;
        avgLng += p.longitude;
      }
      center = LatLng(avgLat / points.length, avgLng / points.length);
    } else {
      center = const LatLng(7.0731, 125.6128);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        width: width,
        child: IgnorePointer(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.trailzap.app',
                maxZoom: 20,
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    color: AppColors.primaryGreen,
                    strokeWidth: 3.0,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
