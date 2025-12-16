import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math' as math;

class TFliteLocalDataSource {
  Interpreter? _faceNetInterpreter;
  Interpreter? _faceDetectorInterpreter;
  bool _initialized = false;

  static const int FACE_NET_INPUT_SIZE = 160;
  static const int EMBEDDING_SIZE = 512;
  static const int DETECTOR_INPUT_SIZE = 128;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final faceNetOptions = InterpreterOptions()
        ..threads = 2
        ..useNnApiForAndroid = true;

      _faceNetInterpreter = await Interpreter.fromAsset(
        'assets/models/facenet_512.tflite',
        options: faceNetOptions,
      );

      final detectorOptions = InterpreterOptions()
        ..threads = 2
        ..useNnApiForAndroid = true;

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

  Future<List<Uint8List>?> detectFaces(Uint8List imageBytes) async {
    if (!_initialized || _faceDetectorInterpreter == null) {
      await initialize();
    }

    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      final input = _preprocessForDetector(image);

      final outputBoxes =
          List<double>.filled(1 * 896 * 16, 0.0).reshape([1, 896, 16]);
      final outputScores =
          List<double>.filled(1 * 896 * 1, 0.0).reshape([1, 896, 1]);

      _faceDetectorInterpreter!.runForMultipleInputs([
        input
      ], {
        0: outputBoxes,
        1: outputScores,
      });

      final rawFaces = _postprocessYoloOutput(
          outputBoxes, outputScores, image.width, image.height);

      if (rawFaces.isEmpty) return null;

      final faces = _nonMaxSuppression(rawFaces, 0.4)
        ..sort((a, b) => b.confidence.compareTo(a.confidence));

      final List<Uint8List> faceImages = [];
      for (int i = 0; i < faces.length; i++) {
        final faceRect = _adjustRectIfInvalid(image, faces[i]);
        final croppedFace = _cropFace(image, faceRect, expandRatio: 0.2);
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

  Future<List<double>> getFaceEmbedding(Uint8List faceImageBytes) async {
    if (!_initialized || _faceNetInterpreter == null) {
      await initialize();
    }

    try {
      final image = img.decodeImage(faceImageBytes);
      if (image == null) return List<double>.filled(EMBEDDING_SIZE, 0.0);

      final input = _preprocessForFaceNet(image);
      final output = List<double>.filled(1 * EMBEDDING_SIZE, 0.0)
          .reshape([1, EMBEDDING_SIZE]);

      _faceNetInterpreter!.run(input, output);

      final embedding = List<double>.from(output[0]);
      return _normalizeEmbedding(embedding);
    } catch (e) {
      print('❌ Error obteniendo embedding: $e');
      return List<double>.filled(EMBEDDING_SIZE, 0.0);
    }
  }

  double calculateSimilarity(List<double> emb1, List<double> emb2) {
    if (emb1.length != emb2.length || emb1.isEmpty) return 0.0;

    double similarity = 0.0;
    for (int i = 0; i < emb1.length; i++) {
      similarity += emb1[i] * emb2[i];
    }

    return similarity;
  }

  List<double> _normalizeEmbedding(List<double> embedding) {
    double norm = 0.0;
    for (final value in embedding) {
      norm += value * value;
    }
    norm = math.sqrt(norm);

    if (norm > 0) {
      return embedding.map((value) => value / norm).toList();
    }

    return embedding;
  }

  List<List<List<List<double>>>> _preprocessForFaceNet(img.Image image) {
    final resized = img.copyResize(
      image,
      width: FACE_NET_INPUT_SIZE,
      height: FACE_NET_INPUT_SIZE,
    );

    final input = List.generate(
        1,
        (_) => List.generate(
            FACE_NET_INPUT_SIZE,
            (_) => List.generate(
                FACE_NET_INPUT_SIZE, (_) => List<double>.filled(3, 0.0))));

    for (int y = 0; y < FACE_NET_INPUT_SIZE; y++) {
      for (int x = 0; x < FACE_NET_INPUT_SIZE; x++) {
        final pixel = resized.getPixelSafe(x, y);
        input[0][y][x][0] = pixel.r.toDouble() / 127.5 - 1;
        input[0][y][x][1] = pixel.g.toDouble() / 127.5 - 1;
        input[0][y][x][2] = pixel.b.toDouble() / 127.5 - 1;
      }
    }

    return input;
  }

  List<List<List<List<double>>>> _preprocessForDetector(img.Image image) {
    final resized = img.copyResize(
      image,
      width: DETECTOR_INPUT_SIZE,
      height: DETECTOR_INPUT_SIZE,
    );

    final input = List.generate(
        1,
        (_) => List.generate(
            DETECTOR_INPUT_SIZE,
            (_) => List.generate(
                DETECTOR_INPUT_SIZE, (_) => List<double>.filled(3, 0.0))));

    for (int y = 0; y < DETECTOR_INPUT_SIZE; y++) {
      for (int x = 0; x < DETECTOR_INPUT_SIZE; x++) {
        final pixel = resized.getPixelSafe(x, y);
        input[0][y][x][0] = pixel.r.toDouble() / 255.0;
        input[0][y][x][1] = pixel.g.toDouble() / 255.0;
        input[0][y][x][2] = pixel.b.toDouble() / 255.0;
      }
    }

    return input;
  }

  List<FaceRectangle> _postprocessYoloOutput(
    List outputBoxes,
    List outputScores,
    int originalWidth,
    int originalHeight,
  ) {
    final faces = <FaceRectangle>[];
    const double confidenceThreshold = 0.3;

    try {
      final boxes = outputBoxes[0];
      final scores = outputScores[0];

      for (int i = 0; i < 896; i++) {
        final double confidence = scores[i][0];
        if (confidence < confidenceThreshold) continue;

        final box = boxes[i];
        final double xCenter = box[0];
        final double yCenter = box[1];
        final double width = box[2];
        final double height = box[3];

        final bool alreadyNormalized = xCenter.abs() <= 1.2 &&
            yCenter.abs() <= 1.2 &&
            width <= 1.2 &&
            height <= 1.2;

        double left, top, right, bottom;

        if (alreadyNormalized) {
          left = (xCenter - width / 2) * originalWidth;
          top = (yCenter - height / 2) * originalHeight;
          right = (xCenter + width / 2) * originalWidth;
          bottom = (yCenter + height / 2) * originalHeight;
        } else {
          final double xCenterNorm = xCenter / DETECTOR_INPUT_SIZE;
          final double yCenterNorm = yCenter / DETECTOR_INPUT_SIZE;
          final double widthNorm = width / DETECTOR_INPUT_SIZE;
          final double heightNorm = height / DETECTOR_INPUT_SIZE;

          left = (xCenterNorm - widthNorm / 2) * originalWidth;
          top = (yCenterNorm - heightNorm / 2) * originalHeight;
          right = (xCenterNorm + widthNorm / 2) * originalWidth;
          bottom = (yCenterNorm + heightNorm / 2) * originalHeight;
        }

        final int clampedLeft = left.clamp(0, originalWidth).toInt();
        final int clampedTop = top.clamp(0, originalHeight).toInt();
        final int clampedRight = right.clamp(0, originalWidth).toInt();
        final int clampedBottom = bottom.clamp(0, originalHeight).toInt();

        final int rectWidth = clampedRight - clampedLeft;
        final int rectHeight = clampedBottom - clampedTop;

        if (rectWidth < 10 || rectHeight < 10) continue;

        final double aspectRatio = rectWidth / rectHeight;
        if (aspectRatio < 0.25 || aspectRatio > 3.5) continue;

        faces.add(FaceRectangle(
          left: clampedLeft,
          top: clampedTop,
          width: rectWidth,
          height: rectHeight,
          confidence: confidence,
        ));
      }

      return faces;
    } catch (e) {
      print('❌ Error en post-procesamiento: $e');
      return faces;
    }
  }

  List<FaceRectangle> _nonMaxSuppression(
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

  FaceRectangle _adjustRectIfInvalid(img.Image image, FaceRectangle rect) {
    final int minValidW = (image.width * 0.1).toInt();
    final int minValidH = (image.height * 0.1).toInt();
    final bool isCorner = rect.left == 0 && rect.top == 0;
    final bool tooSmall = rect.width < minValidW || rect.height < minValidH;

    if (!isCorner && !tooSmall) return rect;

    final int targetSize = (math.min(image.width, image.height) * 0.6).toInt();
    final int cx = image.width ~/ 2;
    final int cy = image.height ~/ 2;

    final int left = math.max(0, cx - targetSize ~/ 2);
    final int top = math.max(0, cy - targetSize ~/ 2);
    final int right = math.min(image.width, left + targetSize);
    final int bottom = math.min(image.height, top + targetSize);

    return FaceRectangle(
      left: left,
      top: top,
      width: math.max(1, right - left),
      height: math.max(1, bottom - top),
      confidence: rect.confidence,
    );
  }

  double _iou(FaceRectangle a, FaceRectangle b) {
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

  img.Image? _cropFace(img.Image image, FaceRectangle rect,
      {double expandRatio = 0.0}) {
    try {
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

  void dispose() {
    _faceNetInterpreter?.close();
    _faceDetectorInterpreter?.close();
    _initialized = false;
  }
}

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
