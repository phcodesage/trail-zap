import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trailzap/models/activity.dart';
import 'package:trailzap/services/connectivity_service.dart';
import 'package:trailzap/services/local_storage_service.dart';
import 'package:trailzap/services/supabase_service.dart';
import 'package:trailzap/services/sync_service.dart';

/// Provider for Supabase service instance
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService.instance;
});

/// Provider for activities list
final activitiesProvider = StateNotifierProvider<ActivitiesNotifier, AsyncValue<List<Activity>>>((ref) {
  return ActivitiesNotifier(ref);
});

/// Provider for activities stream (realtime)
final activitiesStreamProvider = StreamProvider<List<Activity>>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return supabase.streamActivities();
});

/// Provider for user stats
final userStatsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final supabase = ref.watch(supabaseServiceProvider);
  return supabase.getUserStats();
});

/// Provider for weekly summary
final weeklySummaryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = ref.watch(supabaseServiceProvider);
  return supabase.getWeeklySummary();
});

/// Notifier for managing activities state
class ActivitiesNotifier extends StateNotifier<AsyncValue<List<Activity>>> {
  final Ref _ref;
  
  ActivitiesNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadActivities();
  }

  SupabaseService get _supabase => _ref.read(supabaseServiceProvider);
  ConnectivityService get _connectivity => ConnectivityService.instance;
  LocalStorageService get _localStorage => LocalStorageService.instance;
  SyncService get _syncService => SyncService.instance;

  /// Load all activities
  Future<void> loadActivities({String? type}) async {
    state = const AsyncValue.loading();
    try {
      final activities = await _supabase.getActivities(type: type);
      state = AsyncValue.data(activities);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Refresh activities (for pull-to-refresh)
  Future<void> refresh() async {
    try {
      final activities = await _supabase.getActivities();
      state = AsyncValue.data(activities);
    } catch (e, st) {
      // Keep old data on refresh error
      state = AsyncValue.error(e, st);
    }
  }

  /// Add a new activity (offline-first)
  Future<Activity?> addActivity({
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
    // Check if we're online
    final isOnline = _connectivity.isOnline;
    
    if (isOnline) {
      // Online: Try to save directly to Supabase
      try {
        final activity = await _supabase.saveActivity(
          name: name,
          type: type,
          distanceKm: distanceKm,
          durationSecs: durationSecs,
          startTime: startTime,
          endTime: endTime,
          mapPolyline: mapPolyline,
          elevationGain: elevationGain,
          avgHr: avgHr,
          description: description,
        );

        if (activity != null) {
          // Add to current list
          final currentActivities = state.value ?? [];
          state = AsyncValue.data([activity, ...currentActivities]);
          return activity;
        }
      } catch (e) {
        debugPrint('Failed to save online, falling back to local: $e');
        // Fall through to offline save
      }
    }
    
    // Offline or failed: Save locally
    debugPrint('Saving activity locally (offline mode)');
    final localId = await _localStorage.savePendingActivity(
      name: name,
      type: type,
      distanceKm: distanceKm,
      durationSecs: durationSecs,
      startTime: startTime,
      endTime: endTime,
      mapPolyline: mapPolyline,
      elevationGain: elevationGain,
      avgHr: avgHr,
      description: description,
    );
    
    debugPrint('Saved locally with ID: $localId');
    
    // If we're online, try to sync immediately
    if (isOnline) {
      _syncService.syncPendingActivities();
    }
    
    return null; // Return null to indicate local save (not synced yet)
  }

  /// Update an activity
  Future<bool> updateActivity(String activityId, Map<String, dynamic> updates) async {
    try {
      final success = await _supabase.updateActivity(activityId, updates);
      if (success) {
        // Refresh to get updated data
        await refresh();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// Delete an activity
  Future<bool> deleteActivity(String activityId) async {
    try {
      final success = await _supabase.deleteActivity(activityId);
      if (success) {
        // Remove from current list
        final currentActivities = state.value ?? [];
        state = AsyncValue.data(
          currentActivities.where((a) => a.id != activityId).toList(),
        );
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// Get activities filtered by type
  Future<void> filterByType(String? type) async {
    await loadActivities(type: type);
  }
}
