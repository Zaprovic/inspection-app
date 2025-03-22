import 'package:flutter/material.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/providers/sync_provider.dart';
import 'package:inspection_app/services/api_service.dart';
import 'package:inspection_app/services/database_service.dart';
import 'package:inspection_app/widgets/home/inspection_card.dart';
import 'package:provider/provider.dart';

class InspectionListWidget extends StatelessWidget {
  final List<Inspection> inspections;
  final Function(int) onInspectionRemoved;
  final Function(int, Inspection) onInspectionUpdated;
  final Function(bool) setLoadingState;

  const InspectionListWidget({
    super.key,
    required this.inspections,
    required this.onInspectionRemoved,
    required this.onInspectionUpdated,
    required this.setLoadingState,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: inspections.length,
      itemBuilder: (context, index) {
        final inspeccion = inspections[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InspectionCard(
            inspection: inspeccion,
            onTap: () => _handleInspectionTap(context, inspeccion, index),
            onDelete: () => _handleInspectionDelete(context, inspeccion, index),
            onSync:
                inspeccion.status == 'Pendiente de sincronización'
                    ? () => _handleInspectionSync(context, inspeccion, index)
                    : null,
          ),
        );
      },
    );
  }

  Future<void> _handleInspectionTap(
    BuildContext context,
    Inspection inspeccion,
    int index,
  ) async {
    // Find the inspection ID from the database
    final allInspections = await DatabaseService.instance.getAllInspections();
    int? inspectionId;

    for (final data in allInspections) {
      if (data['title'] == inspeccion.title &&
          data['date'] == inspeccion.date.toIso8601String()) {
        inspectionId = data['id'] as int;
        break;
      }
    }

    if (inspectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se puede encontrar la inspección'),
        ),
      );
      return;
    }

    final resultado = await Navigator.pushNamed(
      context,
      '/edit',
      arguments: {'id': inspectionId},
    );

    if (resultado != null && resultado is Map) {
      if (resultado.containsKey('action') && resultado['action'] == 'delete') {
        // Eliminar de la base de datos
        final allInspections =
            await DatabaseService.instance.getAllInspections();
        for (final data in allInspections) {
          if (data['title'] == inspeccion.title &&
              data['date'] == inspeccion.date.toIso8601String()) {
            await DatabaseService.instance.deleteInspection(data['id'] as int);
            break;
          }
        }

        onInspectionRemoved(index);

        // Update the SyncProvider if a pending sync was deleted
        if (inspeccion.status == 'Pendiente de sincronización') {
          Provider.of<SyncProvider>(
            context,
            listen: false,
          ).decrementPendingSyncs();
        }
      } else if (resultado.containsKey('inspection')) {
        final updatedInspection = resultado['inspection'] as Inspection;

        // Actualizar en la base de datos
        final allInspections =
            await DatabaseService.instance.getAllInspections();
        for (final data in allInspections) {
          if (data['title'] == inspeccion.title &&
              data['date'] == inspeccion.date.toIso8601String()) {
            final inspectionMap = {
              'title': updatedInspection.title,
              'description': updatedInspection.description,
              'date': updatedInspection.date.toIso8601String(),
              'location':
                  '${updatedInspection.location[0]},${updatedInspection.location[1]}',
              'status':
                  'Pendiente de sincronización', // Set status to pending sync
            };

            await DatabaseService.instance.updateInspection(
              data['id'] as int,
              inspectionMap,
            );
            break;
          }
        }

        // Only increment if it wasn't already pending
        final wasAlreadyPending =
            inspeccion.status == 'Pendiente de sincronización';

        // Make sure to update with the pending sync status
        final updatedInspectionWithStatus = updatedInspection.copyWith(
          status: 'Pendiente de sincronización',
        );

        onInspectionUpdated(index, updatedInspectionWithStatus);

        if (!wasAlreadyPending) {
          Provider.of<SyncProvider>(
            context,
            listen: false,
          ).incrementPendingSyncs();
        }
      }
    }
  }

  Future<void> _handleInspectionDelete(
    BuildContext context,
    Inspection inspeccion,
    int index,
  ) async {
    // Eliminar de la base de datos
    final allInspections = await DatabaseService.instance.getAllInspections();
    for (final data in allInspections) {
      if (data['title'] == inspeccion.title &&
          data['date'] == inspeccion.date.toIso8601String()) {
        await DatabaseService.instance.deleteInspection(data['id'] as int);
        break;
      }
    }

    onInspectionRemoved(index);

    // Update the SyncProvider if a pending sync was deleted
    if (inspeccion.status == 'Pendiente de sincronización') {
      Provider.of<SyncProvider>(context, listen: false).decrementPendingSyncs();
    }
  }

  Future<void> _handleInspectionSync(
    BuildContext context,
    Inspection inspeccion,
    int index,
  ) async {
    setLoadingState(true);

    // Check if we have a valid ID
    if (inspeccion.id == null) {
      setLoadingState(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se puede sincronizar una inspección sin ID'),
        ),
      );
      return;
    }

    // Add logging to debug the sync process
    print('Intentando sincronizar inspección con ID: ${inspeccion.id}');

    final success = await ApiService().syncInspection(inspeccion.id!);

    setLoadingState(false);

    if (success) {
      final updatedInspection = inspeccion.copyWith(status: 'Sincronizada');
      onInspectionUpdated(index, updatedInspection);
    }

    // Use provider to update sync count
    if (success) {
      Provider.of<SyncProvider>(context, listen: false).decrementPendingSyncs();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Inspección sincronizada correctamente'
              : 'No se pudo sincronizar. Comprueba tu conexión WiFi',
        ),
      ),
    );
  }
}
