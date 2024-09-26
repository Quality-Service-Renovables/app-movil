import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'logout_service.dart'; // Importa el servicio de logout
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers.dart'; // Importa el helper
import 'utils/constants.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  List<dynamic> _statusList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    // Verifica el estado de conexión
    final hasConnection = await checkInternetConnection();
    final db = await DatabaseHelper().database;

    // Si existe conexión a internet activa, actualiza el formulario
    if (hasConnection) {
      await _updateSyncTable(db);
    }

    await _getStatus(db);
  }

  Future<void> _updateSyncTable(Database db) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final now = DateTime.now().toIso8601String();

    final response = await http.get(
      Uri.parse('${Constants.apiEndpoint}/api/application/sync'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      //print('Response: $responseData');

      if (responseData['data'] != null &&
          responseData['data']['status'] != null) {
        await db.insert(
          'sync',
          {
            'code': 'main',
            'status': jsonEncode(responseData['data']['status']),
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print("-------> ✓ CARGA DE ESTADOS DE PROYECTOS OK <-------");
      } else {
        print("-------> x CARGA DE ESTADOS DE PROYECTOS FALLIDA <-------");
        setState(() {
          _isLoading = false;
        });
        showErrorDialog(
          context,
          'Error de Conexión',
          ['Datos no encontrados en la respuesta.'],
        );
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      showErrorDialog(
        context,
        'Error de Conexión',
        ['Error: ${response.reasonPhrase}'],
      );
    }
  }

  Future<void> _getStatus(Database db) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'sync',
      columns: ['status'],
      where: 'code = ?', // Cláusula WHERE
      whereArgs: ['main'], // Valor para el marcador de posición
    );

    if (maps.isNotEmpty) {
      final Map<String, dynamic> firstRecord = maps.first;

      // Decodifica el string JSON en un mapa o lista
      final List<dynamic> jsonStatus = jsonDecode(firstRecord['status']);

      setState(() {
        _statusList = jsonStatus;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      showErrorDialog(
        context,
        'QSR no disponible',
        [
          'No se pudo descargar la información de sus asignaciones',
          'Revise su conexión a internet',
          'Si el problema persiste, contacte a su administrador.',
        ],
      );
    }
  }

  Future<void> _refreshStatus() async {
    await _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de Proyectos'),
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
              onRefresh: _refreshStatus,
              child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: _statusList.length,
                itemBuilder: (context, index) {
                  final statusDescription = _statusList[index]['description'];
                  final projectCount = _statusList[index]['projects'].length;
                  final projects = _statusList[index]['projects'];
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 10.0),
                    child: ListTile(
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              statusDescription,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$projectCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/projects',
                          arguments: {
                            'projects': projects,
                            'title': statusDescription,
                          },
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
