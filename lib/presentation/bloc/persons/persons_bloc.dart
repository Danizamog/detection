import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/person.dart';
import '../../../domain/repositories/person_repository.dart';
import 'persons_event.dart';
import 'persons_state.dart';

class PersonsBloc extends Bloc<PersonsEvent, PersonsState> {
  final PersonRepository repository;
  StreamSubscription<List<Person>>? _personsSubscription;

  PersonsBloc({required this.repository}) : super(PersonsInitial()) {
    on<LoadPersons>(_onLoadPersons);
    on<RefreshPersons>(_onRefreshPersons);
    on<PersonsUpdated>(_onPersonsUpdated);
    on<AddPerson>(_onAddPerson);
    on<UpdatePerson>(_onUpdatePerson);
    on<DeletePerson>(_onDeletePerson);
    on<AddFaceImageToPerson>(_onAddFaceImageToPerson);
    on<DeleteFaceImage>(_onDeleteFaceImage);
  }

  void _onLoadPersons(LoadPersons event, Emitter<PersonsState> emit) async {
    emit(PersonsLoading());

    await _personsSubscription?.cancel();

    _personsSubscription = repository.getPersonsStream().listen(
          (persons) => add(PersonsUpdated(persons)),
          onError: (error) => emit(PersonsError(error.toString())),
        );
  }

  Future<void> _onRefreshPersons(
      RefreshPersons event, Emitter<PersonsState> emit) async {
    try {
      final persons = await repository.getPersons();
      emit(PersonsLoaded(persons));
    } catch (e) {
      emit(PersonsError('Error al refrescar: $e'));
    }
  }

  void _onPersonsUpdated(PersonsUpdated event, Emitter<PersonsState> emit) {
    if (event.persons is List<Person>) {
      emit(PersonsLoaded(event.persons as List<Person>));
    }
  }

  Future<void> _onAddPerson(AddPerson event, Emitter<PersonsState> emit) async {
    final currentState = state;
    emit(PersonAdding());

    try {
      final personId = await repository.addPerson(
        name: event.name,
        description: event.description,
      );
      emit(PersonAdded(personId));
      add(RefreshPersons());

      // Restaurar el estado de personas cargadas
      if (currentState is PersonsLoaded) {
        emit(currentState);
      }
    } catch (e) {
      emit(PersonActionError('Error al añadir persona: $e'));
      if (currentState is PersonsLoaded) {
        emit(currentState);
      }
    }
  }

  Future<void> _onUpdatePerson(
      UpdatePerson event, Emitter<PersonsState> emit) async {
    final currentState = state;

    try {
      final success = await repository.updatePerson(
        id: event.id,
        name: event.name,
        description: event.description,
      );

      if (success) {
        emit(PersonUpdated());
        add(RefreshPersons());
      } else {
        emit(const PersonActionError('Error al actualizar persona'));
      }

      if (currentState is PersonsLoaded) {
        emit(currentState);
      }
    } catch (e) {
      emit(PersonActionError('Error al actualizar persona: $e'));
      if (currentState is PersonsLoaded) {
        emit(currentState);
      }
    }
  }

  Future<void> _onDeletePerson(
      DeletePerson event, Emitter<PersonsState> emit) async {
    final currentState = state;

    try {
      final success = await repository.deletePerson(event.id);

      if (success) {
        emit(PersonDeleted());
        add(RefreshPersons());
      } else {
        emit(const PersonActionError('Error al eliminar persona'));
      }

      if (currentState is PersonsLoaded) {
        emit(currentState);
      }
    } catch (e) {
      emit(PersonActionError('Error al eliminar persona: $e'));
      if (currentState is PersonsLoaded) {
        emit(currentState);
      }
    }
  }

  Future<void> _onAddFaceImageToPerson(
    AddFaceImageToPerson event,
    Emitter<PersonsState> emit,
  ) async {
    final currentState = state;

    try {
      final success = await repository.addFaceImage(
        personId: event.personId,
        imageUrl: event.imageUrl,
        embedding: event.embedding,
        confidence: event.confidence,
      );

      if (success) {
        emit(FaceImageAdded());
        add(RefreshPersons());
      } else {
        emit(const PersonActionError('Error al añadir imagen facial'));
      }

      if (currentState is PersonsLoaded) {
        emit(currentState);
      }
    } catch (e) {
      emit(PersonActionError('Error al añadir imagen facial: $e'));
      if (currentState is PersonsLoaded) {
        emit(currentState);
      }
    }
  }

  Future<void> _onDeleteFaceImage(
    DeleteFaceImage event,
    Emitter<PersonsState> emit,
  ) async {
    final currentState = state;

    try {
      final success = await repository.deleteFaceImage(event.imageId);

      if (success) {
        emit(FaceImageDeleted());
        add(RefreshPersons());
      } else {
        emit(const PersonActionError('Error al eliminar imagen facial'));
      }

      if (currentState is PersonsLoaded) {
        emit(currentState);
      }
    } catch (e) {
      emit(PersonActionError('Error al eliminar imagen facial: $e'));
      if (currentState is PersonsLoaded) {
        emit(currentState);
      }
    }
  }

  @override
  Future<void> close() {
    _personsSubscription?.cancel();
    return super.close();
  }
}
