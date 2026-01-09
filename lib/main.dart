import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trailzap/app.dart';
import 'package:trailzap/services/notification_service.dart';
import 'package:trailzap/utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Supabase with env variables
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // Initialize notification service for tracking
  await NotificationService.instance.initialize();

  runApp(
    const ProviderScope(
      child: TrailZapApp(),
    ),
  );
}
