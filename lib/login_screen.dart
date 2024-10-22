import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'welcome_screen.dart';
import 'utils/constants.dart';
import 'helpers.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController =
      TextEditingController(text: "");
  final TextEditingController _passwordController =
      TextEditingController(text: "");
  bool _isLoading = false;
  bool _obscureText = true; // Estado inicial, la contraseña está oculta
  bool _rememberMe = true; // Estado inicial, recordar contraseña activado

  @override
  void initState() {
    super.initState();
    _checkForExistingToken();
    _loadUserData(); // Cargar el usuario y la contraseña si están guardados
  }

  // Método para cargar los datos guardados
  _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailController.text = prefs.getString('email') ?? '';
      _passwordController.text = prefs.getString('password') ?? '';
      _rememberMe = prefs.getBool('rememberMe') ?? false;
    });
  }

  // Método para guardar los datos del usuario
  _saveUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      prefs.setString('email', _emailController.text);
      prefs.setString('password', _passwordController.text);
      prefs.setBool('rememberMe', _rememberMe);
    } else {
      prefs.remove('email');
      prefs.remove('password');
      prefs.remove('rememberMe');
    }
  }

  Future<void> _checkForExistingToken() async {
    final db = await DatabaseHelper().database;

    // Consulta para verificar que el token existe y que expired_at es null
    List<Map> result = await db.query(
      'sessions',
      columns: [
        'token',
        'expired_at'
      ], // Incluimos 'expired_at' para depuración
      where: 'expired_at IS NULL',
    );

    if (result.isNotEmpty) {
      // Si hay un token válido, redirigir a la pantalla de bienvenida
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    final response = await http.post(
      Uri.parse('${Constants.apiEndpoint}/api/session/login'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'email': _emailController.text,
        'password': _passwordController.text,
      }),
    );

    final Map<String, dynamic> responseData = json.decode(response.body);

    if (response.statusCode == 200 && responseData['status'] == 'ok') {
      final token = responseData['data'];

      final profile = await http.get(
        Uri.parse('${Constants.apiEndpoint}/api/profile/'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      //print('Profile: ${profile.body}');
      final profileAux = json.decode(profile.body);
      final name = profileAux['name'];
      final email = profileAux['email'];
      final avatar =
          await saveURLImageAndGetLocalPath(profileAux['image_profile']);
      //print("Name: $name");
      //print("Email: $email");
      //print("Avatar: $avatar");

      final db = await DatabaseHelper().database;

      // Insertar token en la base de datos
      await db.insert('sessions', {
        'token': token,
        'name': name,
        'email': email,
        'avatar': avatar,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Persistir el token en SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('name', name);
      await prefs.setString('email', email);
      await prefs.setString('avatar', avatar);
      _saveUserData(); // Guardar los datos tras autenticarse

      //print("-------> ✓ LOGIN OK <-------");

      setState(() {
        _isLoading = false;
      });

      // Redirigir a la pantalla de bienvenida
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    } else {
      setState(() {
        _isLoading = false;
      });
      //print("-------> x LOGIN FALLIDO <-------");
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error de inicio de sesión'),
            content: Text(responseData['message'] ?? 'Error desconocido'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
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
        title: const Text('Inicio de sesión'),
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
                height: 75,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Correo',
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
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  labelStyle: TextStyle(color: Colors.red[900]),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red[900]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red[900]!),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                      color: Colors.red[900],
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                ),
                obscureText: _obscureText,
                cursorColor: Colors.red[900],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (bool? value) {
                      setState(() {
                        _rememberMe = value!;
                      });
                    },
                  ),
                  Text('Recordar contraseña'),
                ],
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? CircularProgressIndicator(color: Colors.red[900])
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.grey[800], // Botón gris oscuro
                        padding: const EdgeInsets.symmetric(
                          horizontal: 50,
                          vertical: 15,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('Entrar'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
