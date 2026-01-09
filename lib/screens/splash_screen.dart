import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:trailzap/utils/constants.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo / Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.bolt_rounded,
                size: 64,
                color: Colors.white,
              ),
            )
                .animate(onPlay: (controller) => controller.repeat())
                .shimmer(duration: 2.seconds, color: Colors.white24)
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(delay: 200.ms),

            const SizedBox(height: 32),

            // App Name
            ShaderMask(
              shaderCallback: (bounds) => AppColors.accentGradient.createShader(bounds),
              child: const Text(
                'TrailZap',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),

            const SizedBox(height: 8),

            // Tagline
            Text(
              'Track your adventures',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ).animate().fadeIn(delay: 600.ms),

            const SizedBox(height: 60),

            // Loading indicator
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryGreen.withOpacity(0.7),
                ),
              ),
            ).animate().fadeIn(delay: 800.ms),
          ],
        ),
      ),
    );
  }
}
