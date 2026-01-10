class Activity {
  final String id;
  final String userId;
  final String name;
  final String type; // 'run', 'bike', 'hike'
  final double distanceKm;
  final int durationSecs;
  final double? paceMinPerKm;
  final DateTime startTime;
  final DateTime? endTime;
  final String? mapPolyline;
  final double elevationGain;
  final int? avgHr;
  final DateTime createdAt;
  final String? description;

  Activity({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.distanceKm,
    required this.durationSecs,
    this.paceMinPerKm,
    required this.startTime,
    this.endTime,
    this.mapPolyline,
    this.elevationGain = 0,
    this.avgHr,
    required this.createdAt,
    this.description,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      distanceKm: (json['distance_km'] as num).toDouble(),
      durationSecs: json['duration_secs'] as int,
      paceMinPerKm: json['pace_min_per_km'] != null
          ? (json['pace_min_per_km'] as num).toDouble()
          : null,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      mapPolyline: json['map_polyline'] as String?,
      elevationGain: (json['elevation_gain'] as num?)?.toDouble() ?? 0,
      avgHr: json['avg_hr'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'type': type,
      'distance_km': distanceKm,
      'duration_secs': durationSecs,
      'pace_min_per_km': paceMinPerKm,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'map_polyline': mapPolyline,
      'elevation_gain': elevationGain,
      'avg_hr': avgHr,
      'created_at': createdAt.toIso8601String(),
      'description': description,
    };
  }

  /// For inserting new activity (excludes auto-generated fields)
  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'name': name,
      'type': type,
      'distance_km': distanceKm,
      'duration_secs': durationSecs,
      'pace_min_per_km': paceMinPerKm,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'map_polyline': mapPolyline,
      'elevation_gain': elevationGain,
      'avg_hr': avgHr,
      'description': description,
    };
  }

  Activity copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    double? distanceKm,
    int? durationSecs,
    double? paceMinPerKm,
    DateTime? startTime,
    DateTime? endTime,
    String? mapPolyline,
    double? elevationGain,
    int? avgHr,
    DateTime? createdAt,
    String? description,
  }) {
    return Activity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      distanceKm: distanceKm ?? this.distanceKm,
      durationSecs: durationSecs ?? this.durationSecs,
      paceMinPerKm: paceMinPerKm ?? this.paceMinPerKm,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      mapPolyline: mapPolyline ?? this.mapPolyline,
      elevationGain: elevationGain ?? this.elevationGain,
      avgHr: avgHr ?? this.avgHr,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
    );
  }

  /// Get formatted duration string
  String get formattedDuration {
    final hours = durationSecs ~/ 3600;
    final minutes = (durationSecs % 3600) ~/ 60;
    final seconds = durationSecs % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m ${seconds}s';
  }

  /// Get formatted distance string
  String get formattedDistance {
    if (distanceKm >= 10) {
      return '${distanceKm.toStringAsFixed(1)} km';
    }
    return '${distanceKm.toStringAsFixed(2)} km';
  }

  /// Get formatted pace string
  String get formattedPace {
    if (paceMinPerKm == null || paceMinPerKm == 0) {
      return '--:--';
    }
    final paceMinutes = paceMinPerKm!.floor();
    final paceSeconds = ((paceMinPerKm! - paceMinutes) * 60).round();
    return '$paceMinutes:${paceSeconds.toString().padLeft(2, '0')} /km';
  }

  /// Get activity type display name
  String get typeDisplayName {
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
        return type;
    }
  }
}
