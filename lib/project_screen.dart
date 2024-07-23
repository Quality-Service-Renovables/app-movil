import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'login_screen.dart';

class ProjectsScreen extends StatelessWidget {
  final List<dynamic> projects;
  final String title;

  ProjectsScreen({required this.projects, required this.title});

  Future<void> _logout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.post(
      Uri.parse('https://qsr.mx/api/session/logout'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'token': token!,
      }),
    );

    if (response.statusCode == 200) {
      final db = await DatabaseHelper().database;
      await db.update('sessions', {'expired_at': DateTime.now().toIso8601String()}, where: 'token = ?', whereArgs: [token]);

      // Limpiar el token de SharedPreferences
      await prefs.remove('token');

      // Redirigir a la pantalla de login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('Error al cerrar sesión: ${response.reasonPhrase}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
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
              subtitle: Text(projectDescription),
            ),
          );
        },
      ),
    );
  }
}
