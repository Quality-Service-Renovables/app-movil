import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_helper.dart';

class InspectionFormScreen extends StatefulWidget {
  final String ctInspectionUuid;

  const InspectionFormScreen({super.key, required this.ctInspectionUuid});

  @override
  _InspectionFormScreenState createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  String? formJson;
  String? message;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _getFormInspection(widget.ctInspectionUuid);
  }

  Future<void> _getFormInspection(String ctInspectionUuid) async {
    message = 'Procesando, espere...';
    // Verifica el estado de conexión
    final hasConnection = await _checkInternetConnection();
    final db = await DatabaseHelper().database;
    // Si existe conexión a internet activa, actualiza el formulario
    if (hasConnection) {
      message = 'Actualizando formulario';
      await _updateFormInspection(db, widget.ctInspectionUuid);
    }
    // Recupera la información del formulario
    await _getFormFromDatabase(db, ctInspectionUuid);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error de inicio de sesión'),
          content: Text(responseData['message'] ?? 'Error desconocido'),
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

  Future<bool> _checkInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _updateFormInspection(Database db, String ctInspectionUuid) async {
    // Get token application
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    // Validate connection
    print('Existe conexión y se debe actualizar el json: $ctInspectionUuid');
    final response = await http.get(Uri.parse('https://qsr.mx/api/inspection/forms/get-form/$ctInspectionUuid'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    //final jsonResponse = json.decode(response.body);
    final jsonResponse = json.decode(response.body);

    if (response.statusCode == 200) {
      final data = jsonResponse['data'];
      final now = DateTime.now().toIso8601String();

      await db.insert(
        'inspection_forms',
        {
          'ct_inspection_uuid': ctInspectionUuid,
          'json_form': jsonEncode(data),
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      message = 'Formulario no disponible';
    }

  }

  Future<void> _getFormFromDatabase(Database db, String ctInspectionUuid) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'inspection_forms',
      columns: ['json_form'],
      where: 'ct_inspection_uuid = ?',
      whereArgs: [ctInspectionUuid],
    );

    if (maps.isNotEmpty) {
      final Map<String, dynamic> firstRecord = maps.first;
      final jsonFormDatabase = firstRecord['json_form'];

      // Decodifica el string JSON en un mapa
      final Map<String, dynamic> jsonFormData = jsonDecode(jsonFormDatabase);

      // Ahora puedes acceder a los datos dentro de jsonFormData
      final Map<String, dynamic> sections = jsonFormData['sections'];

      print('Se encontró información en la base de datos $sections');
      formJson = jsonFormDatabase;
      message = 'Información recuperada...';
      //return maps.first;
    } else {
      print('No se encontró información en la base de datos');
      message = 'No fue posible recuperar el formulario, revise su conexión';
      //return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldMessengerKey,
      appBar: AppBar(
        title: const Text('Inspección'),
      ),
      body: formJson != null
          ? SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Text(formJson ?? '', style: const TextStyle(fontSize: 16.0)),
      )
          : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Text(message ?? '', style: const TextStyle(fontSize: 16.0)),
    ));
  }
}
