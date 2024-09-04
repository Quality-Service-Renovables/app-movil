import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'logout_service.dart'; // Importa el servicio de logout
import 'helpers.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class InspectionFormScreen extends StatefulWidget {
  final String ctInspectionUuid;

  const InspectionFormScreen({super.key, required this.ctInspectionUuid});

  @override
  _InspectionFormScreenState createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  Map<String, dynamic> _inspectionData = {};
  bool _isLoading = true;
  File? _image;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _getFormInspection(widget.ctInspectionUuid);
  }

  // Método para seleccionar una imagen desde la galería
  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  // Método para eliminar la imagen seleccionada
  void _removeImage() {
    setState(() {
      _image = null;
    });
  }

  // Método para mostrar la imagen en un modal
  void _viewImage() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(_image!),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close'),
              ),
            ],
          ),
        );
      },
    );
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

  Future<void> _refreshInspectionData() async {
    await _getFormInspection(widget.ctInspectionUuid);
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
          : RefreshIndicator(
              onRefresh: _refreshInspectionData,
              child: ListView(
                padding: const EdgeInsets.all(10),
                // Secciones
                children: _inspectionData.entries.map((entry) {
                  final fields = entry.value['fields'] as Map<String, dynamic>;
                  final subsections =
                      entry.value['sub_sections'] as List<dynamic>;

                  return ExpansionTile(
                    title: Text(entry.value['section_details']
                        ['ct_inspection_section'] as String),
                    subtitle: const Text("Sección"),
                    textColor: Colors.blueAccent,
                    collapsedTextColor: Colors.blueAccent,
                    children: <Widget>[
                      // Campos
                      Column(
                        children: fields.entries.map((fieldEntry) {
                          final field = fieldEntry.value;
                          return Column(children: [
                            ListTile(
                              title: Text(field['ct_inspection_form']),
                              subtitle: const Text("Campo"),
                            ),
                            _image == null
                                ? Text('No image selected.')
                                : Stack(
                                    children: [
                                      // Imagen seleccionada
                                      Image.file(
                                        _image!,
                                        width: 75,
                                      ),
                                      // Botón de eliminación en forma de "X"
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: _removeImage,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            padding: EdgeInsets.all(8),
                                            child: Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Botón para visualizar la imagen
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        child: GestureDetector(
                                          onTap: _viewImage,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              shape: BoxShape.circle,
                                            ),
                                            padding: EdgeInsets.all(8),
                                            child: Icon(
                                              Icons.zoom_in,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                            SizedBox(height: 5),
                            ElevatedButton(
                              onPressed: () => _pickImage(ImageSource.gallery),
                              child: Text('Select Image from Gallery'),
                            ),
                            ElevatedButton(
                              onPressed: () => _pickImage(ImageSource.camera),
                              child: Text('Take Photo with Camera'),
                            ),
                          ]);
                        }).toList(),
                      ),
                      // Subsecciones
                      Column(
                        children: subsections.map((subsection) {
                          final fieldsSub =
                              subsection['fields'] as Map<String, dynamic>;
                          return ExpansionTile(
                            title: Text(
                                subsection['ct_inspection_section'] as String),
                            subtitle: const Text("Sub-sección"),
                            textColor: Colors.blue,
                            collapsedTextColor: Colors.blue,
                            // Campos de la subsección
                            children: fieldsSub.entries.map((fieldSub) {
                              final field = fieldSub.value;
                              return ListTile(
                                title: Text(field['ct_inspection_form']),
                                subtitle: const Text("Campo"),
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }
}
