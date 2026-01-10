import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:gap/gap.dart';
import 'package:latlong2/latlong.dart';
import 'package:trailzap/services/tracking_service.dart';
import 'package:trailzap/services/location_service.dart';
import 'package:trailzap/providers/activities_provider.dart';
import 'package:trailzap/utils/constants.dart';
import 'package:trailzap/widgets/gradient_button.dart';
import 'package:trailzap/widgets/map_polyline.dart';

/// Provider for tracking service
final trackingServiceProvider = ChangeNotifierProvider<TrackingService>((ref) {
  return TrackingService.instance;
});

class TrackScreen extends ConsumerStatefulWidget {
  final String? initialActivityType;
  
  const TrackScreen({super.key, this.initialActivityType});

  @override
  ConsumerState<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends ConsumerState<TrackScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  final MapController _mapController = MapController();
  bool _isInitializing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Request location permission on load
    _checkLocationPermission();
    
    // Set initial activity type if provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tracking = ref.read(trackingServiceProvider);
      
      // Reset state if idle (clears previous activity's metrics)
      tracking.resetIfIdle();
      
      if (widget.initialActivityType != null) {
        tracking.setActivityType(widget.initialActivityType!);
      }
      _checkForRecoverableSession();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _checkForRecoverableSession() async {
    final tracking = ref.read(trackingServiceProvider);
    if (tracking.hasRecoverableSession) {
      final sessionInfo = tracking.recoveredSessionInfo;
      if (sessionInfo != null && mounted) {
        _showRecoveryDialog(sessionInfo);
      }
    }
  }

  void _showRecoveryDialog(Map<String, dynamic> sessionInfo) {
    final durationSecs = sessionInfo['duration_secs'] as int? ?? 0;
    final distanceMeters = (sessionInfo['distance_meters'] as num?)?.toDouble() ?? 0;
    final activityType = sessionInfo['activity_type'] as String? ?? 'Activity';
    
    final duration = Duration(seconds: durationSecs);
    final mins = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final distanceKm = (distanceMeters / 1000).toStringAsFixed(2);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.restore, color: AppColors.primaryOrange),
            const SizedBox(width: 12),
            const Text('Session Found'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have an unfinished ${activityType.toUpperCase()} session:',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.darkBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('$mins:$secs', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Text('Duration', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                  Container(width: 1, height: 40, color: AppColors.darkDivider),
                  Column(
                    children: [
                      Text('$distanceKm km', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Text('Distance', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Would you like to continue this session?',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(trackingServiceProvider).discardRecoveredSession();
            },
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              HapticFeedback.mediumImpact();
              final success = await ref.read(trackingServiceProvider).recoverSession();
              if (success && mounted) {
                // Session recovered in paused state
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Session restored! Tap Resume to continue.')),
                );
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkLocationPermission() async {
    final locationService = LocationService.instance;
    final hasPermission = await locationService.hasPermission();
    if (!hasPermission) {
      final permission = await locationService.requestPermission();
      if (permission.toString().contains('denied')) {
        setState(() {
          _errorMessage = 'Location permission required for tracking';
        });
      }
    }
  }

  Future<void> _startTracking() async {
    final tracking = ref.read(trackingServiceProvider);
    
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    HapticFeedback.heavyImpact();

    final success = await tracking.startTracking();

    setState(() {
      _isInitializing = false;
    });

    if (!success) {
      setState(() {
        _errorMessage = 'Failed to start GPS tracking. Please check location permissions.';
      });
      _showErrorSnackbar('Could not start tracking. Check GPS settings.');
    }
  }

  void _pauseTracking() {
    HapticFeedback.mediumImpact();
    ref.read(trackingServiceProvider).pauseTracking();
  }

  void _resumeTracking() {
    HapticFeedback.mediumImpact();
    ref.read(trackingServiceProvider).resumeTracking();
  }

  Future<void> _stopTracking() async {
    HapticFeedback.heavyImpact();
    
    final tracking = ref.read(trackingServiceProvider);
    final result = await tracking.stopTracking();

    if (result != null) {
      _showSaveDialog(result);
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const Gap(12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.darkCard,
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () {
            LocationService.instance.openLocationSettings();
          },
        ),
      ),
    );
  }

  void _showSaveDialog(TrackingResult result) {
    final nameController = TextEditingController(text: result.defaultName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.darkDivider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Gap(24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.getActivityColor(result.activityType).withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getActivityIcon(result.activityType),
                      color: AppColors.getActivityColor(result.activityType),
                      size: 24,
                    ),
                  ),
                  const Gap(16),
                  const Expanded(
                    child: Text(
                      'Save Activity',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(24),
              
              // Mini map preview
              if (result.mapPolyline.isNotEmpty)
                MiniMapPreview(
                  encodedPolyline: result.mapPolyline,
                  height: 120,
                ),
              
              const Gap(20),

              TextField(
                controller: nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Activity Name',
                  hintText: 'Give your activity a name',
                ),
              ),
              const Gap(24),

              // Summary stats
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryStat(
                      label: 'Distance',
                      value: '${result.distanceKm.toStringAsFixed(2)} km',
                    ),
                    Container(width: 1, height: 40, color: AppColors.darkDivider),
                    _SummaryStat(
                      label: 'Duration',
                      value: _formatDuration(Duration(seconds: result.durationSecs)),
                    ),
                    Container(width: 1, height: 40, color: AppColors.darkDivider),
                    _SummaryStat(
                      label: 'Pace',
                      value: '${result.paceMinPerKm.isFinite ? result.paceMinPerKm.toStringAsFixed(1) : '--'} /km',
                    ),
                  ],
                ),
              ),
              const Gap(24),

              GradientButton(
                onPressed: () async {
                  // Save to Supabase
                  final activity = await ref.read(activitiesProvider.notifier).addActivity(
                    name: nameController.text.isNotEmpty ? nameController.text : result.defaultName,
                    type: result.activityType,
                    distanceKm: result.distanceKm,
                    durationSecs: result.durationSecs,
                    startTime: result.startTime,
                    endTime: result.endTime,
                    mapPolyline: result.mapPolyline,
                    elevationGain: result.elevationGain,
                  );

                  if (mounted) {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.primaryGreen),
                            const Gap(12),
                            Text(activity != null ? 'Activity saved!' : 'Saved locally'),
                          ],
                        ),
                        backgroundColor: AppColors.darkCard,
                      ),
                    );
                  }
                },
                child: const Text('Save Activity'),
              ),
              const Gap(12),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showDiscardDialog();
                },
                child: const Text(
                  'Discard',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              const Gap(16),
            ],
          ),
        ),
      ),
    );
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Discard Activity?'),
        content: const Text(
          'Are you sure you want to discard this activity? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(trackingServiceProvider).discardTracking();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'run':
        return Icons.directions_run_rounded;
      case 'walk':
        return Icons.directions_walk_rounded;
      case 'bike':
        return Icons.directions_bike_rounded;
      case 'hike':
        return Icons.hiking_rounded;
      default:
        return Icons.directions_run_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(trackingServiceProvider);
    final isTracking = tracking.state != TrackingState.idle;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: tracking.state == TrackingState.idle
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        automaticallyImplyLeading: false,
        title: isTracking
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tracking.state == TrackingState.tracking
                              ? AppColors.primaryGreen.withAlpha(
                                  (128 + 127 * _pulseController.value).toInt())
                              : AppColors.primaryOrange,
                        ),
                      );
                    },
                  ),
                  const Gap(8),
                  Text(
                    tracking.state == TrackingState.tracking ? 'Recording' : 'Paused',
                    style: TextStyle(
                      color: tracking.state == TrackingState.tracking
                          ? AppColors.primaryGreen
                          : AppColors.primaryOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : null,
        actions: isTracking
            ? [
                IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: () {
                    if (tracking.currentPosition != null) {
                      _mapController.move(
                        LatLng(
                          tracking.currentPosition!.latitude,
                          tracking.currentPosition!.longitude,
                        ),
                        17,
                      );
                    }
                  },
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Map
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.all(16),
                child: _buildMap(tracking),
              ),
            ),

            // Metrics
            Expanded(
              flex: 2,
              child: _buildMetricsPanel(tracking),
            ),

            // Controls
            if (tracking.state == TrackingState.idle)
              _buildActivitySelector(tracking)
            else
              _buildTrackingControls(tracking),

            const Gap(32),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(TrackingService tracking) {
    // Convert track points to LatLng
    final routePoints = tracking.trackPoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    LatLng? currentPos;
    if (tracking.currentPosition != null) {
      currentPos = LatLng(
        tracking.currentPosition!.latitude,
        tracking.currentPosition!.longitude,
      );
    }

    if (tracking.state == TrackingState.idle && currentPos == null) {
      // Show placeholder when not tracking
      return Container(
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.darkDivider),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isInitializing)
                const CircularProgressIndicator(color: AppColors.primaryGreen)
              else ...[
                Icon(
                  Icons.map_outlined,
                  size: 48,
                  color: AppColors.textMuted,
                ),
                const Gap(12),
                Text(
                  _errorMessage ?? 'Start tracking to see the map',
                  style: TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: MapPolylineWidget(
        points: routePoints,
        currentPosition: currentPos,
        controller: _mapController,
        zoom: 17,
        height: double.infinity,
        interactive: true,
        showCurrentLocation: true,
      ),
    );
  }

  Widget _buildMetricsPanel(TrackingService tracking) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.darkDivider.withAlpha(128)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Duration
          Text(
            tracking.formatDuration(),
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w300,
              color: AppColors.textPrimary,
              letterSpacing: -2,
            ),
          ).animate().fadeIn(),

          const Gap(8),

          const Text(
            'Duration',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),

          const Gap(24),

          // Distance and Pace
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MetricColumn(
                value: tracking.distanceKm.toStringAsFixed(2),
                unit: 'km',
                label: 'Distance',
                color: AppColors.runColor,
              ),
              Container(width: 1, height: 50, color: AppColors.darkDivider),
              _MetricColumn(
                value: tracking.formatPace(),
                unit: '/km',
                label: 'Pace',
                color: AppColors.bikeColor,
              ),
              Container(width: 1, height: 50, color: AppColors.darkDivider),
              _MetricColumn(
                value: tracking.elevationGain.toStringAsFixed(0),
                unit: 'm',
                label: 'Elevation',
                color: AppColors.hikeColor,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildActivitySelector(TrackingService tracking) {
    return Column(
      children: [
        // Activity type selector
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: ['run', 'walk', 'bike', 'hike'].map((type) {
              final isSelected = tracking.activityType == type;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    tracking.setActivityType(type);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                AppColors.getActivityColor(type),
                                AppColors.getActivityColor(type).withAlpha(178),
                              ],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getActivityIcon(type),
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          size: 20,
                        ),
                        const Gap(8),
                        Text(
                          type[0].toUpperCase() + type.substring(1),
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const Gap(24),

        // Start button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GradientButton(
            onPressed: _isInitializing ? null : _startTracking,
            isLoading: _isInitializing,
            gradient: LinearGradient(
              colors: [
                AppColors.getActivityColor(tracking.activityType),
                AppColors.getActivityColor(tracking.activityType).withAlpha(178),
              ],
            ),
            height: 64,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, size: 28),
                Gap(8),
                Text(
                  'Start',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildTrackingControls(TrackingService tracking) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Stop button
          _ControlButton(
            icon: Icons.stop_rounded,
            label: 'Stop',
            color: Colors.red,
            onPressed: _stopTracking,
          ),

          // Pause/Resume button
          _ControlButton(
            icon: tracking.state == TrackingState.tracking
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            label: tracking.state == TrackingState.tracking ? 'Pause' : 'Resume',
            color: AppColors.primaryGreen,
            size: 80,
            onPressed: tracking.state == TrackingState.tracking
                ? _pauseTracking
                : _resumeTracking,
          ),

          // Lock button
          _ControlButton(
            icon: Icons.lock_outline_rounded,
            label: 'Lock',
            color: AppColors.textSecondary,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Screen lock coming soon!')),
              );
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }
}

class _MetricColumn extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final Color color;

  const _MetricColumn({
    required this.value,
    required this.unit,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w300,
                color: color,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                unit,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        const Gap(4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final double size;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            onPressed();
          },
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha(38),
              border: Border.all(color: color, width: 3),
            ),
            child: Icon(icon, color: color, size: size * 0.45),
          ),
        ),
        const Gap(8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const Gap(4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
