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
  Uint8List? _capturedImageBytes;
  Map<String, dynamic>? _recognizedPerson;
  double _recognitionConfidence = 0.0;
  Timer? _recognitionTimer;
  bool _showCapturePreview = false;
  int _currentCameraIndex = 0;
  bool _isSwitchingCamera = false;

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

      // Buscar cámara trasera primero
      _currentCameraIndex = _cameras!.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_currentCameraIndex == -1) _currentCameraIndex = 0;

      await _initializeCameraController(_currentCameraIndex);

      // Iniciar reconocimiento continuo cada 2 segundos
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

  Future<void> _initializeCameraController(int cameraIndex) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    _controller = CameraController(
      _cameras![cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();

    if (mounted) {
      setState(() {
        _isCameraInitialized = true;
        _isLoading = false;
        _isSwitchingCamera = false;
        _statusMessage = 'Cámara lista - Apunta a un rostro';
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    setState(() {
      _isSwitchingCamera = true;
      _isCameraInitialized = false;
    });

    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras!.length;
    await _initializeCameraController(_currentCameraIndex);
  }

  void _startContinuousRecognition() {
    _recognitionTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_isCameraInitialized &&
          !_isProcessing &&
          !_isRecognizing &&
          !_showCapturePreview &&
          !_isSwitchingCamera) {
        await _processFrame();
      }
    });
  }

  Future<void> _processFrame() async {
    if (!_isCameraInitialized ||
        _isProcessing ||
        _showCapturePreview ||
        _isSwitchingCamera) return;

    setState(() {
      _isRecognizing = true;
    });

    try {
      // Capturar frame de la cámara
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();

      // Reconocer persona usando el servicio real con umbral 0.7
      final recognition = await SupabaseService.recognizeFace(
        bytes,
        threshold: 0.7,
      );

      if (!mounted) return;

      if (recognition != null) {
        final confidence = recognition['similarity'] as double;
        setState(() {
          _recognizedPerson = recognition['person'];
          _recognitionConfidence = confidence;
          _statusMessage = '✅ ${_recognizedPerson!['name']} - '
              '${(_recognitionConfidence * 100).toStringAsFixed(1)}%';
        });
      } else {
        setState(() {
          _recognizedPerson = null;
          _statusMessage = '👤 Persona no reconocida';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recognizedPerson = null;
          _statusMessage = '🔍 Buscando rostro...';
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
      final bytes = await image.readAsBytes();

      setState(() {
        _capturedImage = image;
        _capturedImageBytes = bytes;
        _showCapturePreview = true;
        _statusMessage = 'Imagen capturada - Guardar o recapturar';
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error capturando: $e';
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

  void _showAddImageDialog(int personId) {
    if (_capturedImageBytes == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir Imagen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.memory(
              _capturedImageBytes!,
              height: 200,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 10),
            Text(
              '¿Añadir esta imagen a ${_recognizedPerson!['name']}?',
              textAlign: TextAlign.center,
            ),
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
              await _addImageToPerson(personId, _capturedImageBytes!);
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

      // Validar bytes
      if (imageBytes.isEmpty) {
        throw Exception('Imagen vacía, intenta capturar nuevamente');
      }

      // Generar embedding primero para validar rostro
      final embedding = await SupabaseService.generateFaceEmbedding(
        Uint8List.fromList(imageBytes),
      );

      // Validaciones de embedding
      if (embedding.isEmpty) {
        throw Exception('No se detectó rostro. Intenta acercarte y encuadrar.');
      }
      if (embedding.length < 128) {
        throw Exception('Embedding inválido. Vuelve a intentar con mejor luz.');
      }

      // Subir imagen a storage
      final fileName =
          'person_${personId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final imageUrl = await SupabaseService.uploadImage(
        Uint8List.fromList(imageBytes),
        fileName,
      );

      // Guardar en BD
      final ok = await SupabaseService.addFaceImage(
        personId: personId,
        imageUrl: imageUrl,
        embedding: embedding,
      );

      if (!ok) {
        throw Exception('No se pudo guardar en la base de datos');
      }

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
      // Mostrar error amigable
      if (mounted) {
        setState(() {
          _statusMessage = '❌ Error al generar embedding: $e';
        });
      }
      // Diálogo con recomendaciones
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No se pudo procesar el rostro'),
            content: const Text(
              'Consejos:\n\n• Asegúrate de que el rostro esté bien encuadrado dentro del recuadro.\n• Evita contraluces y mantén buena iluminación.\n• Mantén la cámara estable y más cerca del rostro.',
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
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _resetCamera() {
    setState(() {
      _capturedImage = null;
      _capturedImageBytes = null;
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
    if (_capturedImageBytes == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Image.memory(
      _capturedImageBytes!,
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
                        Flexible(
                          child: Text(
                            _statusMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                      // Botón para recapturar o cambiar cámara
                      if (_showCapturePreview)
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.5),
                          ),
                          child: IconButton(
                            onPressed: _resetCamera,
                            icon: const Icon(Icons.close,
                                color: Colors.white, size: 30),
                            tooltip: 'Cancelar',
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.5),
                          ),
                          child: IconButton(
                            onPressed: _cameras != null && _cameras!.length > 1
                                ? _switchCamera
                                : null,
                            icon: const Icon(Icons.flip_camera_android,
                                color: Colors.white, size: 30),
                            tooltip: 'Cambiar cámara',
                          ),
                        ),

                      // Botón capturar/guardar
                      GestureDetector(
                        onTap: _isProcessing || _isSwitchingCamera
                            ? null
                            : (_showCapturePreview
                                ? _saveToPerson
                                : _captureImage),
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
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.5),
                        ),
                        child: IconButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/persons');
                          },
                          icon: const Icon(Icons.people,
                              color: Colors.white, size: 30),
                          tooltip: 'Ver personas',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Indicador de procesamiento
                  if (_isProcessing || _isRecognizing || _isSwitchingCamera)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(
                            color: Colors.white,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _isSwitchingCamera
                                ? 'Cambiando cámara...'
                                : _isProcessing
                                    ? 'Procesando...'
                                    : 'Reconociendo...',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
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

          // Botón para volver (siempre visible)
          SafeArea(
            child: Positioned(
              top: 0,
              left: 0,
              child: Container(
                margin: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.5),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Volver',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
