import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService {
  // Singleton pattern
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  
  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  bool _isConnected = true;
  bool get isConnected => _isConnected;

  void initialize() {
    // Check initial connection status
    _checkConnectionStatus();
    
    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // If any connection type is available, consider it connected
      _updateConnectionStatus(results);
    });
  }

  Future<void> _checkConnectionStatus() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      _connectionStatusController.add(false);
      _isConnected = false;
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // Consider connected if any result is not 'none'
    bool isConnected = results.any((result) => result != ConnectivityResult.none);
    _isConnected = isConnected;
    _connectionStatusController.add(isConnected);
  }

  // Make a retry attempt to connect to backend
  Future<bool> retryConnection() async {
    final result = await _connectivity.checkConnectivity();
    bool isConnected = result != ConnectivityResult.none;
    _isConnected = isConnected;
    _connectionStatusController.add(isConnected);
    return isConnected;
  }

  void dispose() {
    _connectionStatusController.close();
  }
}

// Widget to display connectivity status and retry option
class ConnectivityBanner extends StatelessWidget {
  final VoidCallback onRetry;
  final bool isOffline;

  const ConnectivityBanner({
    Key? key,
    required this.onRetry,
    required this.isOffline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox();

    return Container(
      color: Colors.red.shade700,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.white),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'You\'re offline. App will work in offline mode.',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'RETRY',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}