import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'login_screen.dart';
import 'utils/constants.dart';

class LogoutService {
  static Future<void> logout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null) {
      final response = await http.post(
        Uri.parse(Constants.apiEndpoint + '/api/session/logout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'token': token,
        }),
      );

      final db = await DatabaseHelper().database;
      final currentTime = DateTime.now().toIso8601String();

      if (response.statusCode == 200) {
        // Actualizar todos los registros de tokens expirados
        await db.update(
          'sessions',
          {'expired_at': currentTime},
          where: 'expired_at IS NULL',
        );

        // Limpiar el token de SharedPreferences
        await prefs.remove('token');

        // Redirigir a la pantalla de login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      } else {
        _showErrorDialog(context, 'Error al cerrar sesión: ${response.reasonPhrase}');
      }
    }
  }

  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
