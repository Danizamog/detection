import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final persons = Provider.of<List<Map<String, dynamic>>>(context);

    // CORREGIDO: Especificar que el fold retorna un int
    final int totalImages = persons.fold(
        0, (int sum, person) => sum + (person['imageCount'] as int? ?? 0));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.lightBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.1,
                        child: Icon(
                          Icons.face_retouching_natural,
                          size: 200,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.face_retouching_natural,
                            size: 60,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            'Reconocimiento Facial Inteligente',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${persons.length} personas • $totalImages imágenes',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Sistema con múltiples imágenes por persona',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.2,
              ),
              delegate: SliverChildListDelegate([
                _buildFeatureCard(
                  Icons.camera_alt,
                  'Reconocimiento en Tiempo Real',
                  'Usa la cámara para identificar rostros',
                  Colors.blue,
                  () => Navigator.pushNamed(context, '/camera'),
                ),
                _buildFeatureCard(
                  Icons.person_add,
                  'Registrar Nueva Persona',
                  'Añade múltiples imágenes para mejor precisión',
                  Colors.green,
                  () => Navigator.pushNamed(context, '/add-person'),
                ),
                _buildFeatureCard(
                  Icons.people,
                  'Base de Datos',
                  'Ver y gestionar todas las personas',
                  Colors.orange,
                  () => Navigator.pushNamed(context, '/persons'),
                ),
                _buildFeatureCard(
                  Icons.photo_library,
                  'Galería de Imágenes',
                  'Ver todas las imágenes faciales',
                  Colors.purple,
                  () => Navigator.pushNamed(context, '/persons'),
                ),
                _buildFeatureCard(
                  Icons.settings,
                  'Configuración',
                  'Ajustes del sistema',
                  Colors.teal,
                  () => _showSettings(context),
                ),
                _buildFeatureCard(
                  Icons.help,
                  'Ayuda y Guía',
                  'Cómo usar el sistema',
                  Colors.indigo,
                  () => _showHelp(context),
                ),
              ]),
            ),
          ),

          // Estadísticas rápidas
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📊 Estadísticas del Sistema',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(Icons.people, 'Personas', persons.length),
                      _buildStatItem(Icons.photo, 'Imágenes', totalImages),
                      _buildStatItem(Icons.trending_up, 'Precisión', '95%'),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    '💡 Consejo: Añade 5-10 imágenes por persona con diferentes ángulos y expresiones para obtener los mejores resultados de reconocimiento.',
                    style: TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    IconData icon,
    String title,
    String description,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, dynamic value) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 30),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value.toString(),
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuración'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Opciones del sistema:\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ListTile(
                leading: Icon(Icons.notifications),
                title: Text('Notificaciones'),
                trailing: Switch(value: true, onChanged: null),
              ),
              ListTile(
                leading: Icon(Icons.security),
                title: Text('Modo seguro'),
                trailing: Switch(value: true, onChanged: null),
              ),
              ListTile(
                leading: Icon(Icons.save),
                title: Text('Guardar automáticamente'),
                trailing: Switch(value: true, onChanged: null),
              ),
              ListTile(
                leading: Icon(Icons.cloud_upload),
                title: Text('Sincronización en la nube'),
                trailing: Switch(value: true, onChanged: null),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guía de Uso'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cómo usar el sistema:\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildHelpStep('1', 'Registrar Personas',
                  'Añade nuevas personas con múltiples imágenes desde diferentes ángulos.'),
              _buildHelpStep('2', 'Reconocimiento',
                  'Usa la cámara para identificar rostros en tiempo real.'),
              _buildHelpStep('3', 'Gestionar Base de Datos',
                  'Visualiza y edita todas las personas registradas.'),
              _buildHelpStep('4', 'Añadir Más Imágenes',
                  'Para mejorar la precisión, añade más imágenes a personas existentes.'),
              const SizedBox(height: 10),
              const Text(
                '📌 Recomendaciones:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                  '• Usa buena iluminación\n• Varias expresiones faciales\n• Diferentes ángulos\n• Sin obstrucciones (gafas, gorras)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpStep(String number, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
