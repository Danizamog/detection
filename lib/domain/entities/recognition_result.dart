import 'dart:typed_data';

class RecognitionResult {
  final int personId;
  final String personName;
  final String personDescription;
  final double similarity;
  final Uint8List? faceImage;

  const RecognitionResult({
    required this.personId,
    required this.personName,
    required this.personDescription,
    required this.similarity,
    this.faceImage,
  });
}
