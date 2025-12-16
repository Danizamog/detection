import '../../domain/entities/person.dart';

class PersonModel extends Person {
  const PersonModel({
    required super.id,
    required super.name,
    required super.description,
    required super.images,
    required super.averageEmbedding,
    required super.createdAt,
  });

  factory PersonModel.fromJson(Map<String, dynamic> json) {
    final images = (json['face_images'] as List<dynamic>?)
            ?.map((img) => FaceImageModel.fromJson(img))
            .toList() ??
        [];

    List<double> averageEmbedding = [];
    if (images.isNotEmpty) {
      final embeddings = images
          .where((img) => img.embedding.isNotEmpty)
          .map((img) => img.embedding)
          .toList();

      if (embeddings.isNotEmpty) {
        averageEmbedding = _calculateAverageEmbedding(embeddings);
      }
    }

    return PersonModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Sin nombre',
      description: json['description'] as String? ?? '',
      images: images,
      averageEmbedding: averageEmbedding,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
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
}

class FaceImageModel extends FaceImage {
  const FaceImageModel({
    required super.id,
    required super.imageUrl,
    required super.embedding,
    required super.confidence,
    required super.createdAt,
  });

  factory FaceImageModel.fromJson(Map<String, dynamic> json) {
    return FaceImageModel(
      id: json['id'] as int,
      imageUrl: json['image_url'] as String? ?? '',
      embedding: _parseEmbedding(json['embedding']),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.95,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_url': imageUrl,
      'embedding': embedding,
      'confidence': confidence,
      'created_at': createdAt.toIso8601String(),
    };
  }

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
}
