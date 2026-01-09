import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:trailzap/utils/constants.dart';
import 'package:trailzap/widgets/gradient_button.dart';

enum TrackingState { idle, tracking, paused }

class TrackScreen extends ConsumerStatefulWidget {
  const TrackScreen({super.key});

  @override
  ConsumerState<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends ConsumerState<TrackScreen>
    with TickerProviderStateMixin {
  TrackingState _trackingState = TrackingState.idle;
  String _selectedActivityType = 'run';
  
  // Tracking metrics
  Duration _duration = Duration.zero;
  double _distance = 0.0;
  Timer? _timer;
  
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTracking() {
    HapticFeedback.heavyImpact();
    setState(() {
      _trackingState = TrackingState.tracking;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _duration += const Duration(seconds: 1);
        // Simulate distance increment (will be replaced with real GPS)
        _distance += 0.002 + (0.001 * (timer.tick % 5));
      });
    });
  }

  void _pauseTracking() {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    setState(() {
      _trackingState = TrackingState.paused;
    });
  }

  void _resumeTracking() {
    HapticFeedback.mediumImpact();
    setState(() {
      _trackingState = TrackingState.tracking;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _duration += const Duration(seconds: 1);
        _distance += 0.002 + (0.001 * (timer.tick % 5));
      });
    });
  }

  void _stopTracking() {
    HapticFeedback.heavyImpact();
    _timer?.cancel();
    
    // Show save dialog
    _showSaveDialog();
  }

  void _showSaveDialog() {
    final nameController = TextEditingController(
      text: '${_getActivityTypeName()} - ${_formatDate(DateTime.now())}',
    );

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
              const Text(
                'Save Activity',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Gap(24),
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
                      value: '${_distance.toStringAsFixed(2)} km',
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: AppColors.darkDivider,
                    ),
                    _SummaryStat(
                      label: 'Duration',
                      value: _formatDuration(_duration),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: AppColors.darkDivider,
                    ),
                    _SummaryStat(
                      label: 'Pace',
                      value: _formatPace(),
                    ),
                  ],
                ),
              ),
              const Gap(24),
              GradientButton(
                onPressed: () {
                  // TODO: Save to Supabase
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.primaryGreen),
                          const Gap(12),
                          const Text('Activity saved!'),
                        ],
                      ),
                      backgroundColor: AppColors.darkCard,
                    ),
                  );
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
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close track screen
            },
            child: const Text(
              'Discard',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  String _getActivityTypeName() {
    switch (_selectedActivityType) {
      case 'run':
        return 'Run';
      case 'bike':
        return 'Bike Ride';
      case 'hike':
        return 'Hike';
      default:
        return 'Activity';
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
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

  String _formatPace() {
    if (_distance < 0.01) return '--:--';
    final paceMinutes = (_duration.inSeconds / 60) / _distance;
    final mins = paceMinutes.floor();
    final secs = ((paceMinutes - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')} /km';
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'run':
        return Icons.directions_run_rounded;
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
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: _trackingState == TrackingState.idle
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        automaticallyImplyLeading: false,
        title: _trackingState != TrackingState.idle
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
                          color: _trackingState == TrackingState.tracking
                              ? AppColors.primaryGreen.withOpacity(
                                  0.5 + 0.5 * _pulseController.value)
                              : AppColors.primaryOrange,
                        ),
                      );
                    },
                  ),
                  const Gap(8),
                  Text(
                    _trackingState == TrackingState.tracking
                        ? 'Recording'
                        : 'Paused',
                    style: TextStyle(
                      color: _trackingState == TrackingState.tracking
                          ? AppColors.primaryGreen
                          : AppColors.primaryOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Map placeholder
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.darkDivider),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 48,
                        color: AppColors.textMuted,
                      ),
                      const Gap(12),
                      Text(
                        _trackingState == TrackingState.idle
                            ? 'Map will appear here'
                            : 'GPS Tracking Active',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Metrics
            Expanded(
              flex: 2,
              child: _buildMetricsPanel(),
            ),

            // Controls
            if (_trackingState == TrackingState.idle)
              _buildActivitySelector()
            else
              _buildTrackingControls(),

            const Gap(32),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.darkDivider.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Duration
          Text(
            _formatDuration(_duration),
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w300,
              color: AppColors.textPrimary,
              letterSpacing: -2,
            ),
          ).animate().fadeIn(),
          
          const Gap(8),
          
          Text(
            'Duration',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),

          const Gap(24),

          // Distance and Pace
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MetricColumn(
                value: _distance.toStringAsFixed(2),
                unit: 'km',
                label: 'Distance',
                color: AppColors.runColor,
              ),
              Container(
                width: 1,
                height: 50,
                color: AppColors.darkDivider,
              ),
              _MetricColumn(
                value: _formatPace().split(' ')[0],
                unit: '/km',
                label: 'Pace',
                color: AppColors.bikeColor,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildActivitySelector() {
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
            children: ['run', 'bike', 'hike'].map((type) {
              final isSelected = _selectedActivityType == type;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedActivityType = type);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                AppColors.getActivityColor(type),
                                AppColors.getActivityColor(type).withOpacity(0.7),
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
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                          size: 20,
                        ),
                        const Gap(8),
                        Text(
                          type[0].toUpperCase() + type.substring(1),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
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
            onPressed: _startTracking,
            gradient: LinearGradient(
              colors: [
                AppColors.getActivityColor(_selectedActivityType),
                AppColors.getActivityColor(_selectedActivityType).withOpacity(0.7),
              ],
            ),
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow_rounded, size: 28),
                const Gap(8),
                const Text(
                  'Start',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildTrackingControls() {
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
            icon: _trackingState == TrackingState.tracking
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            label: _trackingState == TrackingState.tracking ? 'Pause' : 'Resume',
            color: AppColors.primaryGreen,
            size: 80,
            onPressed: _trackingState == TrackingState.tracking
                ? _pauseTracking
                : _resumeTracking,
          ),

          // Lock button (placeholder)
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
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                color: color,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const Gap(4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
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
              color: color.withOpacity(0.15),
              border: Border.all(color: color, width: 3),
            ),
            child: Icon(
              icon,
              color: color,
              size: size * 0.45,
            ),
          ),
        ),
        const Gap(8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStat({
    required this.label,
    required this.value,
  });

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
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
