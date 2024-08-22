import 'package:flutter/material.dart';
import 'logout_service.dart'; // Importa el servicio de logout
import 'package:flutter_html/flutter_html.dart';

class ProjectsScreen extends StatelessWidget {
  final List<dynamic> projects;
  final String title;

  ProjectsScreen({required this.projects, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => LogoutService.logout(context), // Utiliza el servicio de logout
          ),
        ],
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(10),
        itemCount: projects.length,
        itemBuilder: (context, index) {
          final projectName = projects[index]['project_name'];
          final projectDescription = projects[index]['description'];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.0),
            ),
            margin: EdgeInsets.symmetric(vertical: 10.0),
            child: ListTile(
              title: Text(projectName),
              subtitle: Html(
                data: projectDescription,
              ),
            ),
          );
        },
      ),
    );
  }
}
