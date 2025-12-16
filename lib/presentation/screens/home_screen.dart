import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/persons/persons_bloc.dart';
import '../bloc/persons/persons_state.dart';
import '../../domain/entities/person.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PersonsBloc, PersonsState>(
      builder: (context, state) {
        final persons = state is PersonsLoaded ? state.persons : <Person>[];

        final screenSize = MediaQuery.of(context).size;
        final isSmallScreen = screenSize.width < 400;
        final isMediumScreen =
            screenSize.width >= 400 && screenSize.width < 600;
        final isLargeScreen = screenSize.width >= 600;

        final int totalImages =
            persons.fold(0, (int sum, person) => sum + person.imageCount);

        return _buildHomeContent(context, persons, totalImages, screenSize,
            isSmallScreen, isMediumScreen, isLargeScreen);
      },
    );
  }

  Widget _buildHomeContent(
    BuildContext context,
    List<Person> persons,
    int totalImages,
    Size screenSize,
    bool isSmallScreen,
    bool isMediumScreen,
    bool isLargeScreen,
  ) {
    final appBarHeight = isSmallScreen
        ? 200.0
        : isMediumScreen
            ? 240.0
            : 280.0;
    final titleFontSize = isSmallScreen
        ? 20.0
        : isMediumScreen
            ? 24.0
            : 28.0;
    final subtitleFontSize = isSmallScreen
        ? 12.0
        : isMediumScreen
            ? 14.0
            : 16.0;
    final padding = isSmallScreen
        ? 12.0
        : isMediumScreen
            ? 16.0
            : 20.0;
    final gridSpacing = isSmallScreen
        ? 10.0
        : isMediumScreen
            ? 12.0
            : 15.0;
    final crossAxisCount = isSmallScreen
        ? 2
        : isMediumScreen
            ? 2
            : 3;
    final childAspectRatio = isSmallScreen
        ? 1.0
        : isMediumScreen
            ? 1.15
            : 1.3;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: appBarHeight,
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
                          Icon(
                            Icons.face_retouching_natural,
                            size: isSmallScreen
                                ? 40
                                : isMediumScreen
                                    ? 50
                                    : 60,
                            color: Colors.white,
                          ),
                          SizedBox(height: isSmallScreen ? 10 : 15),
                          Text(
                            'Reconocimiento Facial Inteligente',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isSmallScreen ? 6 : 10),
                          Text(
                            '${persons.length} personas • $totalImages imágenes',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: subtitleFontSize,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Sistema con múltiples imágenes por persona',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: subtitleFontSize - 2,
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

          // Encabezado de sección para las funciones rápidas
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(padding, 16, padding, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Funciones rápidas',
                    style: TextStyle(
                      fontSize: isSmallScreen
                          ? 16
                          : isMediumScreen
                              ? 18
                              : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Accede rápidamente a lo más usado',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: isSmallScreen
                          ? 11
                          : isMediumScreen
                              ? 12
                              : 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: EdgeInsets.all(padding),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: gridSpacing,
                mainAxisSpacing: gridSpacing,
                childAspectRatio: childAspectRatio,
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
                  'Personas',
                  'Ver y gestionar todas las personas registradas',
                  Colors.orange,
                  () => Navigator.pushNamed(context, '/persons'),
                ),
                // Removido: Botón "Añadir Imágenes" para evitar duplicidad
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
              margin: EdgeInsets.all(padding),
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📊 Estadísticas del Sistema',
                    style: TextStyle(
                      fontSize: isSmallScreen
                          ? 14
                          : isMediumScreen
                              ? 16
                              : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 10 : 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(Icons.people, 'Personas', persons.length,
                          isSmallScreen),
                      _buildStatItem(
                          Icons.photo, 'Imágenes', totalImages, isSmallScreen),
                      _buildStatItem(
                          Icons.trending_up, 'Precisión', '95%', isSmallScreen),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 10 : 15),
                  Text(
                    '💡 Consejo: Añade 5-10 imágenes por persona con diferentes ángulos y expresiones para obtener los mejores resultados de reconocimiento.',
                    style: TextStyle(
                      color: Colors.blueGrey,
                      fontSize: isSmallScreen
                          ? 11
                          : isMediumScreen
                              ? 12
                              : 13,
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

  Widget _buildStatItem(
      IconData icon, String label, dynamic value, bool isSmallScreen) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: isSmallScreen ? 24 : 30),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey,
            fontSize: isSmallScreen ? 10 : 12,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value.toString(),
          style: TextStyle(
            color: Colors.blue,
            fontSize: isSmallScreen ? 14 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
              // Encabezado con gradiente e icono
              Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(0.12),
                      color.withOpacity(0.25),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios,
                        size: 16, color: color.withOpacity(0.8)),
                    const SizedBox(width: 10),
                  ],
                ),
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

  // Removido: _showSettings() ya no es necesario tras eliminar la tarjeta de Configuración

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
                'Cómo usar el sistema',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ListTile(
                dense: true,
                leading: const Icon(Icons.person_add, color: Colors.green),
                title: const Text('Registrar Personas'),
                subtitle: const Text(
                    'Crea una persona y añade 3-10 imágenes con diferentes ángulos.'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/add-person');
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Reconocimiento en tiempo real'),
                subtitle: const Text(
                    'Usa la cámara para identificar rostros al instante.'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/camera');
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.people, color: Colors.orange),
                title: const Text('Gestionar Personas'),
                subtitle: const Text(
                    'Edita información y añade/elimina imágenes por persona.'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/persons');
                },
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              const Text(
                'Recomendaciones',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                '• Buena iluminación frontal (evita contraluz)\n'
                '• Varias expresiones y ángulos ligeros\n'
                '• Sin obstrucciones (gafas oscuras, gorras)\n'
                '• Rellena mínimo 3 imágenes por persona para mejor precisión',
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/camera');
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Abrir cámara'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/add-person');
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Nueva persona'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/persons');
                    },
                    icon: const Icon(Icons.people),
                    label: const Text('Ver personas'),
                  ),
                ],
              ),
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
