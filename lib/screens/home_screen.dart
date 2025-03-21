import 'package:flutter/material.dart';
import 'package:inspection_app/screens/maps_screen.dart';
import 'package:intl/intl.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/widgets/connectivity_status.dart';
import 'package:inspection_app/theme/app_theme.dart';
import 'package:inspection_app/services/database_service.dart';
import 'package:inspection_app/services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.title});

  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Inspection> inspecciones = [];
  bool isLoading = true;
  int pendingSyncs = 0;

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

      // Count pending syncs
      pendingSyncs =
          loadedInspections
              .where((i) => i.status == 'Pendiente de sincronización')
              .length;

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
              : FloatingActionButton.extended(
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
                          pendingSyncs++;
                        }
                      });
                    }
                  }
                },
                tooltip: 'Añadir Inspección',
                icon: const Icon(Icons.add),
                label: const Text('Nueva Inspección'),
              ),
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
                      };

                      await DatabaseService.instance.createInspection(
                        inspectionMap,
                      );

                      setState(() {
                        inspecciones.add(resultado);
                      });
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
          child: TarjetaInspeccion(
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
                      };

                      await DatabaseService.instance.updateInspection(
                        data['id'] as int,
                        inspectionMap,
                      );
                      break;
                    }
                  }

                  setState(() {
                    inspecciones[index] = updatedInspection;
                  });
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
            },
            onSync:
                inspeccion.status == 'Pendiente de sincronización'
                    ? () async {
                      setState(() {
                        isLoading = true;
                      });

                      final success = await ApiService().syncInspection(
                        inspeccion.id!,
                      );

                      setState(() {
                        isLoading = false;
                        if (success) {
                          inspecciones[index] = inspeccion.copyWith(
                            status: 'Sincronizada',
                          );
                          pendingSyncs--;
                        }
                      });

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

class TarjetaInspeccion extends StatelessWidget {
  final Inspection inspection;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onSync;

  const TarjetaInspeccion({
    super.key,
    required this.inspection,
    required this.onTap,
    required this.onDelete,
    this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final formateadorFecha = DateFormat('MMM d, yyyy');
    final tema = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      inspection.title,
                      style: tema.textTheme.titleLarge?.copyWith(
                        fontSize: isSmallScreen ? 16 : 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder:
                            (ctx) => AlertDialog(
                              title: const Text('Eliminar Inspección'),
                              content: const Text(
                                '¿Estás seguro de que quieres eliminar esta inspección?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('CANCELAR'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    onDelete();
                                  },
                                  child: const Text('ELIMINAR'),
                                ),
                              ],
                            ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                inspection.description,
                style: tema.textTheme.bodyMedium?.copyWith(
                  fontSize: isSmallScreen ? 13 : 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // Make the date and location row more responsive
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        formateadorFecha.format(inspection.date),
                        style: tema.textTheme.bodySmall?.copyWith(
                          fontSize: isSmallScreen ? 10 : 12,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Lat: ${inspection.location[0].toStringAsFixed(2)}, '
                          'Long: ${inspection.location[1].toStringAsFixed(2)}',
                          style: tema.textTheme.bodySmall?.copyWith(
                            fontSize: isSmallScreen ? 10 : 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Make the bottom row more responsive
              LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;

                  // If we have enough space, use a Row, otherwise use a Column
                  if (availableWidth >= 320) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatusChip(isSmallScreen),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (onSync != null)
                              IconButton(
                                icon: const Icon(Icons.sync, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                                onPressed: onSync,
                                tooltip: 'Sincronizar',
                              ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              icon: const Icon(Icons.map, size: 16),
                              label: Text(
                                'Ver en mapa',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 14,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 8 : 12,
                                  vertical: isSmallScreen ? 4 : 8,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => MapsScreen(
                                          latitude: inspection.location[0],
                                          longitude: inspection.location[1],
                                          title: inspection.title,
                                        ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    );
                  } else {
                    // For very small screens, stack the elements vertically
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusChip(isSmallScreen),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (onSync != null) ...[
                              IconButton(
                                icon: const Icon(Icons.sync, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                                onPressed: onSync,
                                tooltip: 'Sincronizar',
                              ),
                              const SizedBox(width: 8),
                            ],
                            TextButton.icon(
                              icon: const Icon(Icons.map, size: 16),
                              label: const Text(
                                'Ver en mapa',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => MapsScreen(
                                          latitude: inspection.location[0],
                                          longitude: inspection.location[1],
                                          title: inspection.title,
                                        ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isSmall) {
    return Chip(
      label: Text(
        inspection.status,
        style: TextStyle(
          fontSize: isSmall ? 10 : 12,
          color:
              inspection.status == 'Sincronizada' ? Colors.white : Colors.black,
        ),
      ),
      padding: EdgeInsets.zero,
      labelPadding: EdgeInsets.symmetric(horizontal: isSmall ? 6 : 8),
      visualDensity: VisualDensity.compact,
      backgroundColor:
          inspection.status == 'Sincronizada' ? Colors.green : Colors.amber,
    );
  }
}
