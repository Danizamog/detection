import 'package:equatable/equatable.dart';

class Person extends Equatable {
  final int id;
  final String name;
  final String description;
  final List<FaceImage> images;
  final List<double> averageEmbedding;
  final DateTime createdAt;

  const Person({
    required this.id,
    required this.name,
    required this.description,
    required this.images,
    required this.averageEmbedding,
    required this.createdAt,
  });

  int get imageCount => images.length;

  @override
  List<Object?> get props =>
      [id, name, description, images, averageEmbedding, createdAt];
}

class FaceImage extends Equatable {
  final int id;
  final String imageUrl;
  final List<double> embedding;
  final double confidence;
  final DateTime createdAt;

  const FaceImage({
    required this.id,
    required this.imageUrl,
    required this.embedding,
    required this.confidence,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, imageUrl, embedding, confidence, createdAt];
}
