import 'package:flutter/material.dart';
import 'package:quality_service/database_helper.dart';
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
      title: 'Quality Service',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/welcome': (context) => WelcomeScreen(),
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
