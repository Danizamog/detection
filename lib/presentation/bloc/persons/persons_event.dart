import 'package:equatable/equatable.dart';

abstract class PersonsEvent extends Equatable {
  const PersonsEvent();

  @override
  List<Object?> get props => [];
}

class LoadPersons extends PersonsEvent {}

class PersonsUpdated extends PersonsEvent {
  final dynamic persons; // Will be List<Person> from stream

  const PersonsUpdated(this.persons);

  @override
  List<Object?> get props => [persons];
}

class AddPerson extends PersonsEvent {
  final String name;
  final String description;

  const AddPerson({
    required this.name,
    this.description = '',
  });

  @override
  List<Object?> get props => [name, description];
}

class UpdatePerson extends PersonsEvent {
  final int id;
  final String? name;
  final String? description;

  const UpdatePerson({
    required this.id,
    this.name,
    this.description,
  });

  @override
  List<Object?> get props => [id, name, description];
}

class DeletePerson extends PersonsEvent {
  final int id;

  const DeletePerson(this.id);

  @override
  List<Object?> get props => [id];
}

class AddFaceImageToPerson extends PersonsEvent {
  final int personId;
  final String imageUrl;
  final List<double> embedding;
  final double confidence;

  const AddFaceImageToPerson({
    required this.personId,
    required this.imageUrl,
    required this.embedding,
    this.confidence = 0.95,
  });

  @override
  List<Object?> get props => [personId, imageUrl, embedding, confidence];
}

class DeleteFaceImage extends PersonsEvent {
  final int imageId;

  const DeleteFaceImage(this.imageId);

  @override
  List<Object?> get props => [imageId];
}
