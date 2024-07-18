import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'inspection_screen.dart'; // Asegúrate de importar el archivo de la pantalla de inspección

class ProjectsScreen extends StatefulWidget {
  @override
  _ProjectsScreenState createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool _isLoading = false;
  List<dynamic> _projects = [];

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    setState(() {
      _isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    if (token == null) {
      _showErrorDialog('Token no encontrado. Por favor, inicia sesión de nuevo.');
      return;
    }

    final response = await http.get(
      Uri.parse('https://qsr.mx/api/employee/get-projects'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
    );

    setState(() {
      _isLoading = false;
    });

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      if (responseData['status'] == 'ok') {
        setState(() {
          _projects = responseData['data'];
        });
      } else {
        _showErrorDialog(responseData['message']);
      }
    } else {
      _showErrorDialog('Error al recuperar los proyectos.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToInspection(String projectUuid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InspectionScreen(projectUuid: projectUuid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Proyectos Asignados'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.red[900], // Rojo oscuro
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.red[900]))
          : ListView.builder(
        itemCount: _projects.length,
        itemBuilder: (context, index) {
          final project = _projects[index]['project'][0];
          return ListTile(
            title: Text(project['project_name']),
            onTap: () => _navigateToInspection(project['project_uuid']),
          );
        },
      ),
    );
  }
}
