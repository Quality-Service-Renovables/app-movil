import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/constants.dart';

class InspectionFormScreen extends StatefulWidget {
  final String ctInspectionUuid;

  const InspectionFormScreen({required this.ctInspectionUuid});

  @override
  _InspectionFormScreenState createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  String? formJson;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  Future<void> _loadForm() async {
    final hasConnection = await _checkInternetConnection();
    final db = await _openDatabase();
    final existingForm = await _getFormFromDatabase(db, widget.ctInspectionUuid);

    if (existingForm != null) {
      setState(() {
        formJson = existingForm['form_json'];
      });

      if (hasConnection) {
        // Actualizar la información desde el endpoint
        await _fetchAndUpdateForm(db, widget.ctInspectionUuid);
      }
    } else if (hasConnection) {
      // Obtener la información desde el endpoint y guardarla
      await _fetchAndSaveForm(db, widget.ctInspectionUuid);
    } else {
      // No hay conexión y no se encontró la información en la base de datos
      _showMessage("Se requiere conexión a internet para continuar");
    }
  }

  Future<bool> _checkInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<Database> _openDatabase() async {
    return openDatabase(
      join(await getDatabasesPath(), 'inspections.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE inspection_forms(id INTEGER PRIMARY KEY, ct_inspection_uuid TEXT, form_json TEXT, created_at TEXT, updated_at TEXT)',
        );
      },
      version: 1,
    );
  }

  Future<Map<String, dynamic>?> _getFormFromDatabase(Database db, String ctInspectionUuid) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'inspection_forms',
      where: 'ct_inspection_uuid = ?',
      whereArgs: [ctInspectionUuid],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    } else {
      return null;
    }
  }

  Future<void> _fetchAndSaveForm(Database db, String ctInspectionUuid) async {
    final response = await http.get(Uri.parse('${Constants.apiEndpoint}/api/inspection/forms/get-form/$ctInspectionUuid'));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      final data = jsonResponse['data'];
      final now = DateTime.now().toIso8601String();

      await db.insert(
        'inspection_forms',
        {
          'ct_inspection_uuid': ctInspectionUuid,
          'form_json': jsonEncode(data),
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (mounted) {
        setState(() {
          formJson = jsonEncode(data);
        });
      }
    } else {
      _showMessage("Error al recuperar datos del servidor");
    }
  }

  Future<void> _fetchAndUpdateForm(Database db, String ctInspectionUuid) async {
    final response = await http.get(Uri.parse('${Constants.apiEndpoint}/api/inspection/forms/get-form/$ctInspectionUuid'));

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      final data = jsonResponse['data'];
      final now = DateTime.now().toIso8601String();

      await db.update(
        'inspection_forms',
        {
          'form_json': jsonEncode(data),
          'updated_at': now,
        },
        where: 'ct_inspection_uuid = ?',
        whereArgs: [ctInspectionUuid],
      );

      if (mounted) {
        setState(() {
          formJson = jsonEncode(data);
        });
      }
    } else {
      _showMessage("Error al actualizar datos del servidor");
    }
  }

  void _showMessage(String message) {
    _scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldMessengerKey,
      appBar: AppBar(
        title: Text('Inspection Form'),
      ),
      body: formJson != null
          ? SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Text(formJson ?? '', style: TextStyle(fontSize: 16.0)),
      )
          : Center(child: CircularProgressIndicator()),
    );
  }
}
