import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trailzap/services/location_service.dart';
import 'package:trailzap/services/notification_service.dart';
import 'package:trailzap/utils/polyline_utils.dart';

/// Activity tracking state
enum TrackingState { idle, tracking, paused }

/// Service for managing activity tracking sessions
class TrackingService extends ChangeNotifier {
  TrackingService._();
  static final TrackingService instance = TrackingService._();

  final LocationService _locationService = LocationService.instance;
  final NotificationService _notificationService = NotificationService.instance;
  StreamSubscription<Position>? _positionSubscription;

  // Tracking state
  TrackingState _state = TrackingState.idle;
  TrackingState get state => _state;

  // Activity type
  String _activityType = 'run';
  String get activityType => _activityType;

  // Timer
  Timer? _timer;
  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  // Metrics
  double _distanceMeters = 0;
  double get distanceKm => _distanceMeters / 1000;

  double _elevationGain = 0;
  double get elevationGain => _elevationGain;

  double? _lastAltitude;

  // Track points
  final List<TrackPoint> _trackPoints = [];
  List<TrackPoint> get trackPoints => List.unmodifiable(_trackPoints);

  // Current position
  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  // Timestamps
  DateTime? _startTime;
  DateTime? get startTime => _startTime;

  DateTime? _endTime;

  // Pace calculation (min/km)
  double get paceMinPerKm {
    if (_distanceMeters < 10) return 0; // Need at least 10m
    final minutes = _duration.inSeconds / 60;
    return minutes / distanceKm;
  }

  // Speed calculation (km/h)
  double get speedKmh {
    if (_duration.inSeconds < 1) return 0;
    return distanceKm / (_duration.inSeconds / 3600);
  }

  /// Set activity type before starting
  void setActivityType(String type) {
    if (_state == TrackingState.idle) {
      _activityType = type;
      notifyListeners();
    }
  }

  /// Start tracking a new activity
  Future<bool> startTracking() async {
    if (_state != TrackingState.idle) return false;

    // Reset all metrics
    _reset();

    // Get initial position
    final position = await _locationService.getCurrentPosition();
    if (position == null) {
      debugPrint('Failed to get initial position');
      return false;
    }

    _currentPosition = position;
    _startTime = DateTime.now();

    // Add first track point
    _addTrackPoint(position);

    // Start location updates
    final started = await _locationService.startTracking(
      distanceFilter: 5,
      interval: const Duration(seconds: 2),
    );

    if (!started) {
      debugPrint('Failed to start location tracking');
      return false;
    }

    // Listen to position updates
    _positionSubscription = _locationService.positionStream.listen(_onPositionUpdate);

    // Start duration timer with notification updates
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _duration += const Duration(seconds: 1);
      _updateNotification();
      notifyListeners();
    });

    _state = TrackingState.tracking;
    notifyListeners();

    // Show initial notification
    await _notificationService.showTrackingNotification(
      activityType: _activityType,
    );

    return true;
  }

  /// Pause tracking
  void pauseTracking() {
    if (_state != TrackingState.tracking) return;

    _timer?.cancel();
    _positionSubscription?.pause();
    _state = TrackingState.paused;
    
    // Update notification to show paused state
    _notificationService.updateTrackingNotification(
      activityType: _activityType,
      duration: formatDuration(),
      distance: '${distanceKm.toStringAsFixed(2)} km',
      pace: formatPace(),
      isPaused: true,
    );
    
    notifyListeners();
  }

  /// Resume tracking
  void resumeTracking() {
    if (_state != TrackingState.paused) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _duration += const Duration(seconds: 1);
      notifyListeners();
    });

    _positionSubscription?.resume();
    _state = TrackingState.tracking;
    
    // Update notification to show resumed state
    _updateNotification();
    
    notifyListeners();
  }

  /// Stop tracking and return activity data
  Future<TrackingResult?> stopTracking() async {
    if (_state == TrackingState.idle) return null;

    _timer?.cancel();
    await _positionSubscription?.cancel();
    await _locationService.stopTracking();
    
    // Cancel notification
    await _notificationService.cancelTrackingNotification();

    _endTime = DateTime.now();
    _state = TrackingState.idle;

    // Generate polyline from track points
    final coordinates = _trackPoints
        .map((p) => [p.latitude, p.longitude])
        .toList();
    
    // Simplify polyline to reduce storage size (tolerance: 5 meters)
    final simplifiedCoords = PolylineUtils.simplify(coordinates, 5);
    final polyline = PolylineUtils.encode(simplifiedCoords);

    final result = TrackingResult(
      activityType: _activityType,
      distanceKm: distanceKm,
      durationSecs: _duration.inSeconds,
      paceMinPerKm: paceMinPerKm,
      startTime: _startTime!,
      endTime: _endTime!,
      mapPolyline: polyline,
      elevationGain: _elevationGain,
      trackPoints: List.from(_trackPoints),
      startLat: _trackPoints.isNotEmpty ? _trackPoints.first.latitude : null,
      startLng: _trackPoints.isNotEmpty ? _trackPoints.first.longitude : null,
      endLat: _trackPoints.isNotEmpty ? _trackPoints.last.latitude : null,
      endLng: _trackPoints.isNotEmpty ? _trackPoints.last.longitude : null,
    );

    notifyListeners();
    return result;
  }

  /// Discard current tracking session
  void discardTracking() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    _locationService.stopTracking();
    _notificationService.cancelTrackingNotification();
    _reset();
    _state = TrackingState.idle;
    notifyListeners();
  }
  
  /// Update notification with current metrics
  void _updateNotification() {
    _notificationService.updateTrackingNotification(
      activityType: _activityType,
      duration: formatDuration(),
      distance: '${distanceKm.toStringAsFixed(2)} km',
      pace: formatPace(),
      isPaused: false,
    );
  }

  /// Handle position updates
  void _onPositionUpdate(Position position) {
    if (_state != TrackingState.tracking) return;

    // Calculate distance from last point
    if (_currentPosition != null) {
      final distance = _locationService.calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      // Only add if moved at least 3 meters (reduce noise)
      if (distance >= 3) {
        _distanceMeters += distance;

        // Calculate elevation gain
        if (_lastAltitude != null && position.altitude > _lastAltitude!) {
          _elevationGain += position.altitude - _lastAltitude!;
        }
        _lastAltitude = position.altitude;

        _currentPosition = position;
        _addTrackPoint(position);
      }
    }

    notifyListeners();
  }

  /// Add a track point
  void _addTrackPoint(Position position) {
    _trackPoints.add(TrackPoint.fromPosition(position, _distanceMeters));
  }

  /// Reset all tracking data
  void _reset() {
    _duration = Duration.zero;
    _distanceMeters = 0;
    _elevationGain = 0;
    _lastAltitude = null;
    _trackPoints.clear();
    _currentPosition = null;
    _startTime = null;
    _endTime = null;
  }

  /// Format duration for display
  String formatDuration() {
    final hours = _duration.inHours;
    final minutes = _duration.inMinutes.remainder(60);
    final seconds = _duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format pace for display
  String formatPace() {
    if (paceMinPerKm <= 0 || paceMinPerKm.isInfinite || paceMinPerKm.isNaN) {
      return '--:--';
    }
    final mins = paceMinPerKm.floor();
    final secs = ((paceMinPerKm - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}

/// Result of a completed tracking session
class TrackingResult {
  final String activityType;
  final double distanceKm;
  final int durationSecs;
  final double paceMinPerKm;
  final DateTime startTime;
  final DateTime endTime;
  final String mapPolyline;
  final double elevationGain;
  final List<TrackPoint> trackPoints;
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;

  TrackingResult({
    required this.activityType,
    required this.distanceKm,
    required this.durationSecs,
    required this.paceMinPerKm,
    required this.startTime,
    required this.endTime,
    required this.mapPolyline,
    required this.elevationGain,
    required this.trackPoints,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
  });

  /// Generate default activity name
  String get defaultName {
    final typeNames = {
      'run': 'Run',
      'walk': 'Walk',
      'bike': 'Bike Ride',
      'hike': 'Hike',
    };
    final typeName = typeNames[activityType] ?? 'Activity';
    final timeOfDay = _getTimeOfDay(startTime);
    return '$timeOfDay $typeName';
  }

  String _getTimeOfDay(DateTime time) {
    final hour = time.hour;
    if (hour < 6) return 'Night';
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    if (hour < 21) return 'Evening';
    return 'Night';
  }
}
