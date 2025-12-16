import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import '../../../domain/entities/recognition_result.dart';

abstract class RecognitionState extends Equatable {
  const RecognitionState();

  @override
  List<Object?> get props => [];
}

class RecognitionInitial extends RecognitionState {}

class RecognitionProcessing extends RecognitionState {}

class RecognitionSuccess extends RecognitionState {
  final RecognitionResult result;

  const RecognitionSuccess(this.result);

  @override
  List<Object?> get props => [result];
}

class RecognitionNotFound extends RecognitionState {
  final String message;

  const RecognitionNotFound(this.message);

  @override
  List<Object?> get props => [message];
}

class RecognitionError extends RecognitionState {
  final String message;

  const RecognitionError(this.message);

  @override
  List<Object?> get props => [message];
}

class FacesDetected extends RecognitionState {
  final List<Uint8List> faces;

  const FacesDetected(this.faces);

  @override
  List<Object?> get props => [faces];
}

class EmbeddingGenerated extends RecognitionState {
  final List<double> embedding;

  const EmbeddingGenerated(this.embedding);

  @override
  List<Object?> get props => [embedding];
}
