import 'dart:io';

import 'package:flutter/material.dart';
import 'package:quality_service/helpers.dart';
import 'logout_service.dart'; // Importa el servicio de logout
import 'package:flutter_html/flutter_html.dart';
import 'inspection_form_screen.dart';
import 'database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'utils/constants.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

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
  bool isSync = false;

  @override
  void initState() {
    super.initState();
    _projects = widget.projects;
    print('Projects: $_projects');
    _initializeSyncStates();
    print("-------> ✓ CARGA DE PROYECTOS OK <-------");
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

  dynamic _prepareDataInspection(
      dynamic inspectionData, String inspectionUuid) {
    dynamic data = [];

    inspectionData['sections'].forEach((key, value) {
      value['fields'].forEach((key, value) {
        if (value['content']['inspection_form_comments'].isNotEmpty) {
          data.add({
            'ct_inspection_form_uuid': value['ct_inspection_form_uuid'],
            'inspection_form_comments': value['content']
                ['inspection_form_comments'],
          });
        } else if ((value['content']['inspection_form_comments'] == "" ||
                value['content']['inspection_form_comments'] == null) &&
            value['evidences'].isNotEmpty) {
          value['content']['inspection_form_comments'] = 'Por definir';
          data.add({
            'ct_inspection_form_uuid': value['ct_inspection_form_uuid'],
            'inspection_form_comments': 'Por definir',
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
            });
          } else if ((value['content']['inspection_form_comments'] == "" ||
                  value['content']['inspection_form_comments'] == null) &&
              value['evidences'].isNotEmpty) {
            value['content']['inspection_form_comments'] = 'Por definir';
            data.add({
              'ct_inspection_form_uuid': value['ct_inspection_form_uuid'],
              'inspection_form_comments': 'Por definir',
            });
          }
        });
      });
    });
    return data;
  }

  // Función para obtener el ID del campo del formulario de inspección
  int _getInspectionFormIdFromResponse(field, response) {
    int inspectionFormId = 1;
    response.forEach((value) {
      if (value['field']['ct_inspection_form_uuid'] ==
              field['ct_inspection_form_uuid'] &&
          value['inspection_form_comments'] ==
              field['content']['inspection_form_comments']) {
        inspectionFormId = value['inspection_form_id'];
      }
    });
    return inspectionFormId;
  }

  dynamic _prepareDataInspectionEvidences(
      dynamic inspectionData, String inspectionUuid, response) {
    dynamic data = [];

    inspectionData['sections'].forEach((key, value) {
      value['fields'].forEach((key, value) {
        if (value['content']['inspection_form_comments'].isNotEmpty &&
            value['evidences'].isNotEmpty) {
          int i = 1;
          value['evidences'].forEach((evidence) {
            data.add({
              'evidence_store': evidence,
              'inspection_uuid': inspectionUuid,
              'position': "$i",
              'inspection_form_id': value['content']['inspection_form_id'] ??
                  _getInspectionFormIdFromResponse(value, response),
            });
            i++;
          });
        }
      });

      value['sub_sections'] = value['sub_sections'] ?? [];
      value['sub_sections'].forEach((subSection) {
        subSection['fields'].forEach((key, value) {
          if (value['content']['inspection_form_comments'].isNotEmpty &&
              value['evidences'].isNotEmpty) {
            int i = 1;
            value['evidences'].forEach((evidence) {
              data.add({
                'evidence_store': evidence,
                'inspection_uuid': inspectionUuid,
                'position': "$i",
                'inspection_form_id': value['content']['inspection_form_id'] ??
                    _getInspectionFormIdFromResponse(value, response),
              });
              i++;
            });
          }
        });
      });
    });
    return data;
  }

  dynamic _updateInspectionFields(inspectionUuid, inspectionData) async {
    dynamic data = _prepareDataInspection(inspectionData, inspectionUuid);
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
    return jsonResponse['data'];
  }

  Future<void> _updateInspectionFieldsEvidences(
      inspectionUuid, inspectionData, response) async {
    dynamic data = _prepareDataInspectionEvidences(
        inspectionData, inspectionUuid, response);

    // Generamos un UUID v4 para la sincronización
    var uuid = const Uuid();
    String syncAppUuid = uuid.v4();

    // Iteramos las evidencias para enviarlas una por una
    data.forEach((value) {
      dynamic valueAux = {
        'inspection_uuid': value['inspection_uuid'],
        'position': value['position'],
        'inspection_form_id': value['inspection_form_id'],
        'from': 'app',
        'sync_app_uuid': syncAppUuid,
      };
      sendEvidences(valueAux, File(value['evidence_store']));
    });
  }

  Future<void> sendEvidences(Map<String, dynamic> data, File imageFile) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    // Crea una solicitud multipart
    var request = http.MultipartRequest(
        'POST', Uri.parse("${Constants.apiEndpoint}/api/inspection/evidences"));

    // Agrega el Bearer Token en los headers
    request.headers['Authorization'] = 'Bearer $token';

    // Adjunta los demás datos del JSON a la solicitud
    data.forEach((key, value) {
      request.fields[key] = value.toString();
    });

    // Adjunta la imagen como archivo
    var stream = http.ByteStream(imageFile.openRead());
    var length = await imageFile.length();

    // Crea un archivo multipart
    var multipartFile = http.MultipartFile(
      'evidence_store', // Clave del archivo en el endpoint Laravel
      stream,
      length,
      filename: path.basename(imageFile.path),
    );

    // Adjunta el archivo a la solicitud
    request.files.add(multipartFile);

    // Se envía la solicitud
    var response = await request.send();

    // Obtenemos la respuesta detallada
    var responseData = await http.Response.fromStream(response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('Success: ${responseData.body}');
    } else {
      print(
          'Response body: ${responseData.body}, Error: ${response.statusCode}');
    }
  }

  Future<void> _syncWithProduction(String inspectionUuid) async {
    final hasConnection = await checkInternetConnection();
    if (!hasConnection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Parece que no tienes conexión a internet, por favor verifica tu conexión.'),
          backgroundColor: Colors.red, // Color rojo
        ),
      );
      return;
    }
    // INICIO - Mostramos un mensaje de sincronización
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sincronizando datos...'),
        backgroundColor: Colors.teal, // Color verde
      ),
    );

    // PASO 1: Obtenemos la data de la inspección
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> inspectionForm = await db.query(
      'inspection_forms',
      columns: ['json_form'],
      where: 'inspection_uuid = ?',
      whereArgs: [inspectionUuid],
    );

    // PASO 2: Si hay datos en la inspección
    if (inspectionForm.isNotEmpty) {
      Map<String, dynamic> inspectionData =
          jsonDecode(inspectionForm.first['json_form']);

      try {
        // PASO 3: Actualizamos los campos de la inspección
        dynamic response =
            await _updateInspectionFields(inspectionUuid, inspectionData);

        // PASO 4: Actualizamos las evidencias de cada campo de la inspección
        await _updateInspectionFieldsEvidences(
            inspectionUuid, inspectionData, response);

        // PASO 5: Actualizamos el estado de sincronización
        await _setSyncState(inspectionUuid);
        // FIN - Muestra un mensaje de éxito.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sincronización exitosa'),
            backgroundColor: Colors.green, // Color verde
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error durante la sincronización: $e'),
            backgroundColor: Colors.red, // Color verde
          ),
        );
        print('Error durante la sincronización: $e');
      }
    }
  }

  Future<void> _setSyncState(inspectionUuid) async {
    final db = await DatabaseHelper().database;

    await db.update(
      'inspection_forms',
      {'is_sync': 1},
      where: 'inspection_uuid = ?',
      whereArgs: [inspectionUuid],
    );

    setState(() {
      isSync = true;
    });
  }

  Future<void> _initializeSyncStates() async {
    for (var project in _projects) {
      final inspectionUuid = project['inspection_uuid'];
      await _getSyncState(inspectionUuid);
    }
  }

  Future<void> _getSyncState(String inspectionUuid) async {
    final db = await DatabaseHelper().database;

    final List<Map<String, dynamic>> inspectionForm = await db.query(
      'inspection_forms',
      columns: ['is_sync'],
      where: 'inspection_uuid = ? AND is_sync = 1',
      whereArgs: [inspectionUuid],
    );

    print('Inspection form sync status');
    print(inspectionForm);
    print(inspectionForm.isNotEmpty);
    print(inspectionUuid);
    print('Inspection form sync status - end');

    setState(() {
      isSync = inspectionForm.isNotEmpty;
    });
    print(
        '*************************** isSync status ***************************');
    print(isSync);
    print(
        '*************************** isSync status ***************************');
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
            print('project..................................................');
            print(_projects[index]);
            final projectName = _projects[index]['project_name'];
            final projectDescription = _projects[index]['description'];
            final ctInspectionUuid =
                _projects[index]['ct_inspection_uuid']; // Recupera el UUID
            final inspectionUuid =
                _projects[index]['inspection_uuid']; // Recupera el UUID
            //
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
                    color: _projects[index]['status_id'] == 6 && isSync
                        ? Colors.grey
                        : Colors.blue, // Cambia color según estado
                    shape: BoxShape.circle, // Forma redondeada
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.cloud_sync,
                        color: Colors.white), // Ícono con color blanco
                    onPressed: _projects[index]['status_id'] == 6 && isSync
                        ? null // Deshabilita el botón si está subiendo
                        : () => _syncWithProduction(inspectionUuid),
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
