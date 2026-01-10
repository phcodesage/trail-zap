import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// Service for monitoring internet connectivity
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final InternetConnection _internetChecker = InternetConnection();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<InternetStatus>? _internetSubscription;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  ConnectivityResult _connectionType = ConnectivityResult.none;
  ConnectivityResult get connectionType => _connectionType;

  bool _isInitialized = false;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Get initial connectivity status
    final results = await _connectivity.checkConnectivity();
    _connectionType = results.isNotEmpty ? results.first : ConnectivityResult.none;

    // Check actual internet access
    _isOnline = await _internetChecker.hasInternetAccess;
    debugPrint('Initial connectivity: $_connectionType, isOnline: $_isOnline');

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    // Listen to internet status changes
    _internetSubscription = _internetChecker.onStatusChange.listen(
      _onInternetStatusChanged,
    );

    _isInitialized = true;
    notifyListeners();
  }

  /// Handle network type changes
  void _onConnectivityChanged(List<ConnectivityResult> results) async {
    _connectionType = results.isNotEmpty ? results.first : ConnectivityResult.none;
    debugPrint('Connectivity changed: $_connectionType');

    if (_connectionType == ConnectivityResult.none) {
      _isOnline = false;
      notifyListeners();
    } else {
      // Verify actual internet access when network type changes
      _isOnline = await _internetChecker.hasInternetAccess;
      notifyListeners();
    }
  }

  /// Handle internet status changes
  void _onInternetStatusChanged(InternetStatus status) {
    final wasOnline = _isOnline;
    _isOnline = status == InternetStatus.connected;
    
    debugPrint('Internet status: $status (was: $wasOnline, now: $_isOnline)');
    
    if (wasOnline != _isOnline) {
      notifyListeners();
    }
  }

  /// Get connection type display name
  String get connectionInfo {
    if (!_isOnline) return 'Offline';
    switch (_connectionType) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      default:
        return 'Connected';
    }
  }

  /// Check if currently connected (one-time check)
  Future<bool> checkConnection() async {
    final results = await _connectivity.checkConnectivity();
    if (results.isEmpty || results.first == ConnectivityResult.none) {
      return false;
    }
    return await _internetChecker.hasInternetAccess;
  }

  /// Dispose resources
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _internetSubscription?.cancel();
    super.dispose();
  }
}
