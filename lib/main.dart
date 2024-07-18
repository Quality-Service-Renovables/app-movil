import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'projects_screen.dart';
import 'inspection_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quality Service Renovables',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/projects': (context) => ProjectsScreen(),
        '/inspection': (context) => InspectionScreen(projectUuid: ''), // Aquí necesitarás pasar el projectUuid apropiado
      },
    );
  }
}
