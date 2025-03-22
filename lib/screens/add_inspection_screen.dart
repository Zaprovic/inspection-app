import 'package:flutter/material.dart';
import 'package:inspection_app/layouts/inspection_form_layout.dart';
import 'package:inspection_app/models/inspection_model.dart';
import 'package:inspection_app/widgets/shared/action_button.dart';
import 'package:inspection_app/widgets/shared/inspection_appbar.dart';
import 'package:inspection_app/widgets/shared/inspection_form_section.dart';
import 'package:inspection_app/widgets/shared/location_input.dart';
import 'package:intl/intl.dart';

class AddInspectionScreen extends StatefulWidget {
  const AddInspectionScreen({super.key});

  @override
  State<AddInspectionScreen> createState() => _AddInspectionScreenState();
}

class _AddInspectionScreenState extends State<AddInspectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latController = TextEditingController(text: '0.0');
  final _longController = TextEditingController(text: '0.0');

  DateTime _selectedDate = DateTime.now();
  final _dateFormatter = DateFormat('MMM d, yyyy');

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

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final newInspection = Inspection(
        title: _titleController.text,
        description: _descriptionController.text,
        date: _selectedDate,
        location: [
          double.parse(_latController.text),
          double.parse(_longController.text),
        ],
        status: 'Pendiente de sincronización', // Set default status
      );

      Navigator.pop(context, newInspection);
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: InspectionAppBar(title: 'Añadir Inspección'),
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
            label: 'GUARDAR INSPECCIÓN',
          ),
        ],
      ),
    );
  }
}
