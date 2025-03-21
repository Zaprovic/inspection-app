import 'package:flutter/material.dart';
import 'package:inspection_app/screens/home_screen.dart';
import 'package:inspection_app/screens/add_inspection_screen.dart';
import 'package:inspection_app/screens/edit_inspection.dart';
import 'package:inspection_app/theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplicación de Inspecciones',
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(title: 'Aplicación de Inspecciones'),
        '/add': (context) => const AddInspectionScreen(),
        '/edit': (context) => const EditInspectionScreen(),
      },
    );
  }
}
