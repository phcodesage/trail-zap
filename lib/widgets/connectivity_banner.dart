import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trailzap/services/connectivity_service.dart';
import 'package:trailzap/services/sync_service.dart';
import 'package:trailzap/utils/constants.dart';

/// Provider for connectivity service
final connectivityProvider = ChangeNotifierProvider<ConnectivityService>((ref) {
  return ConnectivityService.instance;
});

/// Provider for sync service
final syncProvider = ChangeNotifierProvider<SyncService>((ref) {
  return SyncService.instance;
});

/// A banner that shows connectivity status and sync progress
class ConnectivityBanner extends ConsumerWidget {
  final Widget child;

  const ConnectivityBanner({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);
    final sync = ref.watch(syncProvider);
    
    return Column(
      children: [
        // Connectivity Banner
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: !connectivity.isOnline || sync.status == SyncStatus.syncing
              ? null
              : 0,
          child: Material(
            color: _getBannerColor(connectivity, sync),
            child: SafeArea(
              bottom: false,
              child: _buildBannerContent(connectivity, sync),
            ),
          ),
        ),
        
        // Main content
        Expanded(child: child),
      ],
    );
  }

  Color _getBannerColor(ConnectivityService connectivity, SyncService sync) {
    if (!connectivity.isOnline) {
      return Colors.red.shade700;
    }
    if (sync.status == SyncStatus.syncing) {
      return Colors.blue.shade600;
    }
    if (sync.status == SyncStatus.completed) {
      return AppColors.primaryGreen;
    }
    if (sync.status == SyncStatus.failed) {
      return Colors.orange.shade700;
    }
    return Colors.transparent;
  }

  Widget _buildBannerContent(ConnectivityService connectivity, SyncService sync) {
    if (!connectivity.isOnline) {
      return _OfflineBanner(pendingCount: sync.pendingCount);
    }
    
    if (sync.status == SyncStatus.syncing) {
      return _SyncingBanner(
        syncedCount: sync.syncedCount,
        totalCount: sync.totalToSync,
      );
    }
    
    if (sync.status == SyncStatus.completed && sync.syncedCount > 0) {
      return _SyncCompleteBanner(syncedCount: sync.syncedCount);
    }
    
    if (sync.status == SyncStatus.failed) {
      return _SyncFailedBanner(error: sync.lastError);
    }
    
    return const SizedBox.shrink();
  }
}

class _OfflineBanner extends StatelessWidget {
  final int pendingCount;

  const _OfflineBanner({required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              pendingCount > 0
                  ? 'No internet • $pendingCount ${pendingCount == 1 ? 'activity' : 'activities'} pending sync'
                  : 'No internet connection',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncingBanner extends StatelessWidget {
  final int syncedCount;
  final int totalCount;

  const _SyncingBanner({
    required this.syncedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Syncing activities... ($syncedCount/$totalCount)',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncCompleteBanner extends StatelessWidget {
  final int syncedCount;

  const _SyncCompleteBanner({required this.syncedCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.cloud_done, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$syncedCount ${syncedCount == 1 ? 'activity' : 'activities'} synced!',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncFailedBanner extends StatelessWidget {
  final String? error;

  const _SyncFailedBanner({this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.sync_problem, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Some activities failed to sync',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              SyncService.instance.syncPendingActivities();
            },
            child: const Text(
              'Retry',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small connectivity indicator for app bar
class ConnectivityIndicator extends ConsumerWidget {
  const ConnectivityIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);
    final sync = ref.watch(syncProvider);

    if (!connectivity.isOnline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'Offline',
              style: TextStyle(fontSize: 12, color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (sync.pendingCount > 0 && sync.status != SyncStatus.syncing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.shade700,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              '${sync.pendingCount}',
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
