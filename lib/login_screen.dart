import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'welcome_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController(text: "jburto@qsr.mx");
  final TextEditingController _passwordController = TextEditingController(text: "qsr.2024!");
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkForExistingToken();
  }

  Future<void> _checkForExistingToken() async {
    final db = await DatabaseHelper().database;

    // Consulta para verificar que el token existe y que expired_at es null
    List<Map> result = await db.query(
      'sessions',
      columns: ['token', 'expired_at'], // Incluimos 'expired_at' para depuración
      where: 'expired_at IS NULL',
    );

    // Imprimir el resultado de la consulta
    print('Resultado de la consulta de token: $result');

    if (result.isNotEmpty) {
      // Si hay un token válido, redirigir a la pantalla de bienvenida
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => WelcomeScreen()),
      );
    } else {
      // Si no hay un token válido, imprimir un mensaje de depuración
      print('No se encontró un token válido o el campo expired_at no es NULL.');
    }
  }


  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    final response = await http.post(
      Uri.parse('https://qsr.mx/api/session/login'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'email': _emailController.text,
        'password': _passwordController.text,
      }),
    );

    setState(() {
      _isLoading = false;
    });

    final Map<String, dynamic> responseData = json.decode(response.body);

    if (response.statusCode == 200 && responseData['status'] == 'ok') {
      final token = responseData['data'];
      final db = await DatabaseHelper().database;

      // Insertar token en la base de datos
      await db.insert('sessions', {
        'token': token,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Persistir el token en SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);

      // Redirigir a la pantalla de bienvenida
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => WelcomeScreen()),
      );
    } else {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inicio de Sesión'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.red[900], // Rojo oscuro
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Image.asset(
                'assets/img/qsr_logo.png',
                height: 100,
              ),
              SizedBox(height: 20),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.red[900]),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red[900]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red[900]!),
                  ),
                ),
                cursorColor: Colors.red[900],
              ),
              SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.red[900]),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red[900]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red[900]!),
                  ),
                ),
                obscureText: true,
                cursorColor: Colors.red[900],
              ),
              SizedBox(height: 20),
              _isLoading
                  ? CircularProgressIndicator(color: Colors.red[900])
                  : ElevatedButton(
                onPressed: _login,
                child: Text('Login'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.grey[800], // Botón gris oscuro
                  padding: EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 15,
                  ),
                  textStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
