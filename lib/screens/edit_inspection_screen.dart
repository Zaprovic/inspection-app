import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:inspection_app/layouts/inspection_form_layout.dart';
import 'package:inspection_app/models/inspection_model.dart';
import 'package:inspection_app/widgets/shared/action_button.dart';
import 'package:inspection_app/widgets/shared/inspection_appbar.dart';
import 'package:inspection_app/widgets/shared/inspection_form_section.dart';
import 'package:inspection_app/widgets/shared/location_input.dart';
import 'package:intl/intl.dart';
import 'package:inspection_app/services/inspection_service.dart';

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

      final inspection = await InspectionService.loadInspection(_inspectionId!);

      if (inspection != null) {
        setState(() {
          _inspection = inspection;
          _titleController.text = _inspection!.title;
          _descriptionController.text = _inspection!.description;
          _latController.text = _inspection!.location[0].toString();
          _longController.text = _inspection!.location[1].toString();
          _selectedDate = _inspection!.date;
          _wasAlreadyPending =
              inspection.status == 'Pendiente de sincronización';
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

        final updatedInspection = await InspectionService.updateInspection(
          id: _inspectionId!,
          title: _titleController.text,
          description: _descriptionController.text,
          date: _selectedDate,
          location: location,
          context: context,
          wasAlreadyPending: _wasAlreadyPending,
        );

        if (mounted) {
          Navigator.pop(context, {
            'action': 'updated',
            'id': _inspectionId,
            'inspection': updatedInspection,
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

      await InspectionService.deleteInspection(
        id: _inspectionId!,
        context: context,
        wasAlreadyPending: _wasAlreadyPending,
      );

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
      appBar: InspectionAppBar(
        title: 'Editar Inspección',
        actions: [
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
      body: InspectionFormLayout(
        formKey: _formKey,
        children: [
          InspectionFormSection(
            titleController: _titleController,
            descriptionController: _descriptionController,
            selectedDate: _selectedDate,
            onSelectDate: _selectDate,
            dateFormatter: _dateFormatter,
          ),
          const SizedBox(height: 16),
          LocationInput(
            latController: _latController,
            longController: _longController,
          ),
          const SizedBox(height: 32),
          ActionButton(
            onPressed: _submitForm,
            icon: Icons.save,
            label: 'ACTUALIZAR INSPECCIÓN',
          ),
        ],
      ),
    );
  }
}
