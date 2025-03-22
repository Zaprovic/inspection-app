import 'package:flutter/material.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/providers/sync_provider.dart';
import 'package:inspection_app/services/database_service.dart';
import 'package:inspection_app/theme/app_theme.dart';
import 'package:provider/provider.dart';

class EmptyStateWidget extends StatelessWidget {
  final Function(Inspection) onInspectionAdded;

  const EmptyStateWidget({super.key, required this.onInspectionAdded});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;
        final iconSize = isSmallScreen ? 80.0 : 120.0;
        final padding = isSmallScreen ? 24.0 : 32.0;

        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: iconSize,
                  color: Theme.of(context).colorScheme.primary.withAlpha(179),
                ),
                const SizedBox(height: 24),
                Text(
                  'No hay inspecciones',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: isSmallScreen ? 24 : 32,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Añade tu primera inspección pulsando el botón de abajo',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: isSmallScreen ? 16 : 18,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => _addNewInspection(context),
                  icon: const Icon(Icons.add),
                  label: Text(isSmallScreen ? 'Añadir' : 'Nueva Inspección'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16 : 24,
                      vertical: isSmallScreen ? 10 : 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addNewInspection(BuildContext context) async {
    final resultado = await Navigator.pushNamed(context, '/add');
    if (resultado != null && resultado is Inspection) {
      // Guardar en la base de datos
      final inspectionMap = {
        'title': resultado.title,
        'description': resultado.description,
        'date': resultado.date.toIso8601String(),
        'location': '${resultado.location[0]},${resultado.location[1]}',
        'status': 'Pendiente de sincronización',
      };

      final id = await DatabaseService.instance.createInspection(inspectionMap);

      // Create a new inspection with the ID from the database
      final createdInspection = resultado.copyWith(
        id: id,
        status: 'Pendiente de sincronización',
      );

      onInspectionAdded(createdInspection);

      // Use the provider to update the pending syncs count
      Provider.of<SyncProvider>(context, listen: false).incrementPendingSyncs();
    }
  }
}
