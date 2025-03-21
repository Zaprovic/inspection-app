import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/widgets/connectivity_status.dart';
import 'package:inspection_app/theme/app_theme.dart';
import 'package:inspection_app/services/database_service.dart';

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
              title: data['title'] as String,
              description: data['description'] as String,
              date: DateTime.parse(data['date'] as String),
              location: [latitude, longitude],
            );
          }).toList();

      setState(() {
        inspecciones = loadedInspections;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      // Podríamos mostrar un SnackBar aquí para informar del error
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
        actions: const [ConnectivityStatus(), SizedBox(width: 8)],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : inspecciones.isEmpty
              ? _buildEstadoVacio()
              : _buildListaInspecciones(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final resultado = await Navigator.pushNamed(context, '/add');
          if (resultado != null && resultado is Inspection) {
            // Guardar en la base de datos
            final inspectionMap = {
              'title': resultado.title,
              'description': resultado.description,
              'date': resultado.date.toIso8601String(),
              'location': '${resultado.location[0]},${resultado.location[1]}',
            };

            await DatabaseService.instance.createInspection(inspectionMap);

            setState(() {
              inspecciones.add(resultado);
            });
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
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
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

  const TarjetaInspeccion({
    super.key,
    required this.inspection,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final formateadorFecha = DateFormat('MMM d, yyyy');
    final tema = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      inspection.title,
                      style: tema.textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
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
                style: tema.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    formateadorFecha.format(inspection.date),
                    style: tema.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.location_on, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Lat: ${inspection.location[0].toStringAsFixed(2)}, '
                    'Long: ${inspection.location[1].toStringAsFixed(2)}',
                    style: tema.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
