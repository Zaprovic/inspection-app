import 'package:flutter/material.dart';
import 'package:inspection_app/models/inspection_model.dart';
import 'package:inspection_app/services/database_service.dart';
import 'package:provider/provider.dart';
import 'package:inspection_app/providers/sync_provider.dart';

class InspectionService {
  // Load an inspection by ID
  static Future<Inspection?> loadInspection(int id) async {
    final inspectionData = await DatabaseService.instance.getInspection(id);

    if (inspectionData != null) {
      final locationString = inspectionData['location'] as String;
      final locationArray =
          locationString.split(',').map((e) => double.parse(e.trim())).toList();

      return Inspection(
        id: id,
        title: inspectionData['title'],
        description: inspectionData['description'],
        date: DateTime.parse(inspectionData['date']),
        location: locationArray,
        status: inspectionData['status'],
      );
    }

    return null;
  }

  // Update an inspection
  static Future<Inspection> updateInspection({
    required int id,
    required String title,
    required String description,
    required DateTime date,
    required List<double> location,
    required BuildContext context,
    required bool wasAlreadyPending,
  }) async {
    final updatedInspection = {
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'location': '${location[0]},${location[1]}',
      'status': 'Pendiente de sincronización',
    };

    await DatabaseService.instance.updateInspection(id, updatedInspection);

    // Update the sync counter if needed
    if (!wasAlreadyPending) {
      Provider.of<SyncProvider>(context, listen: false).incrementPendingSyncs();
    }

    return Inspection(
      id: id,
      title: title,
      description: description,
      date: date,
      location: location,
      status: 'Pendiente de sincronización',
    );
  }

  // Delete an inspection
  static Future<void> deleteInspection({
    required int id,
    required BuildContext context,
    required bool wasAlreadyPending,
  }) async {
    await DatabaseService.instance.deleteInspection(id);

    // Update the sync counter if needed
    if (wasAlreadyPending) {
      Provider.of<SyncProvider>(context, listen: false).decrementPendingSyncs();
    }
  }
}
