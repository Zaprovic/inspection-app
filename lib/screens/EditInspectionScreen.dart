import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:intl/intl.dart';
import 'package:inspection_app/widgets/ConnectivityStatus.dart';
import 'package:inspection_app/services/DatabaseService.dart';
import 'package:provider/provider.dart';
import 'package:inspection_app/providers/SyncProvider.dart';

class EditInspectionScreen extends StatefulWidget {
  const EditInspectionScreen({super.key});

  @override
  State<EditInspectionScreen> createState() => _EditInspectionScreenState();
}

class _EditInspectionScreenState extends State<EditInspectionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _latController;
  late TextEditingController _longController;

  DateTime _selectedDate = DateTime.now();
  Inspection? _inspection;
  int? _inspectionId;
  bool _isLoading = true;
  final _dateFormatter = DateFormat('MMM d, yyyy');
  bool _wasAlreadyPending = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _latController = TextEditingController();
    _longController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get ID from arguments and load inspection if not already done
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && _inspectionId == null) {
      // Make sure args is a Map and contains 'id' before attempting to cast
      if (args is Map && args.containsKey('id') && args['id'] != null) {
        _inspectionId = args['id'] as int;
        _loadInspection();
      } else {
        // Use addPostFrameCallback to show SnackBar after the build is complete
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid inspection ID provided')),
            );
            // Navigate back since we can't proceed without a valid ID
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) Navigator.pop(context);
            });
          }
        });
      }
    }
  }

  Future<void> _loadInspection() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_inspectionId == null) {
        throw Exception('Inspection ID is not provided');
      }

      final inspectionData = await DatabaseService.instance.getInspection(
        _inspectionId!,
      );

      if (inspectionData != null) {
        // Parse the location string from database into a List<double>
        final locationString = inspectionData['location'] as String;
        final locationArray =
            locationString
                .split(',')
                .map((e) => double.parse(e.trim()))
                .toList();

        final status = inspectionData['status'] as String;
        _wasAlreadyPending = status == 'Pendiente de sincronización';

        setState(() {
          _inspection = Inspection(
            id: _inspectionId, // Store the ID in the inspection object
            title: inspectionData['title'],
            description: inspectionData['description'],
            date: DateTime.parse(inspectionData['date']),
            location: locationArray,
            status: status, // Store the status
          );

          _titleController.text = _inspection!.title;
          _descriptionController.text = _inspection!.description;
          _latController.text = _inspection!.location[0].toString();
          _longController.text = _inspection!.location[1].toString();
          _selectedDate = _inspection!.date;
        });
      } else {
        // Use addPostFrameCallback to show SnackBar after the build is complete
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Inspection not found')),
            );
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      // Use addPostFrameCallback to show SnackBar after the build is complete
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading inspection: $e')),
          );
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _latController.dispose();
    _longController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() {
          _isLoading = true;
        });

        final location = [
          double.parse(_latController.text),
          double.parse(_longController.text),
        ];

        // Create a map for database update
        final updatedInspection = {
          'title': _titleController.text,
          'description': _descriptionController.text,
          'date': _selectedDate.toIso8601String(),
          'location': '${location[0]},${location[1]}',
          'status':
              'Pendiente de sincronización', // Always set to pending when updated
        };

        await DatabaseService.instance.updateInspection(
          _inspectionId!,
          updatedInspection,
        );

        // If it wasn't already pending, increment the sync counter
        if (!_wasAlreadyPending) {
          Provider.of<SyncProvider>(
            context,
            listen: false,
          ).incrementPendingSyncs();
        }

        if (mounted) {
          // Return more complete data for updating the home screen
          final updatedInspectionObject = Inspection(
            id: _inspectionId,
            title: _titleController.text,
            description: _descriptionController.text,
            date: _selectedDate,
            location: location,
            status: 'Pendiente de sincronización',
          );

          Navigator.pop(context, {
            'action': 'updated',
            'id': _inspectionId,
            'inspection': updatedInspectionObject,
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating inspection: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _deleteInspection() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await DatabaseService.instance.deleteInspection(_inspectionId!);

      // If we're deleting a pending sync, update the counter
      if (_wasAlreadyPending) {
        Provider.of<SyncProvider>(
          context,
          listen: false,
        ).decrementPendingSyncs();
      }

      if (mounted) {
        Navigator.pop(context, {'action': 'delete'});
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting inspection: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Inspección'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        actions: [
          const ConnectivityStatus(),
          IconButton(
            icon: const Icon(Icons.delete),
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
                            _deleteInspection();
                          },
                          child: Text(
                            'ELIMINAR',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(color: theme.colorScheme.surface),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Información General',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'Título',
                            prefixIcon: const Icon(Icons.title),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa un título';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'Descripción',
                            prefixIcon: const Icon(Icons.description),
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                          ),
                          minLines: 3,
                          maxLines: 5,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa una descripción';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () => _selectDate(context),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Fecha',
                              prefixIcon: const Icon(Icons.calendar_today),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_dateFormatter.format(_selectedDate)),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: theme.colorScheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ubicación',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _latController,
                                decoration: InputDecoration(
                                  labelText: 'Latitud',
                                  prefixIcon: const Icon(Icons.location_on),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: theme.colorScheme.surface,
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Requerido';
                                  }
                                  if (double.tryParse(value) == null) {
                                    return 'Ingresa un número válido';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _longController,
                                decoration: InputDecoration(
                                  labelText: 'Longitud',
                                  prefixIcon: const Icon(Icons.explore),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: theme.colorScheme.surface,
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Requerido';
                                  }
                                  if (double.tryParse(value) == null) {
                                    return 'Ingresa un número válido';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _submitForm,
                  icon: const Icon(Icons.save),
                  label: const Text('ACTUALIZAR INSPECCIÓN'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
