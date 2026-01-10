import 'package:hive_flutter/hive_flutter.dart';
import 'package:trailzap/models/activity.dart';

/// Local storage service for offline activity caching
class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService instance = LocalStorageService._();

  static const String _pendingActivitiesBox = 'pending_activities';
  static const String _syncQueueBox = 'sync_queue';

  Box<Map>? _pendingBox;
  Box<String>? _syncQueueBoxInstance;

  bool _isInitialized = false;

  /// Initialize Hive storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    await Hive.initFlutter();
    
    _pendingBox = await Hive.openBox<Map>(_pendingActivitiesBox);
    _syncQueueBoxInstance = await Hive.openBox<String>(_syncQueueBox);

    _isInitialized = true;
  }

  /// Save an activity locally (pending sync)
  Future<String> savePendingActivity({
    required String name,
    required String type,
    required double distanceKm,
    required int durationSecs,
    required DateTime startTime,
    DateTime? endTime,
    String? mapPolyline,
    double? elevationGain,
    int? avgHr,
    String? description,
  }) async {
    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    
    final activityData = {
      'local_id': localId,
      'name': name,
      'type': type,
      'distance_km': distanceKm,
      'duration_secs': durationSecs,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'map_polyline': mapPolyline,
      'elevation_gain': elevationGain ?? 0,
      'avg_hr': avgHr,
      'description': description,
      'sync_status': 'pending', // pending, syncing, synced, failed
      'created_at': DateTime.now().toIso8601String(),
    };

    await _pendingBox?.put(localId, activityData);
    await _syncQueueBoxInstance?.add(localId);

    return localId;
  }

  /// Get all pending activities
  List<Map<String, dynamic>> getPendingActivities() {
    if (_pendingBox == null) return [];
    
    return _pendingBox!.values
        .where((item) => item['sync_status'] == 'pending')
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Get all locally stored activities (for display when offline)
  List<Map<String, dynamic>> getAllLocalActivities() {
    if (_pendingBox == null) return [];
    
    final activities = _pendingBox!.values
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    
    // Sort by start_time descending
    activities.sort((a, b) {
      final aTime = DateTime.parse(a['start_time'] as String);
      final bTime = DateTime.parse(b['start_time'] as String);
      return bTime.compareTo(aTime);
    });
    
    return activities;
  }

  /// Mark activity as syncing
  Future<void> markActivitySyncing(String localId) async {
    final data = _pendingBox?.get(localId);
    if (data != null) {
      data['sync_status'] = 'syncing';
      await _pendingBox?.put(localId, data);
    }
  }

  /// Mark activity as synced and remove from pending
  Future<void> markActivitySynced(String localId, String remoteId) async {
    final data = _pendingBox?.get(localId);
    if (data != null) {
      data['sync_status'] = 'synced';
      data['remote_id'] = remoteId;
      await _pendingBox?.put(localId, data);
    }
    
    // Remove from sync queue
    final queueValues = _syncQueueBoxInstance?.values.toList() ?? [];
    final index = queueValues.indexOf(localId);
    if (index >= 0) {
      await _syncQueueBoxInstance?.deleteAt(index);
    }
  }

  /// Mark activity as failed to sync
  Future<void> markActivityFailed(String localId, String error) async {
    final data = _pendingBox?.get(localId);
    if (data != null) {
      data['sync_status'] = 'failed';
      data['sync_error'] = error;
      await _pendingBox?.put(localId, data);
    }
  }

  /// Get count of pending activities
  int get pendingCount {
    if (_pendingBox == null) return 0;
    return _pendingBox!.values
        .where((item) => item['sync_status'] == 'pending' || item['sync_status'] == 'failed')
        .length;
  }

  /// Get sync queue
  List<String> getSyncQueue() {
    return _syncQueueBoxInstance?.values.toList() ?? [];
  }

  /// Clear all synced activities (cleanup)
  Future<void> clearSyncedActivities() async {
    if (_pendingBox == null) return;
    
    final keysToDelete = <String>[];
    for (final entry in _pendingBox!.toMap().entries) {
      if (entry.value['sync_status'] == 'synced') {
        keysToDelete.add(entry.key);
      }
    }
    
    for (final key in keysToDelete) {
      await _pendingBox!.delete(key);
    }
  }

  /// Delete a local activity
  Future<void> deleteLocalActivity(String localId) async {
    await _pendingBox?.delete(localId);
    
    final queueValues = _syncQueueBoxInstance?.values.toList() ?? [];
    final index = queueValues.indexOf(localId);
    if (index >= 0) {
      await _syncQueueBoxInstance?.deleteAt(index);
    }
  }

  /// Clear all failed activities
  Future<void> clearFailedActivities() async {
    if (_pendingBox == null) return;
    
    final keysToDelete = <String>[];
    for (final entry in _pendingBox!.toMap().entries) {
      if (entry.value['sync_status'] == 'failed') {
        keysToDelete.add(entry.key);
      }
    }
    
    for (final key in keysToDelete) {
      await _pendingBox!.delete(key);
      // Also remove from sync queue
      final queueValues = _syncQueueBoxInstance?.values.toList() ?? [];
      final index = queueValues.indexOf(key);
      if (index >= 0) {
        await _syncQueueBoxInstance?.deleteAt(index);
      }
    }
  }

  /// Clear all pending activities (nuclear option for stuck data)
  Future<void> clearAllPendingActivities() async {
    await _pendingBox?.clear();
    await _syncQueueBoxInstance?.clear();
  }
}
