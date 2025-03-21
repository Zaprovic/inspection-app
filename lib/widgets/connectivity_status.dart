import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/theme/app_theme.dart';

class ConnectivityStatus extends StatefulWidget {
  const ConnectivityStatus({super.key});

  @override
  State<ConnectivityStatus> createState() => _ConnectivityStatusState();
}

class _ConnectivityStatusState extends State<ConnectivityStatus> {
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    late List<ConnectivityResult> result;
    try {
      result = await _connectivity.checkConnectivity();
    } catch (e) {
      result = [ConnectivityResult.none];
    }

    if (!mounted) return;

    setState(() {
      _connectionStatus =
          result.isNotEmpty ? result.first : ConnectivityResult.none;
    });
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> result) async {
    setState(() {
      _connectionStatus =
          result.isNotEmpty ? result.first : ConnectivityResult.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    IconData statusIcon;
    Color statusColor;
    String statusText;

    switch (_connectionStatus) {
      case ConnectivityResult.wifi:
        statusIcon = Icons.wifi;
        statusColor = AppTheme.successColor;
        statusText = "WiFi";
        break;
      case ConnectivityResult.mobile:
        statusIcon = Icons.signal_cellular_alt;
        statusColor = AppTheme.successColor;
        statusText = "Datos móviles";
        break;
      case ConnectivityResult.ethernet:
        statusIcon = Icons.settings_ethernet;
        statusColor = AppTheme.successColor;
        statusText = "Ethernet";
        break;
      case ConnectivityResult.none:
      default:
        statusIcon = Icons.wifi_off;
        statusColor = AppTheme.errorColor;
        statusText = "Sin conexión";
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
