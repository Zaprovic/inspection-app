import 'package:flutter/material.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/widgets/connectivity_status.dart';
import 'package:inspection_app/theme/app_theme.dart';
import 'package:inspection_app/services/database_service.dart';
import 'package:inspection_app/services/api_service.dart';
import 'package:inspection_app/widgets/home/inspection_card.dart';
import 'package:provider/provider.dart';
import 'package:inspection_app/providers/sync_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.title});

  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Inspection> inspecciones = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInspections();
  }

  Future<void> _loadInspections() async {
    setState(() {
      isLoading = true;
    });

    try {
      final inspectionData = await DatabaseService.instance.getAllInspections();

      final loadedInspections =
          inspectionData.map((data) {
            final locationStr = data['location'] as String;
            final locationParts = locationStr.split(',');
            final latitude = double.parse(locationParts[0]);
            final longitude = double.parse(locationParts[1]);

            return Inspection(
              id: data['id'] as int,
              title: data['title'] as String,
              description: data['description'] as String,
              date: DateTime.parse(data['date'] as String),
              location: [latitude, longitude],
              status: data['status'] as String,
            );
          }).toList();

      // Update the provider with the pending syncs count
      await Provider.of<SyncProvider>(
        context,
        listen: false,
      ).loadPendingSyncs();

      setState(() {
        inspecciones = loadedInspections;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando inspecciones: $e')),
      );
    }
  }

  Future<void> _syncAllPendingInspections() async {
    setState(() {
      isLoading = true;
    });

    try {
      final syncedInspections = await ApiService().syncPendingInspections();

      if (syncedInspections.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${syncedInspections.length} inspecciones sincronizadas',
            ),
          ),
        );

        // Reset the pending syncs counter since all were synced
        Provider.of<SyncProvider>(context, listen: false).resetPendingSyncs();

        await _loadInspections(); // Reload to update UI
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No hay inspecciones para sincronizar o falta conexión WiFi',
            ),
          ),
        );
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sincronizando: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the provider to get the pendingSyncs value
    final syncProvider = Provider.of<SyncProvider>(context);
    final pendingSyncs = syncProvider.pendingSyncs;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Text(widget.title),
        elevation: 2,
        actions: [
          if (pendingSyncs > 0)
            IconButton(
              icon: Badge(
                label: Text(pendingSyncs.toString()),
                child: const Icon(Icons.sync),
              ),
              onPressed: _syncAllPendingInspections,
              tooltip: 'Sincronizar inspecciones pendientes',
            ),
          const ConnectivityStatus(),
          const SizedBox(width: 8),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : inspecciones.isEmpty
              ? _buildEstadoVacio()
              : _buildListaInspecciones(),
      floatingActionButton:
          inspecciones.isEmpty
              ? null // Don't show the button when there are no inspections
              : FloatingActionButton(
                onPressed: () async {
                  final resultado = await Navigator.pushNamed(context, '/add');
                  if (resultado != null && resultado is Inspection) {
                    final createdInspection = await ApiService()
                        .createInspection(resultado);
                    if (createdInspection != null) {
                      setState(() {
                        inspecciones.add(createdInspection);
                        if (createdInspection.status ==
                            'Pendiente de sincronización') {
                          Provider.of<SyncProvider>(
                            context,
                            listen: false,
                          ).incrementPendingSyncs();
                        }
                      });
                    }
                  }
                },
                tooltip: 'Añadir Inspección',
                child: const Icon(Icons.add),
              ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildEstadoVacio() {
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
                  onPressed: () async {
                    final resultado = await Navigator.pushNamed(
                      context,
                      '/add',
                    );
                    if (resultado != null && resultado is Inspection) {
                      // Guardar en la base de datos
                      final inspectionMap = {
                        'title': resultado.title,
                        'description': resultado.description,
                        'date': resultado.date.toIso8601String(),
                        'location':
                            '${resultado.location[0]},${resultado.location[1]}',
                        'status':
                            'Pendiente de sincronización', // Ensure status is set
                      };

                      final id = await DatabaseService.instance
                          .createInspection(inspectionMap);

                      // Create a new inspection with the ID from the database
                      final createdInspection = resultado.copyWith(
                        id: id,
                        status: 'Pendiente de sincronización',
                      );

                      setState(() {
                        inspecciones.add(createdInspection);
                      });

                      // Use the provider to update the pending syncs count
                      Provider.of<SyncProvider>(
                        context,
                        listen: false,
                      ).incrementPendingSyncs();
                    }
                  },
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

  Widget _buildListaInspecciones() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: inspecciones.length,
      itemBuilder: (context, index) {
        final inspeccion = inspecciones[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InspectionCard(
            inspection: inspeccion,
            onTap: () async {
              // Find the inspection ID from the database
              final allInspections =
                  await DatabaseService.instance.getAllInspections();
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
                if (resultado.containsKey('action') &&
                    resultado['action'] == 'delete') {
                  // Eliminar de la base de datos
                  final allInspections =
                      await DatabaseService.instance.getAllInspections();
                  for (final data in allInspections) {
                    if (data['title'] == inspeccion.title &&
                        data['date'] == inspeccion.date.toIso8601String()) {
                      await DatabaseService.instance.deleteInspection(
                        data['id'] as int,
                      );
                      break;
                    }
                  }

                  setState(() {
                    inspecciones.removeAt(index);
                  });

                  // Update the SyncProvider if a pending sync was deleted
                  if (inspeccion.status == 'Pendiente de sincronización') {
                    Provider.of<SyncProvider>(
                      context,
                      listen: false,
                    ).decrementPendingSyncs();
                  }
                } else if (resultado.containsKey('inspection')) {
                  final updatedInspection =
                      resultado['inspection'] as Inspection;

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

                  setState(() {
                    // Make sure to update with the pending sync status
                    inspecciones[index] = updatedInspection.copyWith(
                      status: 'Pendiente de sincronización',
                    );
                  });

                  if (!wasAlreadyPending) {
                    Provider.of<SyncProvider>(
                      context,
                      listen: false,
                    ).incrementPendingSyncs();
                  }
                }
              }
            },
            onDelete: () async {
              // Eliminar de la base de datos
              final allInspections =
                  await DatabaseService.instance.getAllInspections();
              for (final data in allInspections) {
                if (data['title'] == inspeccion.title &&
                    data['date'] == inspeccion.date.toIso8601String()) {
                  await DatabaseService.instance.deleteInspection(
                    data['id'] as int,
                  );
                  break;
                }
              }

              setState(() {
                inspecciones.removeAt(index);
              });

              // Update the SyncProvider if a pending sync was deleted
              if (inspeccion.status == 'Pendiente de sincronización') {
                Provider.of<SyncProvider>(
                  context,
                  listen: false,
                ).decrementPendingSyncs();
              }
            },
            onSync:
                inspeccion.status == 'Pendiente de sincronización'
                    ? () async {
                      setState(() {
                        isLoading = true;
                      });

                      // Check if we have a valid ID
                      if (inspeccion.id == null) {
                        setState(() {
                          isLoading = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Error: No se puede sincronizar una inspección sin ID',
                            ),
                          ),
                        );
                        return;
                      }

                      // Add logging to debug the sync process
                      print(
                        'Intentando sincronizar inspección con ID: ${inspeccion.id}',
                      );

                      final success = await ApiService().syncInspection(
                        inspeccion.id!,
                      );

                      setState(() {
                        isLoading = false;
                        if (success) {
                          inspecciones[index] = inspeccion.copyWith(
                            status: 'Sincronizada',
                          );
                        }
                      });

                      // Use provider to update sync count
                      if (success) {
                        Provider.of<SyncProvider>(
                          context,
                          listen: false,
                        ).decrementPendingSyncs();
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
                    : null,
          ),
        );
      },
    );
  }
}
