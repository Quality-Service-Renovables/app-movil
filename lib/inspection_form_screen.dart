import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'logout_service.dart'; // Importa el servicio de logout
import 'helpers.dart';

class InspectionFormScreen extends StatefulWidget {
  final String ctInspectionUuid;

  const InspectionFormScreen({super.key, required this.ctInspectionUuid});

  @override
  _InspectionFormScreenState createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  Map<String, dynamic> _inspectionData = {};
  bool _isLoading = true;

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _getFormInspection(widget.ctInspectionUuid);
  }

  Future<void> _getFormInspection(String ctInspectionUuid) async {
    final hasConnection = await checkInternetConnection();
    final db = await DatabaseHelper().database;
    if (hasConnection) {
      await _updateFormInspection(db, widget.ctInspectionUuid);
    }
    await _getFormFromDatabase(db, ctInspectionUuid);
  }

  Future<void> _updateFormInspection(
      Database db, String ctInspectionUuid) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print('Existe conexión y se debe actualizar el json: $ctInspectionUuid');
    final response = await http.get(
      Uri.parse(
          'https://qsr.mx/api/inspection/forms/get-form/$ctInspectionUuid'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

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
      showErrorDialog(
        context,
        'QSR no disponible',
        [
          'No fue posible recuperar la información',
          'Información no actualizada'
        ],
      );
    }
  }

  Future<void> _getFormFromDatabase(
      Database db, String ctInspectionUuid) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'inspection_forms',
      columns: ['json_form'],
      where: 'ct_inspection_uuid = ?',
      whereArgs: [ctInspectionUuid],
    );

    if (maps.isNotEmpty) {
      final jsonData = jsonDecode(maps.first['json_form']);
      final Map<String, dynamic> sections = jsonData['sections'] ?? {};

      setState(() {
        _inspectionData = sections;
        _isLoading = false;
      });
    } else {
      print('No se encontró información en la base de datos');
      showErrorDialog(
        context,
        'QSR Checklist',
        [
          'No se encontró checklist, no es posible continuar.',
          'Revise se conexión.',
          'Si el problema persiste contacte al administrador.',
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () =>
                LogoutService.logout(context), // Utiliza el servicio de logout
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(10),
              // Secciones
              children: _inspectionData.entries.map((entry) {
                final fields = entry.value['fields'] as Map<String, dynamic>;
                final subsections =
                    entry.value['sub_sections'] as List<dynamic>;

                return ExpansionTile(
                  title: Text(entry.value['section_details']
                      ['ct_inspection_section'] as String),
                  subtitle: Text("Sección"),
                  textColor: Colors.blueAccent,
                  collapsedTextColor: Colors.blueAccent,
                  children: <Widget>[
                    // Campos
                    Column(
                      children: fields.entries.map((fieldEntry) {
                        final field = fieldEntry.value;
                        return ListTile(
                          title: Text(field['ct_inspection_form']),
                          subtitle: Text("Campo"),
                        );
                      }).toList(),
                    ),
                    // Subsecciones
                    Column(
                      children: subsections.map((subsection) {
                        final fieldsSub = subsection['fields'] as Map<String, dynamic>;
                        return ExpansionTile(
                          title: Text(
                              subsection['ct_inspection_section'] as String),
                              subtitle: Text("Sub-sección"),
                          textColor: Colors.blue,
                          collapsedTextColor: Colors.blue,
                          // Campos de la subsección
                          children: fieldsSub.entries.map((fieldSub) {
                              final field = fieldSub.value;
                              return ListTile(
                                title: Text(field['ct_inspection_form']),
                                subtitle: Text("Campo"),
                              );
                            }).toList(),
                        );
                      }).toList(),
                    ),
                  ],
                );
              }).toList(),
            ),
    );
  }
}
