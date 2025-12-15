import 'dart:typed_data';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'face_recognition_service.dart';

class SupabaseService {
  static final String supabaseUrl = 'https://uvdiwniodvndsxembmxz.supabase.co';
  static final String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV2ZGl3bmlvZHZuZHN4ZW1ibXh6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ4ODYzMDYsImV4cCI6MjA4MDQ2MjMwNn0.qBgh6Xjfi-mnSxES_4bVwrgQPxtqBrIqx8ryWPAoY4U';

  static late final SupabaseClient _client;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );

      _client = Supabase.instance.client;
      _initialized = true;

      debugPrint('✅ Supabase inicializado correctamente');
      await _ensureDatabaseStructure();
      await FaceRecognitionService.initialize();
    } catch (e) {
      debugPrint('❌ Error inicializando Supabase: $e');
      rethrow;
    }
  }

  static Future<void> _ensureDatabaseStructure() async {
    try {
      // Verificar que las tablas existan
      await _client.rpc('check_tables_exists');
    } catch (_) {
      debugPrint('⚠️ Ejecuta el script SQL en la consola de Supabase');
    }
  }

  static SupabaseClient get client {
    if (!_initialized) {
      throw Exception(
          'Supabase no ha sido inicializado. Llama a initialize() primero.');
    }
    return _client;
  }

  // ========== PERSONAS (Tabla principal) ==========

  static Future<List<Map<String, dynamic>>> getPersons() async {
    try {
      final response = await client.from('persons').select('''
            *,
            face_images (*)
          ''').order('created_at', ascending: false);

      if (response.isEmpty) return [];

      return List<Map<String, dynamic>>.from(response).map((person) {
        final images =
            List<Map<String, dynamic>>.from(person['face_images'] ?? []);

        // Calcular embedding promedio
        List<double> averageEmbedding = [];
        if (images.isNotEmpty) {
          final embeddings = images
              .where(
                  (img) => img['embedding'] != null && img['embedding'] is List)
              .map((img) => _parseEmbedding(img['embedding']))
              .toList();

          if (embeddings.isNotEmpty) {
            averageEmbedding = _calculateAverageEmbedding(embeddings);
          }
        }

        return {
          'id': person['id'] as int,
          'name': person['name'] as String? ?? 'Sin nombre',
          'description': person['description'] as String? ?? '',
          'averageEmbedding': averageEmbedding,
          'imageCount': images.length,
          'images': images
              .map((img) => ({
                    'id': img['id'] as int,
                    'imageUrl': img['image_url'] as String? ?? '',
                    'embedding': _parseEmbedding(img['embedding']),
                    'confidence':
                        (img['confidence'] as num?)?.toDouble() ?? 0.95,
                    'createdAt': img['created_at'] as String? ?? '',
                  }))
              .toList(),
          'createdAt': person['created_at'] as String? ??
              DateTime.now().toIso8601String(),
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error obteniendo personas: $e');
      return [];
    }
  }

  static Future<int> addPerson({
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

  static Future<bool> updatePerson({
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

  static Future<bool> deletePerson(int id) async {
    try {
      // Primero eliminar las imágenes asociadas
      await client.from('face_images').delete().eq('person_id', id);

      // Luego eliminar la persona
      await client.from('persons').delete().eq('id', id);

      return true;
    } catch (e) {
      debugPrint('❌ Error eliminando persona: $e');
      return false;
    }
  }

  // ========== IMÁGENES FACIALES ==========

  static Future<String> uploadImage(
      Uint8List imageBytes, String fileName) async {
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

  static Future<bool> addFaceImage({
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

  static Future<bool> deleteFaceImage(int imageId) async {
    try {
      await client.from('face_images').delete().eq('id', imageId);

      return true;
    } catch (e) {
      debugPrint('❌ Error eliminando imagen facial: $e');
      return false;
    }
  }

  // ========== RECONOCIMIENTO FACIAL ==========

  static Future<Map<String, dynamic>?> recognizeFace(
    Uint8List imageBytes, {
    double threshold = 0.65,
  }) async {
    try {
      // Detectar rostros en la imagen
      final faces = await FaceRecognitionService.detectFaces(imageBytes);
      if (faces == null || faces.isEmpty) {
        debugPrint('⚠️ No se detectaron rostros en la imagen');
        return null;
      }

      // Usar el primer rostro detectado
      final faceImage = faces.first;

      // Obtener embedding del rostro
      final embedding =
          await FaceRecognitionService.getFaceEmbedding(faceImage);

      // Obtener personas de la base de datos
      final persons = await getPersons();

      if (persons.isEmpty) {
        debugPrint('⚠️ No hay personas en la base de datos');
        return null;
      }

      double bestSimilarity = 0.0;
      Map<String, dynamic>? bestPerson;

      for (final person in persons) {
        final averageEmbedding = person['averageEmbedding'] as List<double>;

        if (averageEmbedding.isEmpty) continue;

        final similarity = FaceRecognitionService.calculateSimilarity(
            embedding, averageEmbedding);

        if (similarity > bestSimilarity && similarity >= threshold) {
          bestSimilarity = similarity;
          bestPerson = person;
        }
      }

      if (bestPerson != null) {
        debugPrint('✅ Persona reconocida: ${bestPerson['name']} '
            '(${(bestSimilarity * 100).toStringAsFixed(1)}%)');

        return {
          'person': bestPerson,
          'similarity': bestSimilarity,
          'confidence': bestSimilarity,
          'faceImage': faceImage,
        };
      } else {
        debugPrint('⚠️ No se encontró coincidencia');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error reconociendo rostro: $e');
      return null;
    }
  }

  // Método para generar embedding real usando FaceNet
  static Future<List<double>> generateFaceEmbedding(
      Uint8List imageBytes) async {
    try {
      // Detectar rostros
      final faces = await FaceRecognitionService.detectFaces(imageBytes);
      if (faces == null || faces.isEmpty) {
        throw Exception('No se detectaron rostros en la imagen');
      }

      // Usar el primer rostro para generar embedding
      final embedding =
          await FaceRecognitionService.getFaceEmbedding(faces.first);
      return embedding;
    } catch (e) {
      debugPrint('❌ Error generando embedding con FaceNet: $e');
      // Propagar error para que el caller maneje y no se guarden datos inválidos
      rethrow;
    }
  }

  // ========== FUNCIONES DE AYUDA ==========

  static List<double> _parseEmbedding(dynamic embeddingData) {
    if (embeddingData == null) return [];

    if (embeddingData is List) {
      return embeddingData.map((e) {
        if (e is int) return e.toDouble();
        if (e is double) return e;
        if (e is String) return double.tryParse(e) ?? 0.0;
        return 0.0;
      }).toList();
    }

    return [];
  }

  static List<double> _calculateAverageEmbedding(
      List<List<double>> embeddings) {
    if (embeddings.isEmpty) return [];

    final length = embeddings.first.length;
    final average = List<double>.filled(length, 0.0);

    for (final embedding in embeddings) {
      if (embedding.length != length) continue;

      for (int i = 0; i < length; i++) {
        average[i] += embedding[i];
      }
    }

    final count = embeddings.length.toDouble();
    return average.map((value) => value / count).toList();
  }

  // Stream para actualización en tiempo real
  static Stream<List<Map<String, dynamic>>> getPersonsStream() {
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

              final images = List<Map<String, dynamic>>.from(imagesResponse);

              List<double> averageEmbedding = [];
              if (images.isNotEmpty) {
                final embeddings = images
                    .where((img) => img['embedding'] != null)
                    .map((img) => _parseEmbedding(img['embedding']))
                    .toList();

                if (embeddings.isNotEmpty) {
                  averageEmbedding = _calculateAverageEmbedding(embeddings);
                }
              }

              return {
                'id': person['id'] as int,
                'name': person['name'] as String? ?? 'Sin nombre',
                'description': person['description'] as String? ?? '',
                'averageEmbedding': averageEmbedding,
                'imageCount': images.length,
                'images': images
                    .map((img) => ({
                          'id': img['id'] as int,
                          'imageUrl': img['image_url'] as String? ?? '',
                          'embedding': _parseEmbedding(img['embedding']),
                          'confidence':
                              (img['confidence'] as num?)?.toDouble() ?? 0.95,
                          'createdAt': img['created_at'] as String? ?? '',
                        }))
                    .toList(),
                'createdAt': person['created_at'] as String? ?? '',
              };
            }),
          );

          return personsWithImages;
        });
  }

  static void dispose() {
    FaceRecognitionService.dispose();
  }
}
