import 'package:flutter/material.dart';
import 'package:quality_service/project_screen.dart';

import 'login_screen.dart';
import 'welcome_screen.dart';
import 'package:flutter/services.dart';

void main() {
  // Asegura que los bindings se inicialicen antes de ejecutar el resto del código
  WidgetsFlutterBinding.ensureInitialized();

  // Oculta la barra de estado en Android
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.bottom]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Oculta el banner de debug
      title: 'QSR Eolic Inspection',
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
