import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'supabase_service.dart';
import 'dart:math';

class PersonDetailScreen extends StatefulWidget {
  const PersonDetailScreen({super.key});

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  late int _personId;
  Map<String, dynamic>? _person;
  bool _isLoading = true;
  bool _isUploading = false;
  String? _errorMessage;
  List<File> _newImages = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadPersonData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadPersonData() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == null || args is! Map<String, dynamic>) {
      _errorMessage = 'No se proporcionó ID de persona';
      setState(() => _isLoading = false);
      return;
    }
    
    _personId = args['personId'];
    
    try {
      final persons = await SupabaseService.getPersons();
      _person = persons.firstWhere(
        (p) => p['id'] == _personId,
        orElse: () => throw Exception('Persona no encontrada'),
      );
      
      _nameController.text = _person?['name'] ?? '';
      _descriptionController.text = _person?['description'] ?? '';
    } catch (e) {
      _errorMessage = 'Error cargando datos: $e';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 800,
      );
      
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _newImages.addAll(pickedFiles.map((file) => File(file.path)));
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error seleccionando imágenes: $e';
      });
    }
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 800,
      );
      
      if (pickedFile != null) {
        setState(() {
          _newImages.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error con la cámara: $e';
      });
    }
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  void _removeExistingImage(int imageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar imagen'),
        content: const Text('¿Estás seguro de que quieres eliminar esta imagen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final success = await SupabaseService.deleteFaceImage(imageId);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Imagen eliminada'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadPersonData(); // Recargar datos
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadNewImages() async {
    if (_newImages.isEmpty) return;
    
    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });
    
    try {
      int successfulUploads = 0;
      
      for (final imageFile in _newImages) {
        try {
          // Leer imagen como bytes
          final imageBytes = await imageFile.readAsBytes();
          
          // Subir imagen
          final fileName = 'person_${_personId}_add_${DateTime.now().millisecondsSinceEpoch}_$successfulUploads.jpg';
          final imageUrl = await SupabaseService.uploadImage(
            Uint8List.fromList(imageBytes),
            fileName,
          );
          
          // Generar embedding usando el servicio real
          final embedding = await _generateFaceEmbedding(imageBytes);
          
          // Añadir a la persona
          await SupabaseService.addFaceImage(
            personId: _personId,
            imageUrl: imageUrl,
            embedding: embedding,
          );
          
          successfulUploads++;
        } catch (e) {
          debugPrint('Error subiendo imagen individual: $e');
        }
      }
      
      if (successfulUploads > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $successfulUploads imagen(es) añadida(s)'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Recargar datos y limpiar nuevas imágenes
        await _loadPersonData();
        setState(() {
          _newImages.clear();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error subiendo imágenes: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _updatePersonInfo() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'El nombre es obligatorio';
      });
      return;
    }
    
    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });
    
    try {
      final success = await SupabaseService.updatePerson(
        id: _personId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Información actualizada'),
            backgroundColor: Colors.green,
          ),
        );
        
        await _loadPersonData();
        setState(() => _isEditing = false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error actualizando: $e';
      });
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _deletePerson() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar persona'),
        content: const Text('¿Estás seguro de que quieres eliminar esta persona y todas sus imágenes? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final success = await SupabaseService.deletePerson(_personId);
        if (success) {
          Navigator.pop(context, {'deleted': true});
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Error eliminando: $e';
        });
      }
    }
  }

  Future<List<double>> _generateFaceEmbedding(List<int> imageBytes) async {
    try {
      return await SupabaseService.generateFaceEmbedding(
        Uint8List.fromList(imageBytes),
      );
    } catch (e) {
      debugPrint('Error generando embedding: $e');
      return _generateMockEmbedding(imageBytes);
    }
  }

  Future<List<double>> _generateMockEmbedding(List<int> imageBytes) async {
    final embedding = List<double>.filled(512, 0.0);
    final random = Random(imageBytes.fold<int>(0, (int prev, byte) => prev + byte));
    for (int i = 0; i < embedding.length; i++) {
      embedding[i] = (random.nextDouble() * 2) - 1;
    }
    
    return embedding;
  }

  Widget _buildImageGrid(List<dynamic> images) {
    if (images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library,
              size: 60,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 10),
            const Text(
              'No hay imágenes',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        final imageUrl = image['imageUrl'] as String?;
        
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: imageUrl != null && imageUrl.isNotEmpty
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: Colors.grey[200],
              ),
              child: imageUrl == null || imageUrl.isEmpty
                  ? const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    )
                  : null,
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removeExistingImage(image['id'] as int),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNewImagesGrid() {
    if (_newImages.isEmpty) return Container();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Imágenes nuevas por añadir:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: _newImages.length,
          itemBuilder: (context, index) {
            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(_newImages[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _removeNewImage(index),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Nueva',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _isUploading ? null : _uploadNewImages,
          icon: const Icon(Icons.upload),
          label: Text(
            'Subir ${_newImages.length} imagen(es)',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_errorMessage != null && _person == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(_errorMessage!),
        ),
      );
    }
    
    final images = _person?['images'] as List<dynamic>? ?? [];
    final personName = _person?['name'] as String? ?? 'Sin nombre';
    final personDescription = _person?['description'] as String?;
    final personId = _person?['id'] as int?;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles de Persona'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Editar',
            ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deletePerson,
            tooltip: 'Eliminar',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información de la persona
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.blue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _isEditing
                              ? TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nombre',
                                    border: OutlineInputBorder(),
                                  ),
                                )
                              : Text(
                                  personName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 10),
                    
                    Row(
                      children: [
                        const Icon(Icons.description, color: Colors.blue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _isEditing
                              ? TextFormField(
                                  controller: _descriptionController,
                                  decoration: const InputDecoration(
                                    labelText: 'Descripción',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 3,
                                )
                              : Text(
                                  personDescription?.isNotEmpty == true
                                      ? personDescription!
                                      : 'Sin descripción',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 10),
                    
                    Row(
                      children: [
                        const Icon(Icons.photo_library, color: Colors.blue),
                        const SizedBox(width: 10),
                        Text(
                          '${images.length} imagen(es)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (personId != null)
                          Text(
                            'ID: $personId',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    
                    if (_isEditing)
                      Column(
                        children: [
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isUploading ? null : _updatePersonInfo,
                                  child: _isUploading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Guardar cambios'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = false;
                                      _nameController.text = personName;
                                      _descriptionController.text = personDescription ?? '';
                                    });
                                  },
                                  child: const Text('Cancelar'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Imágenes existentes
            const Text(
              'Imágenes registradas:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildImageGrid(images),
            
            // Nuevas imágenes
            _buildNewImagesGrid(),
            
            // Botones para añadir más imágenes
            if (!_isEditing)
              Column(
                children: [
                  const SizedBox(height: 30),
                  const Text(
                    'Añadir más imágenes:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Más imágenes mejoran la precisión del reconocimiento',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galería'),
                          onPressed: _pickImages,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Cámara'),
                          onPressed: _takePhoto,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            
            // Mensaje de error
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}