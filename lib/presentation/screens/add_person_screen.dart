import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../bloc/persons/persons_bloc.dart';

class AddPersonScreen extends StatefulWidget {
  const AddPersonScreen({super.key});

  @override
  State<AddPersonScreen> createState() => _AddPersonScreenState();
}

class _AddPersonScreenState extends State<AddPersonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<File> _selectedImages = [];
  bool _isUploading = false;
  String? _uploadError;
  String? _uploadSuccess;
  int? _createdPersonId;

  @override
  void initState() {
    super.initState();
    // Mover _checkForPreloadedImage a didChangeDependencies donde el context está disponible
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCheckedArgs) {
      _checkForPreloadedImage();
      _hasCheckedArgs = true;
    }
  }

  bool _hasCheckedArgs = false;

  void _checkForPreloadedImage() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      final imagePath = args['imagePath'] as String?;
      if (imagePath != null) {
        setState(() {
          _selectedImages.add(File(imagePath));
        });
      }
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
          _selectedImages.addAll(pickedFiles.map((file) => File(file.path)));
          _uploadError = null;
          _uploadSuccess = null;
        });
      }
    } catch (e) {
      setState(() {
        _uploadError = 'Error seleccionando imágenes: $e';
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
          _selectedImages.add(File(pickedFile.path));
          _uploadError = null;
          _uploadSuccess = null;
        });
      }
    } catch (e) {
      setState(() {
        _uploadError = 'Error con la cámara: $e';
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _savePerson() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      setState(() {
        _uploadError = 'Por favor, añade al menos una imagen del rostro';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadError = null;
      _uploadSuccess = null;
    });

    try {
      final repository = context.read<PersonsBloc>().repository;

      // 1. Crear la persona
      final personId = await repository.addPerson(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      _createdPersonId = personId;

      // 2. Procesar cada imagen: generar embedding primero, luego subir y guardar
      int successfulUploads = 0;
      int skippedNoFace = 0;
      int failedSaves = 0;

      for (final imageFile in _selectedImages) {
        try {
          // Leer imagen como bytes
          final imageBytes = await imageFile.readAsBytes();

          // Generar embedding usando el servicio real (valida rostro)
          final embedding = await _generateFaceEmbedding(imageBytes);

          // Validaciones de embedding
          if (embedding.isEmpty || embedding.length < 128) {
            skippedNoFace++;
            continue;
          }

          // Subir imagen solo si el embedding es válido
          final fileName =
              'person_${personId}_${DateTime.now().millisecondsSinceEpoch}_$successfulUploads.jpg';
          final imageUrl = await repository.uploadImage(
            Uint8List.fromList(imageBytes),
            fileName,
          );

          // Guardar imagen + embedding en BD
          final ok = await repository.addFaceImage(
            personId: personId,
            imageUrl: imageUrl,
            embedding: embedding,
            confidence: 0.95,
          );

          if (ok) {
            successfulUploads++;
          } else {
            failedSaves++;
          }
        } catch (e) {
          debugPrint('Error subiendo imagen individual: $e');
          failedSaves++;
        }
      }

      if (successfulUploads > 0) {
        setState(() {
          _uploadSuccess = '✅ Persona creada con $successfulUploads imagen(es)';
          if (skippedNoFace > 0 || failedSaves > 0) {
            _uploadSuccess =
                '✅ Persona creada con $successfulUploads imagen(es). '
                'Omitidas sin rostro: $skippedNoFace, fallidas: $failedSaves';
          }
        });

        // Limpiar formulario después de 3 segundos
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _uploadSuccess != null) {
            _clearForm();
            // Navegar de regreso
            Navigator.pop(context);
          }
        });
      } else {
        // Si ninguna imagen fue válida, eliminar la persona creada para no dejar registros vacíos
        try {
          await repository.deletePerson(personId);
        } catch (_) {}
        setState(() {
          _uploadError = 'No se pudieron procesar las imágenes. '
              'Asegúrate de encuadrar bien el rostro y tener buena iluminación.';
        });
      }
    } catch (e) {
      setState(() {
        _uploadError = 'Error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<List<double>> _generateFaceEmbedding(List<int> imageBytes) async {
    try {
      final repository = context.read<PersonsBloc>().repository;
      // Usar el servicio real de reconocimiento facial
      final embedding = await repository.generateFaceEmbedding(
        Uint8List.fromList(imageBytes),
      );
      // No guardar si el embedding no es válido
      if (embedding.isEmpty || embedding.length < 128) {
        throw Exception('No se detectó un rostro válido en la imagen');
      }
      return embedding;
    } catch (e) {
      debugPrint('Error generando embedding: $e');
      // Propagar para que el caller decida omitir/contar como fallo
      rethrow;
    }
  }

  void _clearForm() {
    _nameController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedImages.clear();
      _uploadError = null;
      _uploadSuccess = null;
      _createdPersonId = null;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400;
    final padding = isSmallScreen ? 12.0 : 20.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Nueva Persona'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_createdPersonId != null) {
              // Navegar con resultado
              Navigator.pop(context, {'personId': _createdPersonId});
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_selectedImages.isNotEmpty && !_isUploading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _savePerson,
              tooltip: 'Guardar persona',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Título
              const Text(
                'Registro de Nueva Persona',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isSmallScreen ? 4 : 5),
              const Text(
                'Añade múltiples imágenes para mejor reconocimiento',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: isSmallScreen ? 20 : 30),

              // Campo de nombre
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre completo *',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  if (value.trim().length < 2) {
                    return 'El nombre debe tener al menos 2 caracteres';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 15),

              // Campo de descripción
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Descripción (opcional)',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLines: 3,
                minLines: 2,
              ),

              SizedBox(height: isSmallScreen ? 20 : 25),

              // Título de imágenes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Imágenes del rostro',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_selectedImages.length}/10',
                    style: TextStyle(
                      color: _selectedImages.length >= 10
                          ? Colors.red
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              const Text(
                'Añade entre 3 y 10 imágenes con diferentes ángulos y expresiones',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 15),

              // Grid de imágenes
              if (_selectedImages.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isSmallScreen ? 3 : 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(_selectedImages[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
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
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
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

              const SizedBox(height: 15),

              // Botones para añadir imágenes
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Galería'),
                      onPressed:
                          _selectedImages.length >= 10 ? null : _pickImages,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[50],
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Cámara'),
                      onPressed:
                          _selectedImages.length >= 10 ? null : _takePhoto,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[50],
                        foregroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Mensajes de estado
              if (_uploadSuccess != null)
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _uploadSuccess!,
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_createdPersonId != null)
                              Text(
                                'ID: $_createdPersonId',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              if (_uploadError != null)
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _uploadError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_uploadError != null || _uploadSuccess != null)
                const SizedBox(height: 20),

              // Botón guardar
              ElevatedButton(
                onPressed: _isUploading ? null : _savePerson,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isUploading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('Guardando...'),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add),
                          SizedBox(width: 10),
                          Text(
                            'Guardar Persona',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 10),

              // Botón limpiar
              if (!_isUploading && _selectedImages.isNotEmpty)
                OutlinedButton(
                  onPressed: _clearForm,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Limpiar Formulario'),
                ),

              const SizedBox(height: 20),

              // Información
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Consejos para mejor reconocimiento:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Usa fotos frontales con buena iluminación\n'
                      '• Incluye diferentes expresiones (sonrisa, serio)\n'
                      '• Varía los ángulos (ligeramente de lado)\n'
                      '• Sin gafas de sol o sombreros\n'
                      '• 3-10 imágenes dan los mejores resultados',
                      style: TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
