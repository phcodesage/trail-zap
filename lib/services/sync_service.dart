import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:trailzap/services/connectivity_service.dart';
import 'package:trailzap/services/local_storage_service.dart';
import 'package:trailzap/services/supabase_service.dart';

/// Sync status for activities
enum SyncStatus { idle, syncing, completed, failed }

/// Service for syncing local activities to cloud
class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService instance = SyncService._();

  final ConnectivityService _connectivity = ConnectivityService.instance;
  final LocalStorageService _localStorage = LocalStorageService.instance;
  final SupabaseService _supabase = SupabaseService.instance;

  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  int _syncedCount = 0;
  int get syncedCount => _syncedCount;

  int _totalToSync = 0;
  int get totalToSync => _totalToSync;

  String? _lastError;
  String? get lastError => _lastError;

  bool _isInitialized = false;
  StreamSubscription? _connectivitySubscription;

  /// Initialize sync service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Listen to connectivity changes to trigger sync
    _connectivity.addListener(_onConnectivityChanged);
    
    _isInitialized = true;

    // Try initial sync if online
    if (_connectivity.isOnline) {
      await syncPendingActivities();
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged() {
    if (_connectivity.isOnline && _status == SyncStatus.idle) {
      // Back online - try to sync
      syncPendingActivities();
    }
  }

  /// Sync all pending activities to cloud
  Future<bool> syncPendingActivities() async {
    if (_status == SyncStatus.syncing) return false;
    if (!_connectivity.isOnline) return false;
    if (!_supabase.isAuthenticated) return false;

    final pending = _localStorage.getPendingActivities();
    if (pending.isEmpty) return true;

    _status = SyncStatus.syncing;
    _syncedCount = 0;
    _totalToSync = pending.length;
    _lastError = null;
    notifyListeners();

    debugPrint('Starting sync of ${pending.length} activities');

    bool allSynced = true;

    for (final activity in pending) {
      final localId = activity['local_id'] as String;
      
      try {
        await _localStorage.markActivitySyncing(localId);
        
        final activityType = activity['type'] as String;
        debugPrint('Syncing activity $localId with type: "$activityType"');
        
        // Upload to Supabase
        final result = await _supabase.saveActivity(
          name: activity['name'] as String,
          type: activityType,
          distanceKm: (activity['distance_km'] as num).toDouble(),
          durationSecs: activity['duration_secs'] as int,
          startTime: DateTime.parse(activity['start_time'] as String),
          endTime: activity['end_time'] != null 
              ? DateTime.parse(activity['end_time'] as String) 
              : null,
          mapPolyline: activity['map_polyline'] as String?,
          elevationGain: (activity['elevation_gain'] as num?)?.toDouble(),
          avgHr: activity['avg_hr'] as int?,
          description: activity['description'] as String?,
        );

        if (result != null) {
          await _localStorage.markActivitySynced(localId, result.id);
          _syncedCount++;
          debugPrint('Synced activity: $localId -> ${result.id}');
        } else {
          await _localStorage.markActivityFailed(localId, 'Upload failed');
          allSynced = false;
        }
      } catch (e) {
        debugPrint('Failed to sync activity $localId: $e');
        await _localStorage.markActivityFailed(localId, e.toString());
        _lastError = e.toString();
        allSynced = false;
      }

      notifyListeners();
    }

    _status = allSynced ? SyncStatus.completed : SyncStatus.failed;
    notifyListeners();

    // Reset to idle after a delay
    Future.delayed(const Duration(seconds: 3), () {
      _status = SyncStatus.idle;
      notifyListeners();
    });

    // Cleanup synced activities
    await _localStorage.clearSyncedActivities();

    return allSynced;
  }

  /// Get pending count
  int get pendingCount => _localStorage.pendingCount;

  /// Dispose
  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivityChanged);
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
