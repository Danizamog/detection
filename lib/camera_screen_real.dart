import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'supabase_service.dart';

class CameraScreenReal extends StatefulWidget {
  const CameraScreenReal({super.key});

  @override
  State<CameraScreenReal> createState() => _CameraScreenRealState();
}

class _CameraScreenRealState extends State<CameraScreenReal> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isRecognizing = false;
  String _statusMessage = 'Inicializando cámara...';
  XFile? _capturedImage;
  Map<String, dynamic>? _recognizedPerson;
  double _recognitionConfidence = 0.0;
  Timer? _recognitionTimer;
  bool _showCapturePreview = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _recognitionTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      await _requestPermissions();

      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _statusMessage = 'No se encontraron cámaras';
          _isLoading = false;
        });
        return;
      }

      final camera = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();

      setState(() {
        _isCameraInitialized = true;
        _isLoading = false;
        _statusMessage = 'Cámara lista - Apunta a un rostro';
      });

      // Iniciar reconocimiento continuo cada 3 segundos
      _startContinuousRecognition();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error inicializando cámara: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final storageStatus = await Permission.storage.status;

    if (!cameraStatus.isGranted) {
      await Permission.camera.request();
    }

    if (!storageStatus.isGranted) {
      await Permission.storage.request();
    }
  }

  void _startContinuousRecognition() {
    _recognitionTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_isCameraInitialized &&
          !_isProcessing &&
          !_isRecognizing &&
          !_showCapturePreview) {
        await _processFrame();
      }
    });
  }

  Future<void> _processFrame() async {
    if (!_isCameraInitialized || _isProcessing || _showCapturePreview) return;

    setState(() {
      _isRecognizing = true;
    });

    try {
      // Capturar frame de la cámara
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();

      // Reconocer persona usando el servicio real
      final recognition = await SupabaseService.recognizeFace(bytes);

      if (recognition != null && mounted) {
        setState(() {
          _recognizedPerson = recognition['person'];
          _recognitionConfidence = recognition['similarity'];
          _statusMessage = '✅ ${_recognizedPerson!['name']} - '
              '${(_recognitionConfidence * 100).toStringAsFixed(1)}%';
        });
      } else if (mounted) {
        setState(() {
          _recognizedPerson = null;
          _statusMessage = '👤 Persona no reconocida';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error procesando: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecognizing = false;
        });
      }
    }
  }

  Future<void> _captureImage() async {
    if (!_isCameraInitialized || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Capturando imagen...';
    });

    try {
      final image = await _controller!.takePicture();

      setState(() {
        _capturedImage = image;
        _showCapturePreview = true;
        _statusMessage = 'Imagen capturada';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error capturando: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveToPerson() async {
    if (_capturedImage == null) return;

    if (_recognizedPerson != null) {
      // Añadir imagen a persona existente
      _showAddImageDialog(_recognizedPerson!['id']);
    } else {
      // Crear nueva persona
      _showNewPersonDialog();
    }
  }

  void _showAddImageDialog(int personId) async {
    final bytes = await _capturedImage!.readAsBytes();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir Imagen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.memory(
              bytes,
              height: 200,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 10),
            const Text('¿Añadir esta imagen a la persona existente?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _addImageToPerson(personId, bytes);
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  void _showNewPersonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva Persona'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Esta persona no está registrada. ¿Deseas crear un nuevo perfil?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/add-person',
                arguments: {'imagePath': _capturedImage!.path},
              );
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  Future<void> _addImageToPerson(int personId, List<int> imageBytes) async {
    try {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Guardando imagen...';
      });

      // Subir imagen
      final fileName =
          'person_${personId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final imageUrl = await SupabaseService.uploadImage(
        Uint8List.fromList(imageBytes),
        fileName,
      );

      // Generar embedding usando el servicio real
      final embedding = await SupabaseService.generateFaceEmbedding(
        Uint8List.fromList(imageBytes),
      );

      // Añadir a la persona
      await SupabaseService.addFaceImage(
        personId: personId,
        imageUrl: imageUrl,
        embedding: embedding,
      );

      setState(() {
        _statusMessage = '✅ Imagen añadida exitosamente';
      });

      // Resetear después de 2 segundos
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _resetCamera();
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _resetCamera() {
    setState(() {
      _capturedImage = null;
      _recognizedPerson = null;
      _recognitionConfidence = 0.0;
      _showCapturePreview = false;
      _statusMessage = 'Cámara lista - Apunta a un rostro';
    });
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(_statusMessage),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_controller!),

        // Overlay de reconocimiento
        if (_recognizedPerson != null)
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.face, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _recognizedPerson!['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Confianza: ${(_recognitionConfidence * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 14,
                          ),
                        ),
                        if (_recognizedPerson!['description'] != null &&
                            _recognizedPerson!['description'].isNotEmpty)
                          Text(
                            _recognizedPerson!['description'],
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Rectángulo de enfoque
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(
                color: _recognizedPerson != null ? Colors.green : Colors.white,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCapturedImage() {
    if (_capturedImage == null) return Container();

    return Image.file(
      File(_capturedImage!.path),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Vista de cámara o imagen capturada
          _showCapturePreview ? _buildCapturedImage() : _buildCameraPreview(),

          // Controles
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Barra de estado
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          color: _isRecognizing
                              ? Colors.orange
                              : _recognizedPerson != null
                                  ? Colors.green
                                  : Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Botones principales
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Botón para recapturar
                      if (_showCapturePreview)
                        IconButton(
                          onPressed: _resetCamera,
                          icon: const Icon(Icons.refresh,
                              color: Colors.white, size: 30),
                          tooltip: 'Nueva foto',
                        ),

                      // Botón capturar/guardar
                      GestureDetector(
                        onTap:
                            _showCapturePreview ? _saveToPerson : _captureImage,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _showCapturePreview
                                  ? Colors.green
                                  : Colors.white,
                              width: 3,
                            ),
                            color: Colors.transparent,
                          ),
                          child: Center(
                            child: Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _showCapturePreview
                                    ? Colors.green
                                    : Colors.white,
                              ),
                              child: Icon(
                                _showCapturePreview ? Icons.save : Icons.camera,
                                color: Colors.black,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Botón para ver personas
                      IconButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/persons');
                        },
                        icon: const Icon(Icons.people,
                            color: Colors.white, size: 30),
                        tooltip: 'Ver personas',
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Indicador de procesamiento
                  if (_isProcessing || _isRecognizing)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Indicador de carga inicial
          if (_isLoading)
            Container(
              color: Colors.black,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      'Inicializando cámara...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

          // Botón para volver
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: IconButton(
                icon:
                    const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
