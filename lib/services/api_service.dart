import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/services/database_service.dart';

class ApiService {
  static const String baseUrl =
      'https://67dc837ee00db03c406846b6.mockapi.io/inspections_mock';

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Check if device has WiFi connection
  Future<bool> hasWifiConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.wifi);
  }

  // Upload an inspection to the remote API
  Future<bool> uploadInspection(Inspection inspection) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': inspection.title,
          'description': inspection.description,
          'date': inspection.date.toIso8601String(),
          'location': '${inspection.location[0]},${inspection.location[1]}',
          'status': 'Sincronizada',
        }),
      );

      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Error uploading inspection: $e');
      return false;
    }
  }

  // Handle inspection creation based on connectivity
  Future<Inspection?> createInspection(Inspection inspection) async {
    final hasWifi = await hasWifiConnection();

    // Set status based on connectivity
    inspection = inspection.copyWith(
      status: hasWifi ? 'Sincronizada' : 'Pendiente de sincronización',
    );

    // Create inspection in local database
    final db = DatabaseService.instance;
    final inspectionMap = {
      'title': inspection.title,
      'description': inspection.description,
      'date': inspection.date.toIso8601String(),
      'location': '${inspection.location[0]},${inspection.location[1]}',
      'status': inspection.status,
    };

    final id = await db.createInspection(inspectionMap);
    inspection = inspection.copyWith(id: id);

    // If WiFi is available, upload to API
    if (hasWifi) {
      final success = await uploadInspection(inspection);
      if (!success) {
        // If upload fails, update status in local database
        await db.updateInspectionStatus(id, 'Pendiente de sincronización');
        inspection = inspection.copyWith(status: 'Pendiente de sincronización');
      }
    }

    return inspection;
  }

  // Sync all pending inspections
  Future<List<Inspection>> syncPendingInspections() async {
    final hasWifi = await hasWifiConnection();
    if (!hasWifi) {
      return [];
    }

    final db = DatabaseService.instance;
    final pendingInspections = await db.getInspectionsByStatus(
      'Pendiente de sincronización',
    );
    final List<Inspection> syncedInspections = [];

    for (final data in pendingInspections) {
      final locationStr = data['location'] as String;
      final locationParts = locationStr.split(',');
      final latitude = double.parse(locationParts[0]);
      final longitude = double.parse(locationParts[1]);

      final inspection = Inspection(
        id: data['id'] as int,
        title: data['title'] as String,
        description: data['description'] as String,
        date: DateTime.parse(data['date'] as String),
        location: [latitude, longitude],
        status: data['status'] as String,
      );

      final success = await uploadInspection(inspection);
      if (success) {
        await db.updateInspectionStatus(inspection.id!, 'Sincronizada');
        syncedInspections.add(inspection.copyWith(status: 'Sincronizada'));
      }
    }

    return syncedInspections;
  }

  // Sync a specific inspection
  Future<bool> syncInspection(int id) async {
    final hasWifi = await hasWifiConnection();
    if (!hasWifi) return false;

    final db = DatabaseService.instance;
    final data = await db.getInspection(id);

    if (data == null || data['status'] == 'Sincronizada') {
      return false;
    }

    final locationStr = data['location'] as String;
    final locationParts = locationStr.split(',');
    final latitude = double.parse(locationParts[0]);
    final longitude = double.parse(locationParts[1]);

    final inspection = Inspection(
      id: data['id'] as int,
      title: data['title'] as String,
      description: data['description'] as String,
      date: DateTime.parse(data['date'] as String),
      location: [latitude, longitude],
      status: data['status'] as String,
    );

    final success = await uploadInspection(inspection);
    if (success) {
      await db.updateInspectionStatus(id, 'Sincronizada');
      return true;
    }

    return false;
  }
}
