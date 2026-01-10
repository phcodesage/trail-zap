import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:trailzap/models/activity.dart';
import 'package:trailzap/providers/activities_provider.dart';
import 'package:trailzap/screens/activity_detail_screen.dart';
import 'package:trailzap/utils/constants.dart';

/// Filter type for activities
enum ActivityFilter { all, run, walk, bike, hike }

class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen> {
  ActivityFilter _filter = ActivityFilter.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(activitiesProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: const Text('All Activities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search activities...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.darkCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: ActivityFilter.values.map((filter) {
                final isSelected = _filter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_getFilterLabel(filter)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _filter = filter);
                      HapticFeedback.selectionClick();
                    },
                    selectedColor: _getFilterColor(filter).withOpacity(0.3),
                    checkmarkColor: _getFilterColor(filter),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? _getFilterColor(filter)
                          : AppColors.textSecondary,
                    ),
                    backgroundColor: AppColors.darkCard,
                    side: BorderSide(
                      color: isSelected
                          ? _getFilterColor(filter)
                          : AppColors.darkDivider,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Activities List
          Expanded(
            child: activitiesAsync.when(
              data: (activities) {
                final filtered = _filterActivities(activities);
                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }
                return _buildGroupedActivitiesList(filtered);
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const Gap(16),
                    Text('Failed to load activities'),
                    const Gap(8),
                    TextButton(
                      onPressed: () => ref.read(activitiesProvider.notifier).refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Activity> _filterActivities(List<Activity> activities) {
    var filtered = activities;

    // Filter by type
    if (_filter != ActivityFilter.all) {
      final typeStr = _filter.name;
      filtered = filtered.where((a) => a.type == typeStr).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((a) =>
          a.name.toLowerCase().contains(query) ||
          a.type.toLowerCase().contains(query)
      ).toList();
    }

    return filtered;
  }

  Widget _buildGroupedActivitiesList(List<Activity> activities) {
    // Group activities by date
    final grouped = <String, List<Activity>>{};
    for (final activity in activities) {
      final dateKey = _getDateGroupKey(activity.startTime);
      grouped.putIfAbsent(dateKey, () => []).add(activity);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(activitiesProvider.notifier).refresh(),
      color: AppColors.primaryGreen,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final date = grouped.keys.elementAt(index);
          final dateActivities = grouped[date]!;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  date,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              // Activities for this date
              ...dateActivities.asMap().entries.map((entry) {
                return _ActivityListItem(
                  activity: entry.value,
                  onTap: () => _openActivityDetail(entry.value),
                ).animate().fadeIn(delay: (50 * entry.key).ms).slideX(begin: 0.03);
              }),
            ],
          );
        },
      ),
    );
  }

  String _getDateGroupKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final activityDate = DateTime(date.year, date.month, date.day);

    if (activityDate == today) {
      return 'Today';
    } else if (activityDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else if (date.year == now.year) {
      return DateFormat('MMMM d').format(date);
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  void _openActivityDetail(Activity activity) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityDetailScreen(activity: activity),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _filter == ActivityFilter.all ? Icons.fitness_center : _getFilterIcon(_filter),
            size: 64,
            color: AppColors.textMuted,
          ),
          const Gap(16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No activities matching "$_searchQuery"'
                : _filter == ActivityFilter.all
                    ? 'No activities yet'
                    : 'No ${_getFilterLabel(_filter).toLowerCase()} activities',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Activities',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Gap(20),
              ...ActivityFilter.values.map((filter) => ListTile(
                leading: Icon(
                  filter == ActivityFilter.all
                      ? Icons.all_inclusive
                      : _getFilterIcon(filter),
                  color: _getFilterColor(filter),
                ),
                title: Text(_getFilterLabel(filter)),
                trailing: _filter == filter
                    ? Icon(Icons.check, color: AppColors.primaryGreen)
                    : null,
                onTap: () {
                  setState(() => _filter = filter);
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  String _getFilterLabel(ActivityFilter filter) {
    switch (filter) {
      case ActivityFilter.all:
        return 'All';
      case ActivityFilter.run:
        return 'Runs';
      case ActivityFilter.walk:
        return 'Walks';
      case ActivityFilter.bike:
        return 'Bike Rides';
      case ActivityFilter.hike:
        return 'Hikes';
    }
  }

  Color _getFilterColor(ActivityFilter filter) {
    switch (filter) {
      case ActivityFilter.all:
        return AppColors.primaryGreen;
      case ActivityFilter.run:
        return AppColors.runColor;
      case ActivityFilter.walk:
        return AppColors.walkColor;
      case ActivityFilter.bike:
        return AppColors.bikeColor;
      case ActivityFilter.hike:
        return AppColors.hikeColor;
    }
  }

  IconData _getFilterIcon(ActivityFilter filter) {
    switch (filter) {
      case ActivityFilter.all:
        return Icons.all_inclusive;
      case ActivityFilter.run:
        return Icons.directions_run;
      case ActivityFilter.walk:
        return Icons.directions_walk;
      case ActivityFilter.bike:
        return Icons.directions_bike;
      case ActivityFilter.hike:
        return Icons.terrain;
    }
  }
}

/// Individual activity list item
class _ActivityListItem extends StatelessWidget {
  final Activity activity;
  final VoidCallback onTap;

  const _ActivityListItem({
    required this.activity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.getActivityColor(activity.type);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkDivider.withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Activity Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getActivityIcon(activity.type),
                    color: color,
                    size: 26,
                  ),
                ),
                const Gap(16),

                // Activity Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
                          const Gap(4),
                          Text(
                            DateFormat.jm().format(activity.startTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Stats
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          activity.distanceKm.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        Text(
                          ' km',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Gap(2),
                    Text(
                      _formatDuration(activity.durationSecs),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const Gap(8),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'run':
        return Icons.directions_run;
      case 'walk':
        return Icons.directions_walk;
      case 'bike':
        return Icons.directions_bike;
      case 'hike':
        return Icons.terrain;
      default:
        return Icons.fitness_center;
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}:${secs.toString().padLeft(2, '0')}';
  }
}
