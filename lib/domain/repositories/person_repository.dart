import 'dart:typed_data';
import '../entities/person.dart';

abstract class PersonRepository {
  Future<List<Person>> getPersons();
  Stream<List<Person>> getPersonsStream();
  Future<int> addPerson({required String name, String description});
  Future<bool> updatePerson(
      {required int id, String? name, String? description});
  Future<bool> deletePerson(int id);
  Future<String> uploadImage(Uint8List imageBytes, String fileName);
  Future<bool> addFaceImage({
    required int personId,
    required String imageUrl,
    required List<double> embedding,
    double confidence,
  });
  Future<bool> deleteFaceImage(int imageId);
  Future<List<double>> generateFaceEmbedding(Uint8List imageBytes);
}
