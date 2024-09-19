import 'package:flutter/material.dart';
import 'logout_service.dart'; // Importa el servicio de logout
import 'package:flutter_html/flutter_html.dart';
import 'inspection_form_screen.dart';

class ProjectsScreen extends StatefulWidget {
  final List<dynamic> projects;
  final String title;

  const ProjectsScreen({super.key, required this.projects, required this.title});

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
      _projects = List.from(_projects); // Aquí deberías asignar los nuevos datos.
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => LogoutService.logout(context), // Utiliza el servicio de logout
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
            final ctInspectionUuid = _projects[index]['ct_inspection_uuid']; // Recupera el UUID
            final inspectionUuid = _projects[index]['inspection_uuid']; // Recupera el UUID

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
                    icon: Icon(Icons.cloud_sync, color: Colors.white), // Ícono con color blanco
                    onPressed: () {
                      // Acción al presionar el botón
                      print('Botón presionado en el proyecto: $projectName');
                    },
                  ),
                ),
                onTap: () {
                  // Navega a la pantalla de inspección al hacer tap
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InspectionFormScreen(
                        ctInspectionUuid: ctInspectionUuid, inspectionUuid: inspectionUuid
                      ),
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