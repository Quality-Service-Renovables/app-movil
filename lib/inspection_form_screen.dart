import 'package:flutter/material.dart';
import 'dart:convert'; // Para manejar JSON

class InspectionFormScreen extends StatelessWidget {
  final String ctInspectionUuid;

  InspectionFormScreen({required this.ctInspectionUuid});

  // Ejemplo de JSON simulado (en producción esto vendrá de tu API)
  final String jsonResponse = '''{
    "status": "ok",
    "message": "Records retrieved successfully.",
    "data": {
      "sections": {
        "inspeccion_externa": {
          "section_details": {
            "ct_inspection_section_uuid": "3014a180-a552-4072-844b-b70d07c0aea1",
            "ct_inspection_section": "Inspección Externa",
            "ct_inspection_section_code": "inspeccion_externa",
            "ct_inspection_relation_id": null,
            "created_at": "2024-08-23T03:14:37.000000Z",
            "updated_at": "2024-08-23T03:14:37.000000Z",
            "deleted_at": null
          },
          "fields": [],
          "sub_sections": [
            {
              "ct_inspection_section_uuid": "3dc6ea35-2109-456e-a03e-a36ab381b0d0",
              "ct_inspection_section": "Sistema Refrigeración",
              "ct_inspection_section_code": "sistema_refrigeracion",
              "ct_inspection_relation_id": 1,
              "created_at": "2024-08-23T03:14:37.000000Z",
              "updated_at": "2024-08-23T03:14:37.000000Z",
              "deleted_at": null,
              "fields": {
                "estado_intercambiador": {
                  "ct_inspection_form_uuid": "a08e05d9-c954-4db4-beca-3dd81b4b054c",
                  "ct_inspection_form": "Estado del Intercambiador",
                  "ct_inspection_form_code": "estado_intercambiador",
                  "required": 1,
                  "created_at": "2024-08-23T03:14:37.000000Z",
                  "updated_at": "2024-08-23T03:14:37.000000Z",
                  "deleted_at": null,
                  "result": null
                },
                "funcionamiento_ventiladores": {
                  "ct_inspection_form_uuid": "a07024e0-a41e-455c-920e-304b3cfb00ad",
                  "ct_inspection_form": "Funcionamiento de Ventiladores",
                  "ct_inspection_form_code": "funcionamiento_ventiladores",
                  "required": 1,
                  "created_at": "2024-08-23T03:14:37.000000Z",
                  "updated_at": "2024-08-23T03:14:37.000000Z",
                  "deleted_at": null,
                  "result": null
                }
              }
            }
          ]
        }
      }
    }
  }''';

  @override
  Widget build(BuildContext context) {
    // Decodificar el JSON
    final Map<String, dynamic> data = json.decode(jsonResponse)['data'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Inspection Form'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          children: _buildSections(data['sections']),
        ),
      ),
    );
  }

  List<Widget> _buildSections(Map<String, dynamic> sections) {
    List<Widget> sectionWidgets = [];

    sections.forEach((key, section) {
      sectionWidgets.add(_buildSection(section));
    });

    return sectionWidgets;
  }

  Widget _buildSection(Map<String, dynamic> section) {
    List<Widget> subsectionWidgets = [];

    // Si la sección tiene subsecciones
    if (section['sub_sections'] != null) {
      section['sub_sections'].forEach((subsection) {
        subsectionWidgets.add(_buildSubsection(subsection));
      });
    }

    return Card(
      child: ExpansionTile(
        title: Text(section['section_details']['ct_inspection_section']),
        children: subsectionWidgets,
      ),
    );
  }

  Widget _buildSubsection(Map<String, dynamic> subsection) {
    List<Widget> fieldWidgets = [];

    // Si la subsección tiene campos
    if (subsection['fields'] != null) {
      subsection['fields'].forEach((key, field) {
        fieldWidgets.add(_buildField(field));
      });
    }

    return Card(
      child: ExpansionTile(
        title: Text(subsection['ct_inspection_section']),
        children: fieldWidgets,
      ),
    );
  }

  Widget _buildField(Map<String, dynamic> field) {
    return ListTile(
      title: Text(field['ct_inspection_form']),
      subtitle: Text('Código: ${field['ct_inspection_form_code']}'),
      trailing: Icon(
        field['required'] == 1 ? Icons.check_circle : Icons.circle,
        color: field['required'] == 1 ? Colors.green : Colors.red,
      ),
    );
  }
}
