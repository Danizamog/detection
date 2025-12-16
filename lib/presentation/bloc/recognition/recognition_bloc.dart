import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/face_recognition_repository.dart';
import 'recognition_event.dart';
import 'recognition_state.dart';

class RecognitionBloc extends Bloc<RecognitionEvent, RecognitionState> {
  final FaceRecognitionRepository repository;

  RecognitionBloc({required this.repository}) : super(RecognitionInitial()) {
    on<RecognizeFaceFromImage>(_onRecognizeFaceFromImage);
    on<ResetRecognition>(_onResetRecognition);
    on<DetectFacesOnly>(_onDetectFacesOnly);
    on<GetFaceEmbedding>(_onGetFaceEmbedding);
  }

  Future<void> _onRecognizeFaceFromImage(
    RecognizeFaceFromImage event,
    Emitter<RecognitionState> emit,
  ) async {
    emit(RecognitionProcessing());

    try {
      final result = await repository.recognizeFace(
        event.imageBytes,
        threshold: event.threshold,
      );

      if (result != null) {
        emit(RecognitionSuccess(result));
      } else {
        emit(const RecognitionNotFound(
          'No se encontró ninguna coincidencia en la base de datos',
        ));
      }
    } catch (e) {
      emit(RecognitionError('Error al reconocer rostro: $e'));
    }
  }

  void _onResetRecognition(
      ResetRecognition event, Emitter<RecognitionState> emit) {
    emit(RecognitionInitial());
  }

  Future<void> _onDetectFacesOnly(
    DetectFacesOnly event,
    Emitter<RecognitionState> emit,
  ) async {
    emit(RecognitionProcessing());

    try {
      final faces = await repository.detectFaces(event.imageBytes);

      if (faces != null && faces.isNotEmpty) {
        emit(FacesDetected(faces));
      } else {
        emit(
            const RecognitionNotFound('No se detectaron rostros en la imagen'));
      }
    } catch (e) {
      emit(RecognitionError('Error al detectar rostros: $e'));
    }
  }

  Future<void> _onGetFaceEmbedding(
    GetFaceEmbedding event,
    Emitter<RecognitionState> emit,
  ) async {
    emit(RecognitionProcessing());

    try {
      final embedding = await repository.getFaceEmbedding(event.faceImageBytes);
      emit(EmbeddingGenerated(embedding));
    } catch (e) {
      emit(RecognitionError('Error al generar embedding: $e'));
    }
  }
}
