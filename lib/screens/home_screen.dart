import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:trailzap/providers/auth_provider.dart';
import 'package:trailzap/screens/track_screen.dart';
import 'package:trailzap/utils/constants.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.accentGradient.createShader(bounds),
          child: const Text(
            'TrailZap',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              _showProfileMenu(context);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // TODO: Refresh activities
          await Future.delayed(const Duration(seconds: 1));
        },
        color: AppColors.primaryGreen,
        backgroundColor: AppColors.darkCard,
        child: CustomScrollView(
          slivers: [
            // Welcome Header
            SliverToBoxAdapter(
              child: _buildWelcomeHeader(user?.email ?? 'Athlete'),
            ),

            // Stats Summary
            SliverToBoxAdapter(
              child: _buildStatsSummary(),
            ),

            // Recent Activities Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Activities',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('See All'),
                    ),
                  ],
                ),
              ),
            ),

            // Activities List (Empty State for now)
            SliverToBoxAdapter(
              child: _buildEmptyState(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const TrackScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        },
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Start Activity'),
      ),
    );
  }

  Widget _buildWelcomeHeader(String name) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ).animate().fadeIn(duration: 400.ms),
          const Gap(4),
          Text(
            'Ready to move?',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.05),
        ],
      ),
    );
  }

  Widget _buildStatsSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.darkCard,
            AppColors.darkCard.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkDivider.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.insights_rounded,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
              const Gap(12),
              const Text(
                'This Week',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Gap(20),
          Row(
            children: [
              _StatItem(
                label: 'Distance',
                value: '0.0',
                unit: 'km',
                color: AppColors.runColor,
              ),
              _StatItem(
                label: 'Activities',
                value: '0',
                unit: '',
                color: AppColors.bikeColor,
              ),
              _StatItem(
                label: 'Time',
                value: '0',
                unit: 'min',
                color: AppColors.hikeColor,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05);
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.darkCard.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.darkDivider.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.directions_run_rounded,
              size: 40,
              color: AppColors.primaryGreen.withOpacity(0.6),
            ),
          ),
          const Gap(20),
          const Text(
            'No activities yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Gap(8),
          Text(
            'Start your first activity and it will\nappear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.darkDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Gap(24),
            _ProfileMenuItem(
              icon: Icons.person_outline,
              label: 'Edit Profile',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile editing coming soon!')),
                );
              },
            ),
            _ProfileMenuItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const Divider(color: AppColors.darkDivider),
            _ProfileMenuItem(
              icon: Icons.logout_rounded,
              label: 'Sign Out',
              color: Colors.red,
              onTap: () async {
                Navigator.pop(context);
                await ref.read(authNotifierProvider.notifier).signOut();
              },
            ),
            const Gap(24),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const Gap(4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const Gap(4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor = color ?? AppColors.textPrimary;

    return ListTile(
      leading: Icon(icon, color: itemColor),
      title: Text(
        label,
        style: TextStyle(
          color: itemColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }
}
