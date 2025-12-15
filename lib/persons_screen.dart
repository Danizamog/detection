import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PersonsScreen extends StatelessWidget {
  const PersonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Leer modo opcional desde la navegación
    final args = ModalRoute.of(context)?.settings.arguments;
    final String? mode =
        (args is Map<String, dynamic>) ? args['mode'] as String? : null;
    final bool addImagesMode = mode == 'add-images';
    final persons = Provider.of<List<Map<String, dynamic>>>(context);

    // Responsive values
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400;
    final isMediumScreen = screenSize.width >= 400 && screenSize.width < 600;
    final gridCrossAxisCount = isSmallScreen
        ? 1
        : isMediumScreen
            ? 2
            : 3;
    final padding = isSmallScreen
        ? 12.0
        : isMediumScreen
            ? 16.0
            : 20.0;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/add-person');
        },
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva Persona'),
        elevation: 4,
      ),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 150,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.lightBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.people,
                      size: 40,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Base de Datos de Personas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${persons.length} persona${persons.length != 1 ? 's' : ''} registrada${persons.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_totalImages(persons)} imágenes faciales',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Banner guía si venimos en modo "añadir imágenes"
          if (addImagesMode)
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.fromLTRB(padding, 12, padding, 0),
                padding: EdgeInsets.all(padding),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.purple),
                    SizedBox(width: isSmallScreen ? 6 : 8),
                    Expanded(
                      child: Text(
                        'Selecciona una persona y usa los botones "Galería" o "Cámara" en su detalle para añadir nuevas imágenes.',
                        style: TextStyle(
                          color: Colors.purple,
                          fontSize: isSmallScreen ? 11 : 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Lista de personas
          if (persons.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.all(padding),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridCrossAxisCount,
                  crossAxisSpacing: padding,
                  mainAxisSpacing: padding,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final person = persons[index];
                    return _buildPersonCard(context, person);
                  },
                  childCount: persons.length,
                ),
              ),
            )
          else
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No hay personas registradas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Presiona el botón + para añadir la primera persona a la base de datos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                        ),
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

  int _totalImages(List<Map<String, dynamic>> persons) {
    // CORREGIDO: Especificar tipo int en el fold
    return persons.fold<int>(0, (int total, person) {
      final imageCount = person['imageCount'] as int? ?? 0;
      return total + imageCount;
    });
  }

  Widget _buildPersonCard(BuildContext context, Map<String, dynamic> person) {
    final images = person['images'] as List<dynamic>? ?? [];
    final imageCount = person['imageCount'] as int? ?? 0;
    final hasImages = imageCount > 0;
    final personName = person['name'] as String? ?? 'Sin nombre';
    final personDescription = person['description'] as String?;
    final createdAt = person['createdAt'] as String?;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/person-detail',
            arguments: {'personId': person['id']},
          );
        },
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen principal
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey[200],
                    image: hasImages && images.isNotEmpty
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(
                              (images.first['imageUrl'] as String?) ?? '',
                            ),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withOpacity(0.1),
                              BlendMode.darken,
                            ),
                          )
                        : null,
                  ),
                  child: Stack(
                    children: [
                      if (!hasImages)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Sin imágenes',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Badge de cantidad de imágenes
                      if (hasImages)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.photo,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$imageCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Nombre
              Text(
                personName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 1,
              ),

              const SizedBox(height: 4),

              // Descripción
              if (personDescription != null && personDescription.isNotEmpty)
                Text(
                  personDescription,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 2,
                ),

              const SizedBox(height: 8),

              // Fecha de registro
              Text(
                'Registrado: ${_formatDate(createdAt)}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Fecha desconocida';

    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Hoy';
      } else if (difference.inDays == 1) {
        return 'Ayer';
      } else if (difference.inDays < 30) {
        return 'Hace ${difference.inDays} días';
      } else if (difference.inDays < 365) {
        return 'Hace ${(difference.inDays / 30).floor()} meses';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }
}
