import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for managing foreground notifications during activity tracking
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int _trackingNotificationId = 888;
  static const String _channelId = 'trailzap_tracking';
  static const String _channelName = 'Activity Tracking';
  static const String _channelDescription = 'Shows current activity tracking status';

  bool _isInitialized = false;
  bool _hasPermission = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Request notification permission for Android 13+
    await _requestNotificationPermission();

    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
    
    // Create notification channel for Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _createNotificationChannel();
    }

    _isInitialized = true;
  }

  /// Request notification permission for Android 13+
  Future<void> _requestNotificationPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        final result = await Permission.notification.request();
        _hasPermission = result.isGranted;
        debugPrint('Notification permission: $result');
      } else {
        _hasPermission = status.isGranted;
      }
    } else {
      _hasPermission = true;
    }
  }

  /// Check if we have permission
  bool get hasPermission => _hasPermission;

  /// Create Android notification channel
  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.low, // Low to avoid sound
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Show tracking notification with initial state
  Future<void> showTrackingNotification({
    required String activityType,
    String duration = '00:00',
    String distance = '0.00 km',
    String pace = '--:--',
  }) async {
    if (!_isInitialized) await initialize();

    final activityEmoji = _getActivityEmoji(activityType);
    final activityName = _getActivityName(activityType);

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true, // Cannot be dismissed
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      showWhen: false,
      silent: true,
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
      // Show as expanded notification
      styleInformation: BigTextStyleInformation(
        '$activityEmoji $activityName in progress\n⏱️ $duration  •  📍 $distance  •  ⚡ $pace /km',
        contentTitle: 'TrailZap - Recording',
        summaryText: 'Tap to view',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _trackingNotificationId,
      'TrailZap - Recording $activityName',
      '⏱️ $duration  •  📍 $distance  •  ⚡ $pace /km',
      details,
    );
  }

  /// Update tracking notification with new metrics
  Future<void> updateTrackingNotification({
    required String activityType,
    required String duration,
    required String distance,
    required String pace,
    bool isPaused = false,
  }) async {
    if (!_isInitialized) return;

    final activityEmoji = _getActivityEmoji(activityType);
    final activityName = _getActivityName(activityType);
    final statusText = isPaused ? 'PAUSED' : 'Recording';

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      showWhen: false,
      silent: true,
      onlyAlertOnce: true, // Don't make sound on updates
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(
        '$activityEmoji $activityName - $statusText\n⏱️ $duration  •  📍 $distance  •  ⚡ $pace /km',
        contentTitle: 'TrailZap - $statusText',
        summaryText: 'Tap to view',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _trackingNotificationId,
      'TrailZap - $statusText',
      '⏱️ $duration  •  📍 $distance  •  ⚡ $pace /km',
      details,
    );
  }

  /// Cancel tracking notification
  Future<void> cancelTrackingNotification() async {
    await _notifications.cancel(_trackingNotificationId);
  }

  /// Get emoji for activity type
  String _getActivityEmoji(String type) {
    switch (type) {
      case 'run':
        return '🏃';
      case 'walk':
        return '🚶';
      case 'bike':
        return '🚴';
      case 'hike':
        return '🥾';
      default:
        return '🏃';
    }
  }

  /// Get display name for activity type
  String _getActivityName(String type) {
    switch (type) {
      case 'run':
        return 'Run';
      case 'walk':
        return 'Walk';
      case 'bike':
        return 'Bike Ride';
      case 'hike':
        return 'Hike';
      default:
        return 'Activity';
    }
  }
}
