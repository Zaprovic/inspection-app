import 'package:flutter/material.dart';
import 'package:inspection_app/models/inspection_model.dart';
import 'package:inspection_app/widgets/shared/connectivity_status.dart';
import 'package:inspection_app/services/database_service.dart';
import 'package:inspection_app/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:inspection_app/providers/sync_provider.dart';
import 'package:inspection_app/widgets/home/empty_state_widget.dart';
import 'package:inspection_app/widgets/home/inspection_list_widget.dart';

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

    // Add a post-frame callback to ensure we've fully initialized before listening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure we're listening to sync provider changes
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);
      syncProvider.addListener(_onSyncProviderChanged);
    });
  }

  @override
  void dispose() {
    // Remove the listener when the widget is disposed
    Provider.of<SyncProvider>(
      context,
      listen: false,
    ).removeListener(_onSyncProviderChanged);
    super.dispose();
  }

  // Callback when sync provider changes
  void _onSyncProviderChanged() {
    // This will trigger a rebuild if needed
    if (mounted) setState(() {});
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

      // Update the provider with the actual count of pending syncs from database
      final pendingCount =
          loadedInspections
              .where(
                (inspection) =>
                    inspection.status == 'Pendiente de sincronización',
              )
              .length;

      // Update the provider with accurate count instead of incrementing/decrementing
      await Provider.of<SyncProvider>(
        context,
        listen: false,
      ).setPendingSyncs(pendingCount);

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

  void _handleInspectionAdded(Inspection inspection) {
    setState(() {
      inspecciones.add(inspection);
    });
  }

  void _handleInspectionRemoved(int index) {
    setState(() {
      inspecciones.removeAt(index);
    });
  }

  void _handleInspectionUpdated(int index, Inspection updatedInspection) {
    setState(() {
      inspecciones[index] = updatedInspection;
    });
  }

  void _setLoadingState(bool loading) {
    setState(() {
      isLoading = loading;
    });
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
              ? EmptyStateWidget(onInspectionAdded: _handleInspectionAdded)
              : InspectionListWidget(
                inspections: inspecciones,
                onInspectionRemoved: _handleInspectionRemoved,
                onInspectionUpdated: _handleInspectionUpdated,
                setLoadingState: _setLoadingState,
              ),
      floatingActionButton:
          inspecciones.isEmpty
              ? null
              : FloatingActionButton(
                onPressed: () async {
                  final resultado = await Navigator.pushNamed(context, '/add');
                  if (resultado != null && resultado is Inspection) {
                    final inspectionMap = {
                      'title': resultado.title,
                      'description': resultado.description,
                      'date': resultado.date.toIso8601String(),
                      'location':
                          '${resultado.location[0]},${resultado.location[1]}',
                      'status': 'Pendiente de sincronización',
                    };

                    final id = await DatabaseService.instance.createInspection(
                      inspectionMap,
                    );

                    // Create inspection with the right ID and status
                    final createdInspection = resultado.copyWith(
                      id: id,
                      status: 'Pendiente de sincronización',
                    );

                    setState(() {
                      inspecciones.add(createdInspection);
                    });

                    // Reload pending sync count from database instead of incrementing
                    await _loadInspections();
                  }
                },
                tooltip: 'Añadir Inspección',
                child: const Icon(Icons.add),
              ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
