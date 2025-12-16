import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/person_model.dart';

class SupabaseRemoteDataSource {
  final SupabaseClient client;

  SupabaseRemoteDataSource(this.client);

  Future<List<PersonModel>> getPersons() async {
    try {
      final response = await client.from('persons').select('''
        *,
        face_images:face_images_person_id_fkey (*)
      ''').order('created_at', ascending: false);

      if (response.isEmpty) return [];

      return List<Map<String, dynamic>>.from(response)
          .map((json) => PersonModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ Error obteniendo personas: $e');
      return [];
    }
  }

  Stream<List<PersonModel>> getPersonsStream() {
    return client
        .from('persons')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap((data) async {
          if (data.isEmpty) return [];

          final personsWithImages = await Future.wait(
            data.map((person) async {
              final imagesResponse = await client
                  .from('face_images')
                  .select('*')
                  .eq('person_id', person['id']);

              final personWithImages = Map<String, dynamic>.from(person);
              personWithImages['face_images'] = imagesResponse;

              return PersonModel.fromJson(personWithImages);
            }),
          );

          return personsWithImages;
        });
  }

  Future<int> addPerson({
    required String name,
    String description = '',
  }) async {
    try {
      final response = await client
          .from('persons')
          .insert({
            'name': name,
            'description': description,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      return response['id'] as int;
    } catch (e) {
      debugPrint('❌ Error añadiendo persona: $e');
      rethrow;
    }
  }

  Future<bool> updatePerson({
    required int id,
    String? name,
    String? description,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      updates['updated_at'] = DateTime.now().toIso8601String();

      await client.from('persons').update(updates).eq('id', id);

      return true;
    } catch (e) {
      debugPrint('❌ Error actualizando persona: $e');
      return false;
    }
  }

  Future<bool> deletePerson(int id) async {
    try {
      await client.from('face_images').delete().eq('person_id', id);
      await client.from('persons').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ Error eliminando persona: $e');
      return false;
    }
  }

  Future<String> uploadImage(Uint8List imageBytes, String fileName) async {
    try {
      final filePath = 'face_images/$fileName';

      await client.storage.from('face-images').uploadBinary(
            filePath,
            imageBytes,
            fileOptions: FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final publicUrl =
          client.storage.from('face-images').getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      debugPrint('❌ Error subiendo imagen: $e');
      rethrow;
    }
  }

  Future<bool> addFaceImage({
    required int personId,
    required String imageUrl,
    required List<double> embedding,
    double confidence = 0.95,
  }) async {
    try {
      await client.from('face_images').insert({
        'person_id': personId,
        'image_url': imageUrl,
        'embedding': embedding,
        'confidence': confidence,
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      debugPrint('❌ Error añadiendo imagen facial: $e');
      return false;
    }
  }

  Future<bool> deleteFaceImage(int imageId) async {
    try {
      await client.from('face_images').delete().eq('id', imageId);
      return true;
    } catch (e) {
      debugPrint('❌ Error eliminando imagen facial: $e');
      return false;
    }
  }
}
