import 'package:equatable/equatable.dart';
import '../../../domain/entities/person.dart';

abstract class PersonsState extends Equatable {
  const PersonsState();

  @override
  List<Object?> get props => [];
}

class PersonsInitial extends PersonsState {}

class PersonsLoading extends PersonsState {}

class PersonsLoaded extends PersonsState {
  final List<Person> persons;

  const PersonsLoaded(this.persons);

  @override
  List<Object?> get props => [persons];
}

class PersonsError extends PersonsState {
  final String message;

  const PersonsError(this.message);

  @override
  List<Object?> get props => [message];
}

class PersonAdding extends PersonsState {}

class PersonAdded extends PersonsState {
  final int personId;

  const PersonAdded(this.personId);

  @override
  List<Object?> get props => [personId];
}

class PersonUpdated extends PersonsState {}

class PersonDeleted extends PersonsState {}

class FaceImageAdded extends PersonsState {}

class FaceImageDeleted extends PersonsState {}

class PersonActionError extends PersonsState {
  final String message;

  const PersonActionError(this.message);

  @override
  List<Object?> get props => [message];
}
