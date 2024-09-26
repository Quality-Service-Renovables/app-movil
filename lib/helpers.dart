import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

Future<bool> checkInternetConnection() async {
  // Primero, verifica si el dispositivo está conectado a una red.
  final connectivityResult = await Connectivity().checkConnectivity();

  if (connectivityResult != ConnectivityResult.none) {
    // Si está conectado a una red, realiza una solicitud HTTP a un servidor confiable.
    try {
      final response = await http
          .get(Uri.parse("https://www.google.com"))
          .timeout(const Duration(seconds: 5));

      // Si la solicitud es exitosa y el código de estado es 200, hay acceso a Internet.
      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      // Si ocurre algún error (por ejemplo, timeout), se considera que no hay acceso a Internet.
      return false;
    }
  } else {
    // Si no está conectado a ninguna red, devuelve false.
    return false;
  }
}

void showErrorDialog(
    BuildContext context, String title, List<String> messages) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: messages.length == 1
            ? Text(
                messages.first,
                style: const TextStyle(fontSize: 16),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: messages
                    .map((message) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("• ", style: TextStyle(fontSize: 16)),
                              Expanded(
                                child: Text(
                                  message,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

void printPrettyJson(Map<String, dynamic> jsonData) {
  const encoder = JsonEncoder.withIndent('  ');
  String prettyJson = encoder.convert(jsonData);
  debugPrint(prettyJson);
}
