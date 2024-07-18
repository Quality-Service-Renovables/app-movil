import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class InspectionScreen extends StatefulWidget {
  final String projectUuid;

  InspectionScreen({required this.projectUuid});

  @override
  _InspectionScreenState createState() => _InspectionScreenState();
}

class _InspectionScreenState extends State<InspectionScreen> {
  late Future<Map<String, dynamic>> _inspectionData;

  Future<Map<String, dynamic>> _fetchInspectionData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    if (token == null) {
      throw Exception('Token no encontrado');
    }

    final response = await http.get(
      Uri.parse('https://qsr.mx/api/inspection/${widget.projectUuid}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      if (responseData['status'] == 'ok') {
        return responseData['data'];
      } else {
        throw Exception(responseData['message'] ?? 'Error desconocido');
      }
    } else {
      throw Exception('Error al recuperar los datos de inspección');
    }
  }

  @override
  void initState() {
    super.initState();
    _inspectionData = _fetchInspectionData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles de Inspección'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.red[900], // Rojo oscuro
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _inspectionData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: Colors.red[900]),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text('No se encontraron datos de inspección'),
            );
          } else {
            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                ListTile(
                  title: Text('Nombre del Proyecto'),
                  subtitle: Text(data['project_name'] ?? 'N/A'),
                ),
                ListTile(
                  title: Text('Descripción'),
                  subtitle: Text(data['description'] ?? 'N/A'),
                ),
                ListTile(
                  title: Text('Comentarios'),
                  subtitle: Text(data['comments'] ?? 'N/A'),
                ),
                // Agrega más campos según sea necesario
              ],
            );
          }
        },
      ),
    );
  }
}
