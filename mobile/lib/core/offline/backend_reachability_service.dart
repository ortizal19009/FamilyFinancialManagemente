import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class BackendReachabilityService {
  final Connectivity _connectivity = Connectivity();

  Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  Future<bool> canReachBackend() async {
    final connectivityResults = await _connectivity.checkConnectivity();
    final hasConnection = connectivityResults.any(
      (result) => result != ConnectivityResult.none,
    );

    if (!hasConnection) {
      return false;
    }

    try {
      final baseUri = Uri.parse(await ApiConfig.getBaseUrl());
      final healthUri = baseUri.replace(
        path: '/health',
        query: null,
      );
      final response = await http.get(healthUri).timeout(const Duration(seconds: 3));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
