import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trailzap/models/activity.dart';
import 'package:trailzap/models/profile.dart';

/// Service for Supabase database operations
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  final _client = Supabase.instance.client;

  /// Get current user ID
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUserId != null;

  // ==================== PROFILE OPERATIONS ====================

  /// Get current user's profile
  Future<Profile?> getCurrentProfile() async {
    if (currentUserId == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', currentUserId!)
          .single();
      
      return Profile.fromJson(response);
    } catch (e) {
      print('Error getting profile: $e');
      return null;
    }
  }

  /// Update current user's profile
  Future<bool> updateProfile({
    String? username,
    String? fullName,
    String? avatarUrl,
    String? bio,
    String? preferredUnits,
    double? weeklyGoalKm,
  }) async {
    if (currentUserId == null) return false;

    try {
      final updates = <String, dynamic>{};
      if (username != null) updates['username'] = username;
      if (fullName != null) updates['full_name'] = fullName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (bio != null) updates['bio'] = bio;
      if (preferredUnits != null) updates['preferred_units'] = preferredUnits;
      if (weeklyGoalKm != null) updates['weekly_goal_km'] = weeklyGoalKm;

      await _client
          .from('profiles')
          .update(updates)
          .eq('id', currentUserId!);

      return true;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }

  // ==================== ACTIVITY OPERATIONS ====================

  /// Get all activities for current user
  Future<List<Activity>> getActivities({
    int limit = 50,
    int offset = 0,
    String? type,
  }) async {
    if (currentUserId == null) return [];

    try {
      var query = _client
          .from('activities')
          .select()
          .eq('user_id', currentUserId!)
          .order('start_time', ascending: false)
          .range(offset, offset + limit - 1);

      if (type != null) {
        query = query.eq('type', type);
      }

      final response = await query;
      return (response as List).map((json) => Activity.fromJson(json)).toList();
    } catch (e) {
      print('Error getting activities: $e');
      return [];
    }
  }

  /// Get a single activity by ID
  Future<Activity?> getActivity(String activityId) async {
    try {
      final response = await _client
          .from('activities')
          .select()
          .eq('id', activityId)
          .single();

      return Activity.fromJson(response);
    } catch (e) {
      print('Error getting activity: $e');
      return null;
    }
  }

  /// Save a new activity
  Future<Activity?> saveActivity({
    required String name,
    required String type,
    required double distanceKm,
    required int durationSecs,
    required DateTime startTime,
    DateTime? endTime,
    String? mapPolyline,
    double? elevationGain,
    double? elevationLoss,
    int? avgHr,
    int? maxHr,
    String? description,
    bool isManualEntry = false,
  }) async {
    if (currentUserId == null) return null;

    try {
      final data = {
        'user_id': currentUserId,
        'name': name,
        'type': type,
        'distance_km': distanceKm,
        'duration_secs': durationSecs,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'map_polyline': mapPolyline,
        'elevation_gain': elevationGain ?? 0,
        'elevation_loss': elevationLoss ?? 0,
        'avg_hr': avgHr,
        'max_hr': maxHr,
        'description': description,
        'is_manual_entry': isManualEntry,
      };

      final response = await _client
          .from('activities')
          .insert(data)
          .select()
          .single();

      return Activity.fromJson(response);
    } catch (e) {
      print('Error saving activity: $e');
      return null;
    }
  }

  /// Update an existing activity
  Future<bool> updateActivity(String activityId, Map<String, dynamic> updates) async {
    try {
      await _client
          .from('activities')
          .update(updates)
          .eq('id', activityId)
          .eq('user_id', currentUserId!);

      return true;
    } catch (e) {
      print('Error updating activity: $e');
      return false;
    }
  }

  /// Delete an activity
  Future<bool> deleteActivity(String activityId) async {
    try {
      await _client
          .from('activities')
          .delete()
          .eq('id', activityId)
          .eq('user_id', currentUserId!);

      return true;
    } catch (e) {
      print('Error deleting activity: $e');
      return false;
    }
  }

  /// Stream activities for realtime updates
  Stream<List<Activity>> streamActivities() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _client
        .from('activities')
        .stream(primaryKey: ['id'])
        .eq('user_id', currentUserId!)
        .order('start_time', ascending: false)
        .map((list) => list.map((json) => Activity.fromJson(json)).toList());
  }

  // ==================== STATS OPERATIONS ====================

  /// Get user stats summary
  Future<Map<String, dynamic>?> getUserStats() async {
    if (currentUserId == null) return null;

    try {
      final response = await _client
          .from('user_stats')
          .select()
          .eq('user_id', currentUserId!)
          .single();

      return response;
    } catch (e) {
      print('Error getting user stats: $e');
      return null;
    }
  }

  /// Get weekly summary
  Future<List<Map<String, dynamic>>> getWeeklySummary() async {
    if (currentUserId == null) return [];

    try {
      final response = await _client
          .from('weekly_summary')
          .select()
          .eq('user_id', currentUserId!)
          .order('week_start', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting weekly summary: $e');
      return [];
    }
  }

  /// Get activities for a specific date range (for calendar view)
  Future<List<Activity>> getActivitiesInRange(DateTime start, DateTime end) async {
    if (currentUserId == null) return [];

    try {
      final response = await _client
          .from('activities')
          .select()
          .eq('user_id', currentUserId!)
          .gte('start_time', start.toIso8601String())
          .lte('start_time', end.toIso8601String())
          .order('start_time', ascending: false);

      return (response as List).map((json) => Activity.fromJson(json)).toList();
    } catch (e) {
      print('Error getting activities in range: $e');
      return [];
    }
  }
}
