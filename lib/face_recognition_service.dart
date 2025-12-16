import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math' as math;

class FaceRecognitionService {
  static Interpreter? _faceNetInterpreter;
  static Interpreter? _faceDetectorInterpreter;
  static bool _initialized = false;

  // Dimensiones del modelo FaceNet
  static const int FACE_NET_INPUT_SIZE = 160;
  static const int EMBEDDING_SIZE = 512;

  // Dimensiones del modelo de detección
  static const int DETECTOR_INPUT_SIZE = 128;

  static Future<void> initialize() async {
  if (_initialized) return;

  try {
    // Inicializar FaceNet
    final faceNetOptions = InterpreterOptions()
      ..threads = 2
      ..useNnApiForAndroid = true;

    _faceNetInterpreter = await Interpreter.fromAsset(
      'assets/models/facenet_512.tflite',
      options: faceNetOptions,
    );

    // Inicializar detector YOLO
    final detectorOptions = InterpreterOptions()
      ..threads = 2
      ..useNnApiForAndroid = true;

    _faceDetectorInterpreter = await Interpreter.fromAsset(
      'assets/models/yolo_face_detector.tflite',
      options: detectorOptions,
    );

    // 🔍 DEBUGGING - Ver dimensiones reales del modelo
    print('==========================================');
    print('🔍 ANALIZANDO MODELO YOLO:');
    print('==========================================');
    
    final inputTensors = _faceDetectorInterpreter!.getInputTensors();
    final outputTensors = _faceDetectorInterpreter!.getOutputTensors();
    
    print('\n📥 INPUT TENSORS (${inputTensors.length}):');
    for (int i = 0; i < inputTensors.length; i++) {
      final tensor = inputTensors[i];
      print('  Input $i:');
      print('    - Shape: ${tensor.shape}');
      print('    - Type: ${tensor.type}');
      print('    - Name: ${tensor.name}');
    }
    
    print('\n📤 OUTPUT TENSORS (${outputTensors.length}):');
    for (int i = 0; i < outputTensors.length; i++) {
      final tensor = outputTensors[i];
      print('  Output $i:');
      print('    - Shape: ${tensor.shape}');
      print('    - Type: ${tensor.type}');
      print('    - Name: ${tensor.name}');
    }
    
    print('\n==========================================');

    _initialized = true;
    print('✅ Modelos de IA cargados correctamente');
  } catch (e) {
    print('❌ Error cargando modelos de IA: $e');
    rethrow;
  }
}



  static Future<List<Uint8List>?> detectFaces(Uint8List imageBytes) async {
  if (!_initialized || _faceDetectorInterpreter == null) {
    await initialize();
  }

  try {
    print('📸 Decodificando imagen...');
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      print('❌ No se pudo decodificar la imagen');
      return null;
    }

    print('✅ Imagen: ${image.width}x${image.height}');

    // Preprocesar imagen para el detector (128x128)
    print('🔄 Preprocesando...');
    final input = _preprocessForDetector(image);

    // Crear outputs según las dimensiones reales del modelo
    // Output 0: [1, 896, 16] - bounding boxes
    // Output 1: [1, 896, 1] - scores
    final outputBoxes = List<double>.filled(1 * 896 * 16, 0.0)
        .reshape([1, 896, 16]);
    
    final outputScores = List<double>.filled(1 * 896 * 1, 0.0)
        .reshape([1, 896, 1]);

    print('🤖 Ejecutando modelo YOLO...');
    
    // El modelo tiene 2 outputs, así que usamos runForMultipleInputs
    _faceDetectorInterpreter!.runForMultipleInputs(
      [input],
      {
        0: outputBoxes,  // regressors
        1: outputScores, // classificators
      }
    );
    
    print('✅ Modelo ejecutado');

    // Post-procesamiento
    print('🔍 Post-procesando detecciones...');
    final rawFaces = _postprocessYoloOutput(
      outputBoxes, 
      outputScores,
      image.width, 
      image.height
    );

    if (rawFaces.isEmpty) {
      print('! No se detectaron rostros en la imagen');
      return null;
    }

    print('😊 Detectados ${rawFaces.length} rostros');

    // Aplicar NMS y ordenar por confianza
    final faces = _nonMaxSuppression(rawFaces, 0.4)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    print('✅ ${faces.length} rostros después de NMS');

    // Extraer y recortar rostros con margen
    final List<Uint8List> faceImages = [];
    for (int i = 0; i < faces.length; i++) {
      final faceRect = faces[i];
      print('✂️ Recortando rostro ${i + 1}: '
          'left=${faceRect.left}, top=${faceRect.top}, '
          'width=${faceRect.width}, height=${faceRect.height}, '
          'confidence=${faceRect.confidence.toStringAsFixed(2)}');
      
      final croppedFace = _cropFace(image, faceRect, expandRatio: 0.2);
      if (croppedFace != null) {
        faceImages.add(Uint8List.fromList(img.encodeJpg(croppedFace)));
      }
    }

    print('✅ Extraídos ${faceImages.length} rostros');
    return faceImages.isNotEmpty ? faceImages : null;
  } catch (e, stackTrace) {
    print('❌ Error detectando rostros: $e');
    print('📍 Stack trace: $stackTrace');
    return null;
  }
}


  static Future<List<double>> getFaceEmbedding(Uint8List faceImageBytes) async {
    if (!_initialized || _faceNetInterpreter == null) {
      await initialize();
    }

    try {
      final image = img.decodeImage(faceImageBytes);
      if (image == null) return List<double>.filled(EMBEDDING_SIZE, 0.0);

      // Preprocesar para FaceNet
      final input = _preprocessForFaceNet(image);

      // Ejecutar inferencia
      final output = List<double>.filled(1 * EMBEDDING_SIZE, 0.0)
          .reshape([1, EMBEDDING_SIZE]);

      _faceNetInterpreter!.run(input, output);

      // Normalizar el embedding
      final embedding = List<double>.from(output[0]);
      return _normalizeEmbedding(embedding);
    } catch (e) {
      print('❌ Error obteniendo embedding: $e');
      return List<double>.filled(EMBEDDING_SIZE, 0.0);
    }
  }

  static List<double> _normalizeEmbedding(List<double> embedding) {
    // Calcular norma L2
    double norm = 0.0;
    for (final value in embedding) {
      norm += value * value;
    }
    norm = math.sqrt(norm);

    // Normalizar dividiendo por la norma
    if (norm > 0) {
      return embedding.map((value) => value / norm).toList();
    }

    return embedding;
  }

  static List<List<List<List<double>>>> _preprocessForFaceNet(img.Image image) {
    // Redimensionar a 160x160
    final resized = img.copyResize(
      image,
      width: FACE_NET_INPUT_SIZE,
      height: FACE_NET_INPUT_SIZE,
    );

    // Crear tensor 4D: [1, height, width, 3]
    final input = List.generate(
        1,
        (_) => List.generate(
            FACE_NET_INPUT_SIZE,
            (_) => List.generate(
                FACE_NET_INPUT_SIZE, (_) => List<double>.filled(3, 0.0))));

    for (int y = 0; y < FACE_NET_INPUT_SIZE; y++) {
      for (int x = 0; x < FACE_NET_INPUT_SIZE; x++) {
        final pixel = resized.getPixelSafe(x, y);
        input[0][y][x][0] = pixel.r.toDouble() / 127.5 - 1; // R
        input[0][y][x][1] = pixel.g.toDouble() / 127.5 - 1; // G
        input[0][y][x][2] = pixel.b.toDouble() / 127.5 - 1; // B
      }
    }

    return input;
  }

  static List<List<List<List<double>>>> _preprocessForDetector(
      img.Image image) {
    final resized = img.copyResize(
      image,
      width: DETECTOR_INPUT_SIZE,
      height: DETECTOR_INPUT_SIZE,
    );

    // Crear tensor 4D: [1, height, width, 3]
    final input = List.generate(
        1,
        (_) => List.generate(
            DETECTOR_INPUT_SIZE,
            (_) => List.generate(
                DETECTOR_INPUT_SIZE, (_) => List<double>.filled(3, 0.0))));

    for (int y = 0; y < DETECTOR_INPUT_SIZE; y++) {
      for (int x = 0; x < DETECTOR_INPUT_SIZE; x++) {
        final pixel = resized.getPixelSafe(x, y);
        input[0][y][x][0] = pixel.r.toDouble() / 255.0; // R
        input[0][y][x][1] = pixel.g.toDouble() / 255.0; // G
        input[0][y][x][2] = pixel.b.toDouble() / 255.0; // B
      }
    }

    return input;
  }

  static List<FaceRectangle> _postprocessYoloOutput(
  List outputBoxes,
  List outputScores,
  int originalWidth,
  int originalHeight,
) {
  final faces = <FaceRectangle>[];
  const double confidenceThreshold = 0.5;

  try {
    final boxes = outputBoxes[0];
    final scores = outputScores[0];
    
    print('📊 Procesando 896 detecciones');

    for (int i = 0; i < 896; i++) {
  final double confidence = scores[i][0];
  
  // 🔥 DEBUG: Imprimir TODO lo que tenga confidence > 0.4
  if (confidence > 0.4) {
    final box = boxes[i];
    print('🔬 Det $i (conf=${confidence.toStringAsFixed(2)}): xC=${box[0].toStringAsFixed(2)}, yC=${box[1].toStringAsFixed(2)}, w=${box[2].toStringAsFixed(2)}, h=${box[3].toStringAsFixed(2)}');
  }
  
  if (confidence < confidenceThreshold) continue;

  final box = boxes[i];
  
  // ⚠️ TU MODELO DEVUELVE COORDENADAS ABSOLUTAS EN 128x128, NO NORMALIZADAS
  final double xCenter = box[0];
  final double yCenter = box[1];
  final double width = box[2];
  final double height = box[3];

  // 🔥 PRIMERO: Normalizar a [0-1]
  final double xCenterNorm = xCenter / DETECTOR_INPUT_SIZE;
  final double yCenterNorm = yCenter / DETECTOR_INPUT_SIZE;
  final double widthNorm = width / DETECTOR_INPUT_SIZE;
  final double heightNorm = height / DETECTOR_INPUT_SIZE;

  // 🔥 SEGUNDO: Escalar a la imagen original
  final double left = (xCenterNorm - widthNorm / 2) * originalWidth;
  final double top = (yCenterNorm - heightNorm / 2) * originalHeight;
  final double right = (xCenterNorm + widthNorm / 2) * originalWidth;
  final double bottom = (yCenterNorm + heightNorm / 2) * originalHeight;

  final int clampedLeft = left.clamp(0, originalWidth).toInt();
  final int clampedTop = top.clamp(0, originalHeight).toInt();
  final int clampedRight = right.clamp(0, originalWidth).toInt();
  final int clampedBottom = bottom.clamp(0, originalHeight).toInt();

  final int rectWidth = clampedRight - clampedLeft;
  final int rectHeight = clampedBottom - clampedTop;

  if (rectWidth < 20 || rectHeight < 20) continue;
  
  final double aspectRatio = rectWidth / rectHeight;
  if (aspectRatio < 0.3 || aspectRatio > 3.0) continue;

  faces.add(FaceRectangle(
    left: clampedLeft,
    top: clampedTop,
    width: rectWidth,
    height: rectHeight,
    confidence: confidence,
  ));
}

    print('✅ Encontrados ${faces.length} rostros válidos');
    return faces;
  } catch (e) {
    print('❌ Error en post-procesamiento: $e');
    return faces;
  }
}

  static List<FaceRectangle> _nonMaxSuppression(
    List<FaceRectangle> boxes,
    double iouThreshold,
  ) {
    final sorted = [...boxes]
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final selected = <FaceRectangle>[];

    while (sorted.isNotEmpty) {
      final current = sorted.removeAt(0);
      selected.add(current);

      sorted.removeWhere((b) => _iou(current, b) > iouThreshold);
    }

    return selected;
  }

  static double _iou(FaceRectangle a, FaceRectangle b) {
    final x1 = math.max(a.left, b.left);
    final y1 = math.max(a.top, b.top);
    final x2 = math.min(a.right, b.right);
    final y2 = math.min(a.bottom, b.bottom);

    final interW = math.max(0, x2 - x1);
    final interH = math.max(0, y2 - y1);
    final interArea = interW * interH;

    final areaA = a.width * a.height;
    final areaB = b.width * b.height;
    final union = areaA + areaB - interArea;
    if (union == 0) return 0.0;
    return interArea / union;
  }

  static img.Image? _cropFace(img.Image image, FaceRectangle rect,
      {double expandRatio = 0.0}) {
    try {
      // Expandir el recorte para incluir contexto alrededor del rostro
      int cx = rect.left + rect.width ~/ 2;
      int cy = rect.top + rect.height ~/ 2;
      int newW = (rect.width * (1 + expandRatio)).toInt();
      int newH = (rect.height * (1 + expandRatio)).toInt();

      int left = math.max(0, cx - newW ~/ 2);
      int top = math.max(0, cy - newH ~/ 2);
      int right = math.min(image.width, left + newW);
      int bottom = math.min(image.height, top + newH);

      final width = math.max(1, right - left);
      final height = math.max(1, bottom - top);

      return img.copyCrop(image, x: left, y: top, width: width, height: height);
    } catch (e) {
      print('Error recortando rostro: $e');
      return null;
    }
  }

  static double calculateSimilarity(List<double> emb1, List<double> emb2) {
    if (emb1.length != emb2.length || emb1.isEmpty) return 0.0;

    double similarity = 0.0;
    for (int i = 0; i < emb1.length; i++) {
      similarity += emb1[i] * emb2[i];
    }

    // El coseno similarity ya está normalizado porque los embeddings están normalizados
    return similarity;
  }

  static void dispose() {
    _faceNetInterpreter?.close();
    _faceDetectorInterpreter?.close();
    _initialized = false;
  }
}

// Clase auxiliar para representar un rectángulo facial
class FaceRectangle {
  final int left;
  final int top;
  final int width;
  final int height;
  final double confidence;

  FaceRectangle({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.confidence,
  });

  int get right => left + width;
  int get bottom => top + height;
}
