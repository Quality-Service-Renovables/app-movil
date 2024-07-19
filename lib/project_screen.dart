import 'package:flutter/material.dart';

class ProjectsScreen extends StatelessWidget {
  final List<dynamic> projects;
  final String title;

  ProjectsScreen({required this.projects, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
              subtitle: Text(projectDescription),
            ),
          );
        },
      ),
    );
  }
}
