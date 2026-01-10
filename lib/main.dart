import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trailzap/app.dart';
import 'package:trailzap/services/connectivity_service.dart';
import 'package:trailzap/services/local_storage_service.dart';
import 'package:trailzap/services/notification_service.dart';
import 'package:trailzap/services/sync_service.dart';
import 'package:trailzap/services/tracking_service.dart';
import 'package:trailzap/utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Hive for all local storage
  await Hive.initFlutter();

  // Initialize local storage (Hive)
  await LocalStorageService.instance.initialize();
  
  // Clear any stuck failed activities on startup
  await LocalStorageService.instance.clearFailedActivities();

  // Initialize Supabase with env variables
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // Initialize connectivity monitoring
  await ConnectivityService.instance.initialize();

  // Initialize sync service (depends on connectivity)
  await SyncService.instance.initialize();

  // Initialize notification service for tracking
  await NotificationService.instance.initialize();

  // Initialize tracking service (checks for recoverable sessions)
  await TrackingService.instance.initialize();

  runApp(
    const ProviderScope(
      child: TrailZapApp(),
    ),
  );
}
