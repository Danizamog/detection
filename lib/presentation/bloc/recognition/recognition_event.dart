import 'dart:typed_data';
import 'package:equatable/equatable.dart';

abstract class RecognitionEvent extends Equatable {
  const RecognitionEvent();

  @override
  List<Object?> get props => [];
}

class RecognizeFaceFromImage extends RecognitionEvent {
  final Uint8List imageBytes;
  final double threshold;

  const RecognizeFaceFromImage({
    required this.imageBytes,
    this.threshold = 0.65,
  });

  @override
  List<Object?> get props => [imageBytes, threshold];
}

class ResetRecognition extends RecognitionEvent {}

class DetectFacesOnly extends RecognitionEvent {
  final Uint8List imageBytes;

  const DetectFacesOnly(this.imageBytes);

  @override
  List<Object?> get props => [imageBytes];
}

class GetFaceEmbedding extends RecognitionEvent {
  final Uint8List faceImageBytes;

  const GetFaceEmbedding(this.faceImageBytes);

  @override
  List<Object?> get props => [faceImageBytes];
}
