import 'dart:typed_data';
import '../../domain/entities/person.dart';
import '../../domain/repositories/person_repository.dart';
import '../datasources/supabase_remote_datasource.dart';
import '../datasources/tflite_local_datasource.dart';

class PersonRepositoryImpl implements PersonRepository {
  final SupabaseRemoteDataSource remoteDataSource;
  final TFliteLocalDataSource localDataSource;

  PersonRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<List<Person>> getPersons() async {
    return await remoteDataSource.getPersons();
  }

  @override
  Stream<List<Person>> getPersonsStream() {
    return remoteDataSource.getPersonsStream();
  }

  @override
  Future<int> addPerson({required String name, String description = ''}) async {
    return await remoteDataSource.addPerson(
        name: name, description: description);
  }

  @override
  Future<bool> updatePerson({
    required int id,
    String? name,
    String? description,
  }) async {
    return await remoteDataSource.updatePerson(
      id: id,
      name: name,
      description: description,
    );
  }

  @override
  Future<bool> deletePerson(int id) async {
    return await remoteDataSource.deletePerson(id);
  }

  @override
  Future<String> uploadImage(Uint8List imageBytes, String fileName) async {
    return await remoteDataSource.uploadImage(imageBytes, fileName);
  }

  @override
  Future<bool> addFaceImage({
    required int personId,
    required String imageUrl,
    required List<double> embedding,
    double confidence = 0.95,
  }) async {
    return await remoteDataSource.addFaceImage(
      personId: personId,
      imageUrl: imageUrl,
      embedding: embedding,
      confidence: confidence,
    );
  }

  @override
  Future<bool> deleteFaceImage(int imageId) async {
    return await remoteDataSource.deleteFaceImage(imageId);
  }

  @override
  Future<List<double>> generateFaceEmbedding(Uint8List imageBytes) async {
    try {
      final faces = await localDataSource.detectFaces(imageBytes);
      if (faces == null || faces.isEmpty) {
        throw Exception('No se detectaron rostros en la imagen');
      }

      final embedding = await localDataSource.getFaceEmbedding(faces.first);
      return embedding;
    } catch (e) {
      rethrow;
    }
  }
}
