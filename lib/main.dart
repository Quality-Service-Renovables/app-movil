import 'package:flutter/material.dart';
import 'package:quality_service/project_screen.dart';

import 'login_screen.dart';
import 'welcome_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QSR Eolic Inspection test',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/welcome': (context) => const WelcomeScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/projects') {
          final args = settings.arguments as Map<String, dynamic>;
          final projects = args['projects'] as List<dynamic>;
          final title = args['title'] as String;
          return MaterialPageRoute(
            builder: (context) {
              return ProjectsScreen(projects: projects, title: title);
            },
          );
        }
        assert(false, 'Need to implement ${settings.name}');
        return null;
      },
    );
  }
}
