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
  static const int DETECTOR_INPUT_SIZE = 416;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Inicializar FaceNet
      final faceNetOptions = InterpreterOptions()
        ..threads = 4
        ..useNnApiForAndroid = false;

      _faceNetInterpreter = await Interpreter.fromAsset(
        'assets/models/facenet_512.tflite',
        options: faceNetOptions,
      );

      // Inicializar detector YOLO
      final detectorOptions = InterpreterOptions()
        ..threads = 4
        ..useNnApiForAndroid = false;

      _faceDetectorInterpreter = await Interpreter.fromAsset(
        'assets/models/yolo_face_detector.tflite',
        options: detectorOptions,
      );

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
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Preprocesar imagen para el detector
      final input = _preprocessForDetector(image);

      // Ejecutar inferencia
      final output =
          List<double>.filled(1 * 10647 * 6, 0.0).reshape([1, 10647, 6]);

      _faceDetectorInterpreter!.run(input, output);

      // Convertir output a List<List<List<double>>>
      final List<List<List<double>>> typedOutput = [];
      for (int i = 0; i < output.shape[0]; i++) {
        final List<List<double>> innerList1 = [];
        for (int j = 0; j < output.shape[1]; j++) {
          final List<double> innerList2 = [];
          for (int k = 0; k < output.shape[2]; k++) {
            innerList2.add(output[i][j][k].toDouble());
          }
          innerList1.add(innerList2);
        }
        typedOutput.add(innerList1);
      }

      // Post-procesamiento para obtener bounding boxes
      final faces =
          _postprocessDetectorOutput(typedOutput, image.width, image.height);

      if (faces.isEmpty) return null;

      // Extraer y recortar rostros
      final faceImages = <Uint8List>[];
      for (final faceRect in faces) {
        final croppedFace = _cropFace(image, faceRect);
        if (croppedFace != null) {
          faceImages.add(Uint8List.fromList(img.encodeJpg(croppedFace)));
        }
      }

      return faceImages.isNotEmpty ? faceImages : null;
    } catch (e) {
      print('❌ Error detectando rostros: $e');
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

  static List<FaceRectangle> _postprocessDetectorOutput(
    List<List<List<double>>> output,
    int originalWidth,
    int originalHeight,
  ) {
    final faces = <FaceRectangle>[];
    const double confidenceThreshold = 0.5;

    // output[0] contiene las detecciones
    final detections = output[0];

    for (final detection in detections) {
      if (detection.length < 5) continue;

      final confidence = detection[4];

      if (confidence > confidenceThreshold) {
        final x = (detection[0] * originalWidth).toInt();
        final y = (detection[1] * originalHeight).toInt();
        final w = (detection[2] * originalWidth).toInt();
        final h = (detection[3] * originalHeight).toInt();

        // Ajustar bounding box
        final left = (x - w / 2).toInt();
        final top = (y - h / 2).toInt();
        final right = (x + w / 2).toInt();
        final bottom = (y + h / 2).toInt();

        // Asegurar que esté dentro de los límites
        final rectLeft = math.max(0, left);
        final rectTop = math.max(0, top);
        final rectWidth = math.min(originalWidth, right) - rectLeft;
        final rectHeight = math.min(originalHeight, bottom) - rectTop;

        if (rectWidth > 20 && rectHeight > 20) {
          faces.add(FaceRectangle(
            left: rectLeft,
            top: rectTop,
            width: rectWidth,
            height: rectHeight,
          ));
        }
      }
    }

    return faces;
  }

  static img.Image? _cropFace(img.Image image, FaceRectangle rect) {
    try {
      // Usar copyCrop con los parámetros correctos
      return img.copyCrop(
        image,
        x: rect.left,
        y: rect.top,
        width: rect.width,
        height: rect.height,
      );
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

  FaceRectangle({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  int get right => left + width;
  int get bottom => top + height;
}
