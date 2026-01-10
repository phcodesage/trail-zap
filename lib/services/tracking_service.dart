import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trailzap/services/location_service.dart';
import 'package:trailzap/services/notification_service.dart';
import 'package:trailzap/utils/polyline_utils.dart';

/// Activity tracking state
enum TrackingState { idle, tracking, paused }

/// Service for managing activity tracking sessions with session recovery
class TrackingService extends ChangeNotifier {
  TrackingService._();
  static final TrackingService instance = TrackingService._();

  static const String _sessionBoxName = 'tracking_session';
  static const String _sessionKey = 'active_session';
  static const int _autoSaveIntervalSeconds = 10;

  final LocationService _locationService = LocationService.instance;
  final NotificationService _notificationService = NotificationService.instance;
  StreamSubscription<Position>? _positionSubscription;
  Box? _sessionBox;

  // Tracking state
  TrackingState _state = TrackingState.idle;
  TrackingState get state => _state;

  // Activity type
  String _activityType = 'run';
  String get activityType => _activityType;

  // Timer
  Timer? _timer;
  Timer? _autoSaveTimer;
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

  // Recovery state
  bool _hasRecoverableSession = false;
  bool get hasRecoverableSession => _hasRecoverableSession;
  Map<String, dynamic>? _recoveredSessionData;

  // Pace calculation (min/km)
  double get paceMinPerKm {
    if (_distanceMeters < 10) return 0;
    final minutes = _duration.inSeconds / 60;
    return minutes / distanceKm;
  }

  // Speed calculation (km/h)
  double get speedKmh {
    if (_duration.inSeconds < 1) return 0;
    return distanceKm / (_duration.inSeconds / 3600);
  }

  /// Initialize session storage and check for recoverable session
  Future<void> initialize() async {
    _sessionBox = await Hive.openBox(_sessionBoxName);
    await _checkForRecoverableSession();
  }

  /// Check if there's a session that can be recovered
  Future<void> _checkForRecoverableSession() async {
    final savedSession = _sessionBox?.get(_sessionKey);
    if (savedSession != null) {
      try {
        final data = Map<String, dynamic>.from(savedSession);
        final savedState = data['state'] as String?;
        
        // Only recover if was tracking or paused
        if (savedState == 'tracking' || savedState == 'paused') {
          _hasRecoverableSession = true;
          _recoveredSessionData = data;
          debugPrint('Found recoverable session: ${data['activity_type']} - ${data['duration_secs']}s');
          notifyListeners();
        } else {
          // Clear stale idle session
          await _clearSavedSession();
        }
      } catch (e) {
        debugPrint('Error checking recoverable session: $e');
        await _clearSavedSession();
      }
    }
  }

  /// Get recovered session info for display
  Map<String, dynamic>? get recoveredSessionInfo => _recoveredSessionData;

  /// Recover session from saved state
  Future<bool> recoverSession() async {
    if (_recoveredSessionData == null) return false;

    try {
      final data = _recoveredSessionData!;
      
      // Restore state
      _activityType = data['activity_type'] as String? ?? 'run';
      _duration = Duration(seconds: data['duration_secs'] as int? ?? 0);
      _distanceMeters = (data['distance_meters'] as num?)?.toDouble() ?? 0;
      _elevationGain = (data['elevation_gain'] as num?)?.toDouble() ?? 0;
      _startTime = DateTime.tryParse(data['start_time'] as String? ?? '');
      
      // Restore track points
      final pointsJson = data['track_points'] as List?;
      if (pointsJson != null) {
        _trackPoints.clear();
        for (final p in pointsJson) {
          _trackPoints.add(TrackPoint.fromJson(Map<String, dynamic>.from(p)));
        }
      }

      // Set to paused state (user can resume)
      _state = TrackingState.paused;
      _hasRecoverableSession = false;
      _recoveredSessionData = null;

      debugPrint('Session recovered: ${_trackPoints.length} points, ${_duration.inSeconds}s');
      notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('Error recovering session: $e');
      await discardRecoveredSession();
      return false;
    }
  }

  /// Discard recovered session
  Future<void> discardRecoveredSession() async {
    _hasRecoverableSession = false;
    _recoveredSessionData = null;
    await _clearSavedSession();
    notifyListeners();
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

    // Start duration timer
    _startTimers();

    _state = TrackingState.tracking;
    notifyListeners();

    // Save initial state
    await _saveSession();

    // Show notification
    await _notificationService.showTrackingNotification(
      activityType: _activityType,
    );

    return true;
  }

  /// Resume tracking from paused or recovered state
  Future<bool> resumeTracking() async {
    if (_state == TrackingState.idle && _hasRecoverableSession) {
      // Recover first, then resume
      final recovered = await recoverSession();
      if (!recovered) return false;
    }

    if (_state != TrackingState.paused) return false;

    // Start location updates if not already running
    final started = await _locationService.startTracking(
      distanceFilter: 5,
      interval: const Duration(seconds: 2),
    );

    if (!started) {
      debugPrint('Failed to resume location tracking');
      return false;
    }

    _positionSubscription?.cancel();
    _positionSubscription = _locationService.positionStream.listen(_onPositionUpdate);

    // Start timers
    _startTimers();

    _state = TrackingState.tracking;
    
    // Update notification
    _updateNotification();
    
    notifyListeners();
    return true;
  }

  /// Pause tracking
  void pauseTracking() {
    if (_state != TrackingState.tracking) return;

    _timer?.cancel();
    _autoSaveTimer?.cancel();
    _positionSubscription?.pause();
    _state = TrackingState.paused;
    
    // Save state immediately on pause
    _saveSession();
    
    // Update notification
    _notificationService.updateTrackingNotification(
      activityType: _activityType,
      duration: formatDuration(),
      distance: '${distanceKm.toStringAsFixed(2)} km',
      pace: formatPace(),
      isPaused: true,
    );
    
    notifyListeners();
  }

  /// Stop tracking and return activity data
  Future<TrackingResult?> stopTracking() async {
    if (_state == TrackingState.idle) return null;

    _timer?.cancel();
    _autoSaveTimer?.cancel();
    await _positionSubscription?.cancel();
    await _locationService.stopTracking();
    
    // Cancel notification
    await _notificationService.cancelTrackingNotification();

    // Clear saved session
    await _clearSavedSession();

    _endTime = DateTime.now();
    _state = TrackingState.idle;

    // Generate polyline from track points
    final coordinates = _trackPoints
        .map((p) => [p.latitude, p.longitude])
        .toList();
    
    // Simplify polyline to reduce storage size
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
  Future<void> discardTracking() async {
    _timer?.cancel();
    _autoSaveTimer?.cancel();
    _positionSubscription?.cancel();
    _locationService.stopTracking();
    _notificationService.cancelTrackingNotification();
    await _clearSavedSession();
    _reset();
    _state = TrackingState.idle;
    notifyListeners();
  }

  /// Start duration and auto-save timers
  void _startTimers() {
    _timer?.cancel();
    _autoSaveTimer?.cancel();

    // Duration timer - every second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _duration += const Duration(seconds: 1);
      _updateNotification();
      notifyListeners();
    });

    // Auto-save timer - every 10 seconds
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: _autoSaveIntervalSeconds), 
      (_) => _saveSession(),
    );
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

  /// Save current session state to Hive
  Future<void> _saveSession() async {
    if (_state == TrackingState.idle) return;
    
    try {
      final sessionData = {
        'state': _state == TrackingState.tracking ? 'tracking' : 'paused',
        'activity_type': _activityType,
        'duration_secs': _duration.inSeconds,
        'distance_meters': _distanceMeters,
        'elevation_gain': _elevationGain,
        'start_time': _startTime?.toIso8601String(),
        'saved_at': DateTime.now().toIso8601String(),
        'track_points': _trackPoints.map((p) => p.toJson()).toList(),
      };
      
      await _sessionBox?.put(_sessionKey, sessionData);
      debugPrint('Session auto-saved: ${_trackPoints.length} points');
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  /// Clear saved session
  Future<void> _clearSavedSession() async {
    await _sessionBox?.delete(_sessionKey);
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

  /// Reset tracking state if idle (called when reopening TrackScreen)
  void resetIfIdle() {
    if (_state == TrackingState.idle && !_hasRecoverableSession) {
      _reset();
      notifyListeners();
    }
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
    _autoSaveTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }
}

/// Single GPS track point
class TrackPoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;
  final double accuracy;
  final DateTime timestamp;
  final double distanceFromStart;

  TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
    required this.accuracy,
    required this.timestamp,
    required this.distanceFromStart,
  });

  factory TrackPoint.fromPosition(Position position, double distance) {
    return TrackPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      speed: position.speed,
      accuracy: position.accuracy,
      timestamp: DateTime.now(),
      distanceFromStart: distance,
    );
  }

  factory TrackPoint.fromJson(Map<String, dynamic> json) {
    return TrackPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble() ?? 0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      distanceFromStart: (json['distance_from_start'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
      'distance_from_start': distanceFromStart,
    };
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
