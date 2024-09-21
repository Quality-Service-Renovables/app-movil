import 'dart:io';

import 'package:flutter/material.dart';
import 'helpers.dart';
import 'logout_service.dart'; // Importa el servicio de logout
import 'package:flutter_html/flutter_html.dart';
import 'inspection_form_screen.dart';
import 'database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'utils/constants.dart';
import 'dart:convert';

class ProjectsScreen extends StatefulWidget {
  final List<dynamic> projects;
  final String title;

  const ProjectsScreen(
      {super.key, required this.projects, required this.title});

  @override
  _ProjectsScreenState createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late List<dynamic> _projects;

  @override
  void initState() {
    super.initState();
    _projects = widget.projects;
    print('Projects: $_projects');
  }

  Future<void> _refreshProjects() async {
    // Aquí puedes agregar la lógica para recargar la lista de proyectos.
    // Por ejemplo, podrías hacer una solicitud HTTP para obtener los datos actualizados.
    // Simularemos una recarga con un retraso de 2 segundos.
    await Future.delayed(const Duration(seconds: 2));

    // Actualiza el estado con los nuevos datos.
    setState(() {
      _projects =
          List.from(_projects); // Aquí deberías asignar los nuevos datos.
    });
  }

  Future<void> _syncWithProduction(String inspectionUuid) async {
    // Muestra un mensaje de éxito.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sincronizando datos...'),
        backgroundColor: Colors.teal, // Color verde
      ),
    );

    var message = 'Sincronización fallida';
    var color = Colors.red;

    // Lógica para sincronizar los datos con la producción.
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> inspectionForm = await db.query(
      'inspection_forms',
      columns: ['json_form'],
      where: 'inspection_uuid = ?',
      whereArgs: [inspectionUuid],
    );
    //print('Inspection form:');
    //printLargeString(inspectionForm.toString());
    print('*******************************************************************EVIDENCES*******************************************************************');


    if (inspectionForm.isNotEmpty) {
      final _inspectionData = jsonDecode(inspectionForm.first['json_form']);
      dynamic data = [];
      dynamic evidences = [];

      _inspectionData['sections'].forEach((key, value) {
        value['fields'].forEach((key, value) {
          if (value['content']['inspection_form_comments'].isNotEmpty) {
            evidences = [];

            if (value['content']['evidences'] != null) {
              value['content']['evidences'].forEach((evidence) async {
                if (evidence['inspection_evidence'] != null) {
                  // Suponiendo que evidence['inspection_evidence'] contiene la ruta del archivo
                  final file = File(evidence['inspection_evidence']);
                  final bytes = await file.readAsBytes();
                  final base64File = base64Encode(bytes);

                  print('evidence');
                  print(evidence['inspection_evidence']);
                  evidences.add({
                    'evidence_uuid': evidence['evidence_uuid'],
                    'evidence_store': base64File,
                  });
                }
              });
            }
            print('*******************************************************************EVIDENCES*******************************************************************');
            data.add({
              'ct_inspection_form_uuid': value['ct_inspection_form_uuid'],
              'inspection_form_comments': value['content']
              ['inspection_form_comments'],
              'evidences': evidences
              //[] // Aqui mandamos a llama la funcion que devuelve las evidencias, tendria que sacarlas del campo
            });
          }
        });

        value['sub_sections'] = value['sub_sections'] ?? [];
        value['sub_sections'].forEach((subSection) {
          subSection['fields'].forEach((key, value) {
            print('valor de subsection');
            print(value);
            if (value['content']['inspection_form_comments'].isNotEmpty) {
              data.add({
                'ct_inspection_form_uuid': value['ct_inspection_form_uuid'],
                'inspection_form_comments': value['content']
                ['inspection_form_comments'],
                'evidences':
                [] // Aqui mandamos a llama la funcion que devuelve las evidencias, tendria que sacarlas del campo
              });
            }
          });
        });
      });

      print("Data: ");
      print(data);

      try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        final response = await http.post(
          Uri.parse(
              '${Constants.apiEndpoint}/api/inspection/forms/set-form-inspection'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'inspection_uuid': inspectionUuid,
            'form': data, // Enviar `data` sin serializar a cadena
          }),
        );

        final jsonResponse = json.decode(response.body);
        print('Response: $jsonResponse');

        if (response.statusCode == 200 || response.statusCode == 201) {
          message = 'Sincronización exitosa';
          color = Colors.green;
        }
      } catch (e) {
        message = 'Error durante la sincronización: $e';
        color = Colors.red;
      }

    }


    // Muestra un mensaje de éxito.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color, // Color verde
      ),
    );
  }

  void printLargeString(String str) {
    const int chunkSize = 800; // Tamaño del fragmento
    for (int i = 0; i < str.length; i += chunkSize) {
      print(str.substring(i, i + chunkSize > str.length ? str.length : i + chunkSize));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () =>
                LogoutService.logout(context), // Utiliza el servicio de logout
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProjects,
        child: ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: _projects.length,
          itemBuilder: (context, index) {
            final projectName = _projects[index]['project_name'];
            final projectDescription = _projects[index]['description'];
            final ctInspectionUuid =
                _projects[index]['ct_inspection_uuid']; // Recupera el UUID
            final inspectionUuid =
                _projects[index]['inspection_uuid']; // Recupera el UUID

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              margin: const EdgeInsets.symmetric(vertical: 10.0),
              child: ListTile(
                title: Text(projectName),
                subtitle: Html(
                  data: projectDescription,
                ),
                trailing: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue, // Color de fondo azul
                    shape: BoxShape.circle, // Forma redondeada
                  ),
                  child: IconButton(
                    icon: Icon(Icons.cloud_sync,
                        color: Colors.white), // Ícono con color blanco
                    onPressed: () {
                      // Acción al presionar el botón
                      _syncWithProduction(
                          inspectionUuid); // Llama a la función _sync
                    },
                  ),
                ),
                onTap: () {
                  // Navega a la pantalla de inspección al hacer tap
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InspectionFormScreen(
                          ctInspectionUuid: ctInspectionUuid,
                          inspectionUuid: inspectionUuid),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}


/**
 *
    import 'dart:convert';
    import 'dart:io';

    // Suponiendo que evidence['inspection_evidence'] contiene la ruta del archivo
    final file = File(evidence['inspection_evidence']);
    final bytes = await file.readAsBytes();
    final base64File = base64Encode(bytes);

    data.add({
    'ct_inspection_form_uuid': value['ct_inspection_form_uuid'],
    'inspection_form_comments': value['content']['inspection_form_comments'],
    'evidences': [
    {
    'evidence_uuid': evidence['evidence_uuid'],
    'evidence_store': base64File,
    }
    ],
    });
 */