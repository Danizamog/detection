import 'dart:typed_data';
import '../../domain/entities/recognition_result.dart';
import '../../domain/repositories/face_recognition_repository.dart';
import '../datasources/tflite_local_datasource.dart';
import '../datasources/supabase_remote_datasource.dart';

class FaceRecognitionRepositoryImpl implements FaceRecognitionRepository {
  final TFliteLocalDataSource localDataSource;
  final SupabaseRemoteDataSource remoteDataSource;

  FaceRecognitionRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<void> initialize() async {
    await localDataSource.initialize();
  }

  @override
  Future<List<Uint8List>?> detectFaces(Uint8List imageBytes) async {
    return await localDataSource.detectFaces(imageBytes);
  }

  @override
  Future<List<double>> getFaceEmbedding(Uint8List faceImageBytes) async {
    return await localDataSource.getFaceEmbedding(faceImageBytes);
  }

  @override
  double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    return localDataSource.calculateSimilarity(embedding1, embedding2);
  }

  @override
  Future<RecognitionResult?> recognizeFace(
    Uint8List imageBytes, {
    double threshold = 0.65,
  }) async {
    try {
      final faces = await detectFaces(imageBytes);
      if (faces == null || faces.isEmpty) {
        return null;
      }

      final faceImage = faces.first;
      final embedding = await getFaceEmbedding(faceImage);

      final persons = await remoteDataSource.getPersons();
      if (persons.isEmpty) {
        return null;
      }

      double bestSimilarity = 0.0;
      RecognitionResult? bestResult;

      for (final person in persons) {
        if (person.averageEmbedding.isEmpty) continue;

        final similarity =
            calculateSimilarity(embedding, person.averageEmbedding);

        if (similarity > bestSimilarity && similarity >= threshold) {
          bestSimilarity = similarity;
          bestResult = RecognitionResult(
            personId: person.id,
            personName: person.name,
            personDescription: person.description,
            similarity: similarity,
            faceImage: faceImage,
          );
        }
      }

      return bestResult;
    } catch (e) {
      return null;
    }
  }
}
