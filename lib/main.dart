import 'package:flutter/material.dart';
import 'package:inspection_app/screens/HomeScreen.dart';
import 'package:inspection_app/screens/AddInspectionScreen.dart';
import 'package:inspection_app/screens/EditInspectionScreen.dart';
import 'package:inspection_app/theme/AppTheme.dart';
import 'package:provider/provider.dart';
import 'package:inspection_app/providers/SyncProvider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => SyncProvider())],
      child: const MyApp(),
    ),
  );
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
