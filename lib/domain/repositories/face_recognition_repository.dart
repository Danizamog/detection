import 'dart:typed_data';
import '../entities/recognition_result.dart';

abstract class FaceRecognitionRepository {
  Future<void> initialize();
  Future<List<Uint8List>?> detectFaces(Uint8List imageBytes);
  Future<List<double>> getFaceEmbedding(Uint8List faceImageBytes);
  double calculateSimilarity(List<double> embedding1, List<double> embedding2);
  Future<RecognitionResult?> recognizeFace(
    Uint8List imageBytes, {
    double threshold,
  });
}
