import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'logout_service.dart'; // Importa el servicio de logout
import 'helpers.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'utils/constants.dart';

class InspectionFormScreen extends StatefulWidget {
  final String ctInspectionUuid;
  final String inspectionUuid;

  const InspectionFormScreen(
      {super.key,
      required this.ctInspectionUuid,
      required this.inspectionUuid});

  @override
  _InspectionFormScreenState createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  Map<String, dynamic> _inspectionData = {};
  bool _isLoading = true;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  IconData _uploadIcon = Icons.save_as;

  @override
  void initState() {
    super.initState();
    _getFormInspection();
  }

  Future<void> _getFormInspection() async {
    print("inspection_uuid" + widget.inspectionUuid);
    final hasConnection = await checkInternetConnection();
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> inspectionForm = await db.query(
      'inspection_forms',
      columns: ['json_form'],
      where: 'inspection_uuid = ?',
      whereArgs: [widget.inspectionUuid],
    );

    if (inspectionForm.isNotEmpty) {
      print("Entro a 1- _getFormFromDatabase");
      await _getFormFromDatabase(db);
    } else if (inspectionForm.isEmpty && hasConnection) {
      print("2 - Entro a _updateFormInspection");
      await _updateFormInspection(db);
      await _getFormFromDatabase(db);
      print("3 - Entro a _getFormFromDatabase");
    } else if (inspectionForm.isEmpty && !hasConnection) {
      print("4 - Entro a _showErrorDialog");
      print(inspectionForm.isEmpty);
      print(hasConnection);
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

  Future<void> _updateFormInspection(Database db) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final response = await http.get(
      Uri.parse('${Constants.apiEndpoint}/api/inspection/forms/get-form/' +
          widget.ctInspectionUuid +
          '?in_process=true'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final jsonResponse = json.decode(response.body);

    print('get form inspection response: $jsonResponse');

    if (response.statusCode == 200) {
      final data = jsonResponse['data'];
      final now = DateTime.now().toIso8601String();

      await db.insert(
        'inspection_forms',
        {
          'inspection_uuid': widget.inspectionUuid,
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

  Future<void> _getFormFromDatabase(Database db) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'inspection_forms',
      columns: ['json_form'],
      where: 'inspection_uuid = ?',
      whereArgs: [widget.inspectionUuid],
    );
    setState(() {
      _inspectionData = jsonDecode(maps.first['json_form']);
      _isLoading = false;

      print("INSPECTION DATA:");
      debugPrint(jsonEncode(_inspectionData), wrapWidth: 1024);

      // Campos de las secciones
      _inspectionData['sections'].forEach((key, value) {
        value['fields'].forEach((key, value) {
          value['result'] = value['result'] ?? {};
          value['result']['inspection_form_comments'] =
              value['result']['inspection_form_comments'] ?? '';
          value['evidences'] = value['evidences'] ?? _getImagesFromField(value);
        });
      });

      // Campos de las subsecciones
      _inspectionData['sections'].forEach((key, value) {
        value['sub_sections'].forEach((subSection) {
          subSection['fields'].forEach((key, value) {
            value['result'] = value['result'] ?? {};
            value['result']['inspection_form_comments'] =
                value['result']['inspection_form_comments'] ?? '';
            value['evidences'] = value['evidences'] ?? _getImagesFromField(value);
          });
        });
      });
    });
  }

  Future<void> _refreshInspectionData() async {
    await _getFormInspection();
  }

  Future<void> _confirmChanges() async {
    setState(() {
      _isUploading = true;
    });
    //print("JSON FORM:");
    //debugPrint(jsonEncode(_inspectionData), wrapWidth: 1024);
    final hasConnection = await checkInternetConnection();

    if (hasConnection) {
      final db = await DatabaseHelper().database;
      final now = DateTime.now().toIso8601String();
      final jsonData = jsonEncode(_inspectionData);

      await db.insert(
        'inspection_forms',
        {
          'inspection_uuid': widget.inspectionUuid,
          'json_form': jsonData,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Consulta el registro guardado para depuración
      final List<Map<String, dynamic>> result = await db.query(
        'inspection_forms',
        where: 'inspection_uuid = ?',
        whereArgs: [widget.inspectionUuid],
      );
      // Cambia el ícono a cloud_done
      setState(() {
        _uploadIcon = Icons.save;
        _isUploading = false;
      });
      //print('Registro guardado: $result');
      print("Registro guardado: ");
      debugPrint(jsonData, wrapWidth: 1024);
    } else {
      showErrorDialog(
        context,
        'QSR Checklist',
        [
          'Se requiere conexión a internet para sincronización de cambios.',
        ],
      );
    }
  }

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmar cambios'),
          content: Text('¿Estás seguro de que deseas confirmar los cambios?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cierra el diálogo
              },
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                _confirmChanges(); // Llama a la función para confirmar cambios
                Navigator.of(context).pop(); // Cierra el diálogo
              },
              child: Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  // Método para seleccionar múltiples imágenes desde la galería
  Future<void> _pickImages(field) async {
    final List<XFile>? pickedFiles = await _picker.pickMultiImage();

    if (pickedFiles != null) {
      setState(() {
        field.value['evidences'] ??= [];
        field.value['evidences']
            .addAll(pickedFiles.map((pickedFile) => pickedFile.path).toList());
        _uploadIcon = Icons.save;
      });
    }
  }

  // Método para tomar una foto con la cámara
  Future<void> _takePhoto(field) async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        field.value['evidences'] ??= [];
        field.value['evidences'].add(pickedFile.path);
        _uploadIcon = Icons.save;
      });
    }
  }

  // Método para eliminar una imagen seleccionada
  void _removeImage(int index, field) {
    setState(() {
      field.value['evidences'].removeAt(index);
      _uploadIcon = Icons.save;
    });
  }

  // Método para mostrar la imagen en un modal
  void _viewImage(image) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _image(image, from: 'full'),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cerrar'),
              ),
            ],
          ),
        );
      },
    );
  }

  // Método para obtener las imágenes de un campo que ya tiene imágenes de la base de datos
  List<dynamic> _getImagesFromField(field) {
    final images = [];
    if (field['result'] != null && field['result']['evidences'] != null) {
      for (var image in field['result']['evidences']) {
        images.add("${Constants.apiEndpoint}/" + image['inspection_evidence']);
      }
    }
    return images;
  }

  // Metodo para mostrar la imagen en un widget
  Widget _image(imagePath, {String from = 'cover'}) {
    // Si la imagen es de internet
    if (imagePath.startsWith('http') || imagePath.startsWith('www')) {
      if (from == 'cover') {
        return Image.network(
          imagePath,
          width: 100,
          height: 100,
        );
      } else {
        return Image.network(
          imagePath,
          fit: BoxFit.cover,
        );
      }
    } else {
      // Si la imagen es local (file path)
      if (from == 'cover') {
        return Image.file(
          File(imagePath),
          width: 100,
          height: 100,
        );
      } else {
        return Image.file(
          File(imagePath),
          fit: BoxFit.cover,
        );
      }
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
          Container(
            margin: const EdgeInsets.only(
                left: 16.0, right: 10.0), // Margen a la izquierda
            decoration: BoxDecoration(
              color: Colors.blue, // Color de fondo
              shape: BoxShape.circle, // Forma redondeada
            ),
            child: _isUploading
                ? CircularProgressIndicator()
                : IconButton(
                    icon: Icon(_uploadIcon,
                        color: Colors.white), // Icono centrado y color blanco
                    onPressed: () => _showConfirmationDialog(
                        context), // Utiliza el servicio de logout
                  ),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshInspectionData,
              child: ListView(
                padding: const EdgeInsets.all(10),
                // Secciones
                children: (_inspectionData['sections'] as Map)
                    .values
                    .map<Widget>((entry) {
                  final fields = entry['fields'] as Map<String, dynamic>;
                  final subsections = entry['sub_sections'] as List<dynamic>;

                  return ExpansionTile(
                    title: Text(entry['section_details']
                        ['ct_inspection_section'] as String),
                    subtitle: const Text("Sección"),
                    textColor: Colors.blueAccent,
                    collapsedTextColor: Colors.blueAccent,
                    children: <Widget>[
                      // Campos
                      Column(
                        children: fields.entries.map((field) {
                          //print("FIELD...");
                          //print(field);
                          // Crea un TextEditingController para cada campo
                          TextEditingController _controller =
                              TextEditingController();

                          // Asigna el valor del result actual al controlador
                          _controller.text = field.value['result']
                                  ['inspection_form_comments'] ??
                              '';

                          return Container(
                            margin: const EdgeInsets.all(15.0),
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.blueAccent),
                                borderRadius: BorderRadius.circular(10)),
                            child: Column(children: [
                              ListTile(
                                title: Text(field.value['ct_inspection_form']),
                                subtitle: const Text("Campo"),
                              ),
                              Container(
                                margin:
                                    const EdgeInsets.only(left: 16, right: 16),
                                child: TextField(
                                  controller: _controller,
                                  decoration: InputDecoration(
                                    labelText: "Comentarios",
                                    labelStyle:
                                        TextStyle(color: Colors.red[900]),
                                    border: OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.red[900]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Colors.red[900]!),
                                    ),
                                  ),
                                  cursorColor: Colors.red[900],
                                  onChanged: (value) {
                                    // Actualiza el valor del campo 'result'
                                    field.value['result']
                                        ['inspection_form_comments'] = value;
                                  },
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment
                                    .center, // Esto centra los botones horizontalmente
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.grey), // Añadir borde
                                        borderRadius: BorderRadius.circular(
                                            8.0), // Borde redondeado opcional
                                      ),
                                      margin: EdgeInsets.all(
                                          16.0), // Espaciado opcional alrededor del botón
                                      child: IconButton(
                                        icon: const Icon(Icons.photo_library),
                                        onPressed: () => _pickImages(field),
                                        style: ButtonStyle(
                                          iconColor: WidgetStateProperty.all(
                                              Colors.red[900]),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: Colors.grey), // Añadir borde
                                        borderRadius: BorderRadius.circular(
                                            8.0), // Borde redondeado opcional
                                      ),
                                      margin: EdgeInsets.all(
                                          16.0), // Espaciado opcional alrededor del botón
                                      child: IconButton(
                                        icon: const Icon(Icons.photo_camera),
                                        onPressed: () => _takePhoto(field),
                                        style: ButtonStyle(
                                          iconColor: WidgetStateProperty.all(
                                              Colors.red[900]),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              field.value['evidences'] == null
                                  ? Text(
                                      'No se han selecionado imagenes.',
                                      textAlign: TextAlign.left,
                                    )
                                  : Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      child: Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: List.generate(
                                            field.value['evidences'].length,
                                            (index) {
                                          return Stack(
                                            children: [
                                              // Imagen seleccionada con un tamaño pequeño
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(
                                                    8.0), // Ajusta el radio del borde
                                                child: _image(field
                                                    .value['evidences'][index]),
                                              ),
                                              // Botón de eliminación en forma de "X"
                                              Positioned(
                                                top: 0,
                                                right: 0,
                                                child: GestureDetector(
                                                  onTap: () => _removeImage(
                                                      index, field),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.red,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    padding: EdgeInsets.all(4),
                                                    child: Icon(
                                                      Icons.close,
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // Botón para visualizar la imagen
                                              Positioned(
                                                top: 0,
                                                left: 0,
                                                child: GestureDetector(
                                                  onTap: () => _viewImage(field
                                                      .value['evidences'][index]),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    padding: EdgeInsets.all(4),
                                                    child: Icon(
                                                      Icons.zoom_in,
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }),
                                      )),
                            ]),
                          );
                        }).toList(),
                      ),
                      // Subsecciones
                      Column(
                        children: subsections.map((subsection) {
                          final fieldsSub =
                              subsection['fields'] as Map<String, dynamic>;

                          return ExpansionTile(
                              title: Text(subsection['ct_inspection_section']
                                  as String),
                              subtitle: const Text("Sub-sección"),
                              textColor: Colors.blue,
                              collapsedTextColor: Colors.blue,
                              // Campos de la subsección
                              children: <Widget>[
                                Column(
                                  children: fieldsSub.entries.map((fieldSub) {
                                    // Crea un TextEditingController para cada campo
                                    TextEditingController _controllerSub =
                                        TextEditingController();
                                    // Asigna el valor del result actual al controlador
                                    _controllerSub.text =
                                        fieldSub.value['result']
                                                ['inspection_form_comments'] ??
                                            '';

                                    return Container(
                                      margin: const EdgeInsets.all(15.0),
                                      decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.blueAccent),
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: Column(children: [
                                        ListTile(
                                          title: Text(fieldSub
                                              .value['ct_inspection_form']),
                                          subtitle: const Text("Campo"),
                                        ),
                                        Container(
                                          margin: const EdgeInsets.only(
                                            left: 16,
                                            right: 16,
                                          ),
                                          child: TextField(
                                            controller: _controllerSub,
                                            decoration: InputDecoration(
                                              labelText: "Comentarios",
                                              labelStyle: TextStyle(
                                                  color: Colors.red[900]),
                                              border: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: Colors.red[900]!),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: Colors.red[900]!),
                                              ),
                                            ),
                                            cursorColor: Colors.red[900],
                                            onChanged: (value) {
                                              // Actualiza el valor del campo 'result'
                                              fieldSub.value['result'][
                                                      'inspection_form_comments'] =
                                                  value;
                                            },
                                          ),
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment
                                              .center, // Esto centra los botones horizontalmente
                                          children: [
                                            Expanded(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                      color: Colors
                                                          .grey), // Añadir borde
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8.0), // Borde redondeado opcional
                                                ),
                                                margin: EdgeInsets.all(
                                                    16.0), // Espaciado opcional alrededor del botón
                                                child: IconButton(
                                                  icon: const Icon(
                                                      Icons.photo_library),
                                                  style: ButtonStyle(
                                                    iconColor:
                                                        WidgetStateProperty.all(
                                                            Colors.red[900]),
                                                  ),
                                                  onPressed: () =>
                                                      _pickImages(fieldSub),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                      color: Colors
                                                          .grey), // Añadir borde
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8.0), // Borde redondeado opcional
                                                ),
                                                margin: EdgeInsets.all(
                                                    16.0), // Espaciado opcional alrededor del botón
                                                child: IconButton(
                                                  icon: const Icon(
                                                      Icons.photo_camera),
                                                  onPressed: () =>
                                                      _takePhoto(fieldSub),
                                                  style: ButtonStyle(
                                                    iconColor:
                                                        WidgetStateProperty.all(
                                                            Colors.red[900]),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        fieldSub.value['evidences'] == null
                                            ? Text(
                                                'No images selected.',
                                                textAlign: TextAlign.left,
                                              )
                                            : Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 16),
                                                child: Wrap(
                                                  spacing: 10,
                                                  runSpacing: 10,
                                                  children: List.generate(
                                                      fieldSub.value['evidences']
                                                          .length, (index) {
                                                    return Stack(
                                                      children: [
                                                        // Imagen seleccionada con un tamaño pequeño
                                                        ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  8.0), // Ajusta el radio del borde
                                                          child: _image(fieldSub
                                                                  .value[
                                                              'evidences'][index]),
                                                        ),
                                                        // Botón de eliminación en forma de "X"
                                                        Positioned(
                                                          top: 0,
                                                          right: 0,
                                                          child:
                                                              GestureDetector(
                                                            onTap: () =>
                                                                _removeImage(
                                                                    index,
                                                                    fieldSub),
                                                            child: Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                color:
                                                                    Colors.red,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                              padding:
                                                                  EdgeInsets
                                                                      .all(4),
                                                              child: Icon(
                                                                Icons.close,
                                                                color: Colors
                                                                    .white,
                                                                size: 16,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        // Botón para visualizar la imagen
                                                        Positioned(
                                                          top: 0,
                                                          left: 0,
                                                          child:
                                                              GestureDetector(
                                                            onTap: () => _viewImage(
                                                                fieldSub.value[
                                                                        'evidences']
                                                                    [index]),
                                                            child: Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                color:
                                                                    Colors.blue,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                              padding:
                                                                  EdgeInsets
                                                                      .all(4),
                                                              child: Icon(
                                                                Icons.zoom_in,
                                                                color: Colors
                                                                    .white,
                                                                size: 16,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  }),
                                                )),
                                      ]),
                                    );
                                  }).toList(),
                                ),
                              ]);
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
