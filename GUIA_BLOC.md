# 📚 Guía Completa: Arquitectura BLoC

## 🎯 ¿Qué es BLoC?

**BLoC** significa **Business Logic Component** (Componente de Lógica de Negocio). Es un patrón de arquitectura creado por Google para Flutter que separa completamente la lógica de negocio de la interfaz de usuario.

### Conceptos Fundamentales

#### 1️⃣ **Eventos (Events)**
Son acciones que el usuario o el sistema dispara. Ejemplos:
- "El usuario presionó el botón de guardar"
- "Se cargó la pantalla"
- "El usuario escribió en un campo de texto"

#### 2️⃣ **Estados (States)**
Representan el estado actual de la aplicación. Ejemplos:
- "Cargando datos..."
- "Datos cargados exitosamente"
- "Error al cargar datos"

#### 3️⃣ **BLoC (Business Logic)**
Es la clase que:
- Recibe eventos
- Procesa la lógica de negocio
- Emite nuevos estados

### Flujo de Datos en BLoC

```
┌─────────────┐
│     UI      │ Usuario interactúa
│  (Widget)   │ ─────────────┐
└─────────────┘               │
       ▲                      │
       │                      ▼
       │               ┌──────────────┐
       │               │    EVENTO    │
       │               │ (LoadData)   │
       │               └──────────────┘
       │                      │
       │                      ▼
       │               ┌──────────────┐
       │               │     BLOC     │
       │               │   (Lógica)   │
       │               └──────────────┘
       │                      │
       │                      ▼
       │               ┌──────────────┐
       └───────────────│    ESTADO    │
      UI escucha       │  (Loading)   │
      y se actualiza   │  (Loaded)    │
                       │  (Error)     │
                       └──────────────┘
```

---

## 🏛️ Clean Architecture

Este proyecto combina BLoC con **Clean Architecture**, que divide el código en 3 capas:

### 📊 Capas de Clean Architecture

```
┌─────────────────────────────────────────┐
│         PRESENTACIÓN (UI)               │
│  • Pantallas (Screens)                  │
│  • BLoCs (Gestión de estado)           │
│  • Widgets                              │
└─────────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────┐
│         DOMINIO (Reglas de Negocio)     │
│  • Entidades (Models puros)             │
│  • Repositorios (Interfaces)            │
│  • Casos de uso                         │
└─────────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────┐
│         DATOS (Fuentes Externas)        │
│  • Datasources (API, Base de datos)    │
│  • Repositorios (Implementaciones)      │
│  • Modelos de datos                     │
└─────────────────────────────────────────┘
```

**Regla de oro:** Las capas superiores pueden depender de las inferiores, pero NO al revés.

---

## 📂 Estructura del Proyecto

```
lib/
├── main.dart                    # Punto de entrada
├── domain/                      # Capa de Dominio
│   ├── entities/
│   └── repositories/
├── data/                        # Capa de Datos
│   ├── models/
│   ├── datasources/
│   └── repositories/
└── presentation/                # Capa de Presentación
    ├── bloc/
    └── screens/
```

---

## 📱 Descripción Detallada de Archivos

### 🔹 `lib/main.dart`
**Punto de entrada de la aplicación**

**Responsabilidades:**
- Inicializar Supabase
- Crear todas las dependencias (Dependency Injection)
- Configurar los BLoCs
- Arrancar la aplicación

**Código clave:**
```dart
void main() async {
  // 1. Inicializar Supabase
  await Supabase.initialize(...);
  
  // 2. Crear datasources
  final supabaseDataSource = SupabaseRemoteDataSource(Supabase.instance.client);
  final tfliteDataSource = TFliteLocalDataSource();
  
  // 3. Crear repositorios
  final personRepository = PersonRepositoryImpl(
    remoteDataSource: supabaseDataSource,
    localDataSource: tfliteDataSource,
  );
  
  // 4. Crear BLoCs
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => PersonsBloc(repository: personRepository)),
        BlocProvider(create: (_) => RecognitionBloc(repository: recognitionRepository)),
      ],
      child: MyApp(),
    ),
  );
}
```

---

## 🧠 Capa de Dominio (`lib/domain/`)

### 📁 `domain/entities/`

#### `person.dart`
**Entidad de Persona**

Representa una persona en el sistema con toda su información.

**Propiedades:**
- `id`: Identificador único (UUID de Supabase)
- `name`: Nombre de la persona
- `description`: Descripción opcional
- `images`: Lista de imágenes faciales (`List<FaceImage>`)
- `averageEmbedding`: Embedding promedio de todas sus fotos (512 números)
- `createdAt`: Fecha de registro

**Clase anidada `FaceImage`:**
- `id`: ID de la imagen
- `url`: URL en Supabase Storage
- `embedding`: Vector de 512 dimensiones que representa el rostro

**Por qué es importante:**
Esta es la representación pura del concepto de "Persona". No sabe nada de bases de datos ni APIs.

---

#### `recognition_result.dart`
**Resultado de Reconocimiento Facial**

Representa el resultado cuando se reconoce un rostro.

**Propiedades:**
- `personId`: ID de la persona reconocida
- `personName`: Nombre de la persona
- `personDescription`: Descripción (puede ser null)
- `similarity`: Nivel de coincidencia (0.0 a 1.0)
- `faceImage`: Imagen del rostro detectado (bytes)

---

### 📁 `domain/repositories/`

Estas son **interfaces** (contratos). Definen QUÉ operaciones se pueden hacer, pero NO cómo se implementan.

#### `person_repository.dart`
**Interfaz del Repositorio de Personas**

Define todas las operaciones relacionadas con personas:

```dart
abstract class PersonRepository {
  Future<List<Person>> getPersons();              // Obtener todas las personas
  Stream<List<Person>> getPersonsStream();        // Stream de actualizaciones en tiempo real
  Future<String> addPerson(...);                  // Crear nueva persona
  Future<void> updatePerson(...);                 // Actualizar datos
  Future<void> deletePerson(String id);           // Eliminar persona
  Future<String> uploadImage(...);                // Subir imagen a storage
  Future<void> addFaceImage(...);                 // Añadir imagen facial con embedding
  Future<void> deleteFaceImage(...);              // Eliminar imagen específica
  Future<List<double>> generateFaceEmbedding(...); // Generar embedding de una foto
}
```

---

#### `face_recognition_repository.dart`
**Interfaz del Repositorio de Reconocimiento**

Define operaciones de reconocimiento facial:

```dart
abstract class FaceRecognitionRepository {
  Future<void> initialize();                      // Inicializar modelos TFLite
  Future<List<dynamic>> detectFaces(...);         // Detectar rostros en imagen
  Future<List<double>> getFaceEmbedding(...);     // Generar embedding de rostro
  double calculateSimilarity(...);                // Calcular similitud entre embeddings
  Future<RecognitionResult?> recognizeFace(...);  // Reconocer rostro completo
}
```

---

## 💾 Capa de Datos (`lib/data/`)

### 📁 `data/models/`

#### `person_model.dart`
**Modelo de Datos de Persona**

Extiende la entidad `Person` y añade funcionalidad de conversión JSON.

**Responsabilidades:**
- Convertir JSON de Supabase a objetos Dart (`fromJson`)
- Convertir objetos Dart a JSON (`toJson`)
- Calcular el embedding promedio de todas las imágenes

**Ejemplo de conversión:**
```dart
// JSON de Supabase
{
  "id": "abc-123",
  "name": "Juan Pérez",
  "images": [
    {"id": "img1", "url": "https://...", "embedding": [0.1, 0.2, ...]},
    {"id": "img2", "url": "https://...", "embedding": [0.15, 0.22, ...]}
  ]
}

// Se convierte a:
PersonModel(
  id: "abc-123",
  name: "Juan Pérez",
  images: [FaceImage(...), FaceImage(...)],
  averageEmbedding: [0.125, 0.21, ...] // Promedio calculado
)
```

---

### 📁 `data/datasources/`

Los **datasources** hacen el trabajo "sucio" de comunicarse con APIs y bases de datos.

#### `supabase_remote_datasource.dart`
**Comunicación con Supabase**

**Responsabilidades:**
- Hacer peticiones HTTP a Supabase (GET, POST, PUT, DELETE)
- Subir archivos al Storage
- Escuchar cambios en tiempo real (Realtime)
- Convertir respuestas JSON a modelos

**Operaciones principales:**
- `getPersons()`: SELECT * FROM persons con JOIN a images
- `addPerson()`: INSERT INTO persons
- `updatePerson()`: UPDATE persons SET ...
- `deletePerson()`: DELETE FROM persons + eliminar imágenes
- `uploadImage()`: Subir archivo a Supabase Storage
- `addFaceImage()`: INSERT INTO images con URL y embedding
- `deleteFaceImage()`: DELETE FROM images + eliminar del storage
- `getPersonsStream()`: Escuchar cambios con Supabase Realtime

**Ejemplo de stream en tiempo real:**
```dart
Stream<List<PersonModel>> getPersonsStream() {
  return supabaseClient
      .from('persons')
      .stream(primaryKey: ['id'])  // Escucha cambios
      .map((data) => data.map((json) => PersonModel.fromJson(json)).toList());
}
```

---

#### `tflite_local_datasource.dart`
**Procesamiento de Inteligencia Artificial Local**

**Responsabilidades:**
- Cargar modelos TFLite (FaceNet-512 y YOLO)
- Detectar rostros en imágenes
- Generar embeddings faciales
- Calcular similitud entre rostros

**Modelos usados:**
1. **YOLO Face Detector** (`yolo_face_detector.tflite`)
   - Detecta dónde están los rostros en una imagen
   - Devuelve coordenadas [x, y, width, height]

2. **FaceNet-512** (`facenet_512.tflite`)
   - Convierte un rostro en un vector de 512 números
   - Rostros similares tienen vectores similares

**Proceso de reconocimiento:**
```dart
// 1. Detectar rostro
List faces = await detectFaces(imageBytes);
// faces = [[x: 100, y: 150, width: 200, height: 200]]

// 2. Recortar rostro
Uint8List faceImage = _cropFace(imageBytes, faces[0]);

// 3. Generar embedding
List<double> embedding = await getFaceEmbedding(faceImage);
// embedding = [0.234, -0.123, 0.456, ..., 0.789] (512 números)

// 4. Comparar con embeddings en BD
double similarity = calculateSimilarity(embedding, storedEmbedding);
// similarity = 0.87 (87% de coincidencia)
```

---

### 📁 `data/repositories/`

Los **repositorios** implementan las interfaces del dominio y coordinan los datasources.

#### `person_repository_impl.dart`
**Implementación del Repositorio de Personas**

**Responsabilidades:**
- Coordinar operaciones entre Supabase y TFLite
- Implementar la lógica de negocio compleja
- Manejar errores

**Dependencias:**
- `SupabaseRemoteDataSource`: Para operaciones en BD
- `TFliteLocalDataSource`: Para generar embeddings

**Flujo de añadir persona con imágenes:**
```dart
1. Crear persona en Supabase
2. Por cada imagen:
   a. Detectar rostro con TFLite
   b. Generar embedding con TFLite
   c. Subir imagen a Storage
   d. Guardar URL + embedding en BD
3. Retornar ID de persona creada
```

---

#### `face_recognition_repository_impl.dart`
**Implementación del Repositorio de Reconocimiento**

**Responsabilidades:**
- Implementar el flujo completo de reconocimiento facial
- Comparar embedding con todas las personas registradas
- Determinar si hay coincidencia según umbral

**Flujo de reconocimiento:**
```dart
Future<RecognitionResult?> recognizeFace(
  Uint8List imageBytes,
  double threshold, // Ej: 0.5 = 50% mínimo de similitud
) async {
  // 1. Detectar rostro
  List faces = await localDataSource.detectFaces(imageBytes);
  if (faces.isEmpty) return null;
  
  // 2. Generar embedding del rostro
  List<double> faceEmbedding = await localDataSource.getFaceEmbedding(faceImage);
  
  // 3. Obtener todas las personas
  List<Person> persons = await remoteDataSource.getPersons();
  
  // 4. Comparar con cada persona
  for (Person person in persons) {
    double similarity = localDataSource.calculateSimilarity(
      faceEmbedding,
      person.averageEmbedding,
    );
    
    if (similarity >= threshold) {
      return RecognitionResult(
        personId: person.id,
        personName: person.name,
        similarity: similarity,
      );
    }
  }
  
  return null; // No se encontró coincidencia
}
```

---

## 🎨 Capa de Presentación (`lib/presentation/`)

### 📁 `presentation/bloc/persons/`

#### `persons_event.dart`
**Eventos de Personas**

Todas las acciones que el usuario puede hacer relacionadas con personas:

```dart
// Cargar lista de personas
class LoadPersons extends PersonsEvent {}

// Añadir nueva persona
class AddPerson extends PersonsEvent {
  final String name;
  final String? description;
}

// Actualizar persona existente
class UpdatePerson extends PersonsEvent {
  final String id;
  final String name;
  final String? description;
}

// Eliminar persona
class DeletePerson extends PersonsEvent {
  final String id;
}

// Añadir imagen a persona
class AddFaceImageToPerson extends PersonsEvent {
  final String personId;
  final Uint8List imageBytes;
  final List<double> embedding;
}

// Eliminar imagen de persona
class DeleteFaceImage extends PersonsEvent {
  final String personId;
  final String imageId;
}
```

---

#### `persons_state.dart`
**Estados de Personas**

Representa todos los posibles estados de la gestión de personas:

```dart
// Estado inicial
class PersonsInitial extends PersonsState {}

// Cargando lista
class PersonsLoading extends PersonsState {}

// Lista cargada exitosamente
class PersonsLoaded extends PersonsState {
  final List<Person> persons;
}

// Error al cargar
class PersonsError extends PersonsState {
  final String message;
}

// Añadiendo persona
class PersonAdding extends PersonsState {}

// Persona añadida exitosamente
class PersonAdded extends PersonsState {
  final String personId;
}

// Error al añadir
class PersonAddError extends PersonsState {
  final String message;
}

// Estados similares para: Update, Delete, AddImage, DeleteImage
```

---

#### `persons_bloc.dart`
**BLoC de Personas**

**Responsabilidad:** Gestionar toda la lógica de CRUD de personas.

**Cómo funciona:**

```dart
class PersonsBloc extends Bloc<PersonsEvent, PersonsState> {
  final PersonRepository repository;
  StreamSubscription? _personsSubscription;
  
  PersonsBloc({required this.repository}) : super(PersonsInitial()) {
    // Registrar handlers para cada evento
    on<LoadPersons>(_onLoadPersons);
    on<AddPerson>(_onAddPerson);
    on<UpdatePerson>(_onUpdatePerson);
    on<DeletePerson>(_onDeletePerson);
    on<AddFaceImageToPerson>(_onAddFaceImageToPerson);
    on<DeleteFaceImage>(_onDeleteFaceImage);
  }
  
  // Handler de LoadPersons
  Future<void> _onLoadPersons(LoadPersons event, Emitter emit) async {
    emit(PersonsLoading());  // Emitir estado de carga
    
    // Cancelar stream anterior si existe
    await _personsSubscription?.cancel();
    
    // Escuchar stream de Supabase
    _personsSubscription = repository.getPersonsStream().listen(
      (persons) => emit(PersonsLoaded(persons)),  // Emitir cuando lleguen datos
      onError: (error) => emit(PersonsError(error.toString())),
    );
  }
  
  // Handler de AddPerson
  Future<void> _onAddPerson(AddPerson event, Emitter emit) async {
    emit(PersonAdding());
    
    try {
      final personId = await repository.addPerson(
        name: event.name,
        description: event.description,
      );
      
      emit(PersonAdded(personId: personId));
      add(LoadPersons());  // Recargar lista
    } catch (e) {
      emit(PersonAddError(message: e.toString()));
    }
  }
}
```

---

### 📁 `presentation/bloc/recognition/`

#### `recognition_event.dart`
**Eventos de Reconocimiento**

```dart
// Reconocer rostro en imagen
class RecognizeFaceFromImage extends RecognitionEvent {
  final Uint8List imageBytes;
  final double threshold; // Umbral de confianza (0.0 - 1.0)
}

// Resetear estado de reconocimiento
class ResetRecognition extends RecognitionEvent {}

// Solo detectar rostros sin reconocer
class DetectFacesOnly extends RecognitionEvent {
  final Uint8List imageBytes;
}

// Generar embedding de un rostro
class GetFaceEmbedding extends RecognitionEvent {
  final Uint8List faceImageBytes;
}
```

---

#### `recognition_state.dart`
**Estados de Reconocimiento**

```dart
// Estado inicial
class RecognitionInitial extends RecognitionState {}

// Procesando imagen
class RecognitionProcessing extends RecognitionState {}

// Rostro reconocido exitosamente
class RecognitionSuccess extends RecognitionState {
  final RecognitionResult result;
}

// No se encontró coincidencia
class RecognitionNotFound extends RecognitionState {
  final String message;
}

// Error en reconocimiento
class RecognitionError extends RecognitionState {
  final String message;
}

// Rostros detectados (sin reconocer)
class FacesDetected extends RecognitionState {
  final List<dynamic> faces;
}

// Embedding generado
class EmbeddingGenerated extends RecognitionState {
  final List<double> embedding;
}
```

---

#### `recognition_bloc.dart`
**BLoC de Reconocimiento**

**Responsabilidad:** Gestionar el proceso de reconocimiento facial.

```dart
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
    Emitter emit,
  ) async {
    emit(RecognitionProcessing());
    
    try {
      final result = await repository.recognizeFace(
        imageBytes: event.imageBytes,
        threshold: event.threshold,
      );
      
      if (result != null) {
        emit(RecognitionSuccess(result: result));
      } else {
        emit(RecognitionNotFound(message: 'No se encontró coincidencia'));
      }
    } catch (e) {
      emit(RecognitionError(message: e.toString()));
    }
  }
}
```

---

### 📁 `presentation/screens/`

#### `home_screen.dart`
**Pantalla Principal**

**Qué hace:**
- Muestra estadísticas (total personas, total imágenes)
- Tarjetas de acceso rápido a funciones principales
- Navegación a otras pantallas

**Cómo usa BLoC:**
```dart
BlocBuilder<PersonsBloc, PersonsState>(
  builder: (context, state) {
    if (state is PersonsLoaded) {
      return Column(
        children: [
          Text('Total personas: ${state.persons.length}'),
          Text('Total imágenes: ${_countImages(state.persons)}'),
        ],
      );
    }
    return CircularProgressIndicator();
  },
)
```

---

#### `persons_screen.dart`
**Lista de Personas**

**Qué hace:**
- Muestra grid de todas las personas registradas
- Cada tarjeta tiene foto, nombre y número de imágenes
- Click en tarjeta abre detalle

**Cómo usa BLoC:**
```dart
BlocBuilder<PersonsBloc, PersonsState>(
  builder: (context, state) {
    if (state is PersonsLoading) return CircularProgressIndicator();
    
    if (state is PersonsLoaded) {
      return GridView.builder(
        itemCount: state.persons.length,
        itemBuilder: (context, index) {
          final person = state.persons[index];
          return PersonCard(person: person);
        },
      );
    }
    
    if (state is PersonsError) return Text('Error: ${state.message}');
    
    return Container();
  },
)
```

**Actualización en tiempo real:**
Cuando alguien añade/elimina una persona en Supabase, el stream del BLoC recibe el cambio y el `BlocBuilder` se reconstruye automáticamente.

---

#### `camera_screen_real.dart`
**Cámara con Reconocimiento en Tiempo Real**

**Qué hace:**
- Muestra preview de la cámara
- Cada 2 segundos captura un frame y lo reconoce
- Muestra resultados en overlay (nombre, similitud)
- Permite capturar y guardar fotos

**Cómo usa BLoC:**
```dart
// Escuchar cambios de estado de reconocimiento
BlocListener<RecognitionBloc, RecognitionState>(
  listener: (context, state) {
    if (state is RecognitionSuccess) {
      setState(() {
        _recognizedPersonName = state.result.personName;
        _similarity = state.result.similarity;
      });
    } else if (state is RecognitionNotFound) {
      setState(() {
        _recognizedPersonName = 'Desconocido';
      });
    }
  },
  child: CameraPreview(_controller),
)

// Procesar frame cada 2 segundos
void _processFrame() {
  _controller.takePicture().then((XFile file) async {
    final bytes = await file.readAsBytes();
    
    // Disparar evento de reconocimiento
    context.read<RecognitionBloc>().add(
      RecognizeFaceFromImage(
        imageBytes: bytes,
        threshold: 0.5,
      ),
    );
  });
}
```

---

#### `add_person_screen.dart`
**Formulario de Nueva Persona**

**Qué hace:**
- Formulario con nombre y descripción
- Selector de múltiples imágenes
- Valida que las imágenes contengan rostros
- Genera embeddings antes de guardar

**Cómo usa el repository:**
```dart
Future<void> _savePerson() async {
  // 1. Crear persona
  final personId = await context.read<PersonsBloc>().repository.addPerson(
    name: _nameController.text,
    description: _descriptionController.text,
  );
  
  // 2. Por cada imagen seleccionada
  for (XFile imageFile in _selectedImages) {
    final bytes = await imageFile.readAsBytes();
    
    // a. Generar embedding
    final embedding = await context.read<PersonsBloc>().repository
        .generateFaceEmbedding(bytes);
    
    // b. Subir imagen
    final imageUrl = await context.read<PersonsBloc>().repository
        .uploadImage(bytes, personId);
    
    // c. Guardar en BD
    await context.read<PersonsBloc>().repository.addFaceImage(
      personId: personId,
      imageUrl: imageUrl,
      embedding: embedding,
    );
  }
  
  // 3. Recargar lista
  context.read<PersonsBloc>().add(LoadPersons());
}
```

---

#### `person_detail_screen.dart`
**Detalle de Persona**

**Qué hace:**
- Muestra toda la información de una persona
- Permite editar nombre y descripción
- Grid de todas las imágenes
- Botones para añadir/eliminar imágenes
- Botón de eliminar persona

**Cómo usa el repository:**
```dart
// Cargar datos
Future<void> _loadPerson() async {
  final persons = await context.read<PersonsBloc>().repository.getPersons();
  setState(() {
    _person = persons.firstWhere((p) => p.id == widget.personId);
  });
}

// Editar persona
Future<void> _updatePerson() async {
  await context.read<PersonsBloc>().repository.updatePerson(
    id: _person.id,
    name: _nameController.text,
    description: _descriptionController.text,
  );
  context.read<PersonsBloc>().add(LoadPersons());
}

// Eliminar persona
Future<void> _deletePerson() async {
  await context.read<PersonsBloc>().repository.deletePerson(_person.id);
  context.read<PersonsBloc>().add(LoadPersons());
  Navigator.pop(context);
}
```

---

## 🔄 Flujos Completos de Uso

### Flujo 1: Usuario Abre la App

```
1. main.dart inicializa Supabase
2. main.dart crea datasources y repositorios
3. main.dart crea PersonsBloc con repository
4. MyApp se renderiza con MultiBlocProvider
5. HomeScreen se muestra
6. HomeScreen dispara: context.read<PersonsBloc>().add(LoadPersons())
7. PersonsBloc recibe LoadPersons event
8. PersonsBloc llama: repository.getPersonsStream()
9. Repository llama: remoteDataSource.getPersonsStream()
10. Datasource hace query a Supabase con Realtime
11. Supabase retorna stream con personas
12. PersonsBloc emite: PersonsLoaded(persons: [...])
13. BlocBuilder en HomeScreen se reconstruye
14. UI muestra estadísticas
```

---

### Flujo 2: Usuario Toma Foto en Cámara

```
1. Usuario abre CameraScreen
2. CameraController inicia preview
3. Timer dispara _processFrame() cada 2 segundos
4. _processFrame() captura frame como bytes
5. Dispara evento: RecognizeFaceFromImage(imageBytes: bytes, threshold: 0.5)
6. RecognitionBloc recibe evento
7. RecognitionBloc emite: RecognitionProcessing()
8. RecognitionBloc llama: repository.recognizeFace(bytes, 0.5)
9. Repository llama: localDataSource.detectFaces(bytes)
10. TFLite YOLO detecta rostro → [x: 100, y: 150, width: 200, height: 200]
11. Repository recorta imagen del rostro
12. Repository llama: localDataSource.getFaceEmbedding(faceBytes)
13. TFLite FaceNet genera embedding → [0.234, -0.123, ..., 0.789] (512 números)
14. Repository llama: remoteDataSource.getPersons()
15. Supabase retorna todas las personas con sus embeddings
16. Repository recorre cada persona:
    - Calcula similitud = cosine_similarity(nuevo_embedding, persona.averageEmbedding)
    - Si similitud >= 0.5 → MATCH encontrado
17. Repository retorna RecognitionResult(personName: "Juan", similarity: 0.87)
18. RecognitionBloc emite: RecognitionSuccess(result: ...)
19. BlocListener en CameraScreen detecta cambio de estado
20. UI actualiza overlay mostrando: "Juan - 87%"
```

---

### Flujo 3: Usuario Añade Nueva Persona

```
1. Usuario abre AddPersonScreen
2. Usuario llena formulario: nombre="María", descripción="Ingeniera"
3. Usuario selecciona 3 fotos desde galería
4. Usuario presiona "Guardar"
5. Por cada foto:
   a. Se llama: repository.generateFaceEmbedding(imageBytes)
   b. TFLite detecta rostro y genera embedding
   c. Si no hay rostro → mostrar error y cancelar
6. Si todas tienen rostro → llamar repository.addPerson("María", "Ingeniera")
7. Repository llama: remoteDataSource.addPerson()
8. Supabase INSERT INTO persons → retorna personId
9. Por cada foto:
   a. repository.uploadImage(bytes, personId)
   b. Datasource sube a Storage → retorna URL
   c. repository.addFaceImage(personId, url, embedding)
   d. Datasource INSERT INTO images
10. Se calcula averageEmbedding de las 3 fotos
11. Supabase Realtime notifica cambio en tabla persons
12. PersonsBloc escucha stream y recibe nueva persona
13. PersonsBloc emite: PersonsLoaded(persons: [...nuevaLista...])
14. HomeScreen y PersonsScreen se actualizan automáticamente
15. AddPersonScreen navega de vuelta con Navigator.pop()
```

---

## 🎯 Beneficios de Esta Arquitectura

### 1️⃣ **Separación de Responsabilidades**
Cada clase tiene un propósito único y claro.

### 2️⃣ **Testeable**
Puedes hacer tests unitarios de cada capa:
```dart
test('PersonsBloc emite PersonsLoaded al cargar personas', () async {
  // Arrange: crear mock del repository
  final mockRepo = MockPersonRepository();
  when(mockRepo.getPersonsStream()).thenAnswer((_) => Stream.value([person1]));
  
  // Act: crear BLoC y disparar evento
  final bloc = PersonsBloc(repository: mockRepo);
  bloc.add(LoadPersons());
  
  // Assert: verificar estados emitidos
  await expectLater(
    bloc.stream,
    emitsInOrder([PersonsLoading(), PersonsLoaded([person1])]),
  );
});
```

### 3️⃣ **Mantenible**
Si cambias de Supabase a Firebase, solo modificas el datasource. El resto del código sigue igual.

### 4️⃣ **Escalable**
Añadir nuevas features es fácil:
- Nueva pantalla → Crea screen y usa BLoC existente
- Nueva funcionalidad → Añade evento y handler en BLoC

### 5️⃣ **Reactiva**
La UI se actualiza automáticamente cuando cambian los datos (gracias a streams y BlocBuilder).

### 6️⃣ **Type-Safe**
Usas clases tipadas (`Person`, `RecognitionResult`) en lugar de `Map<String, dynamic>`.

---

## 📦 Dependencias Clave

```yaml
dependencies:
  flutter_bloc: ^8.1.6      # Gestión de estado BLoC
  equatable: ^2.0.5         # Comparación de objetos inmutables
  supabase_flutter: ^2.5.6  # Backend (BD + Storage + Realtime)
  tflite_flutter: ^0.12.1   # Modelos de IA (FaceNet + YOLO)
  camera: ^0.11.0+2         # Cámara del dispositivo
  image_picker: ^1.1.2      # Selector de imágenes
```

---

## 🚀 Comandos Útiles

```bash
# Obtener dependencias
flutter pub get

# Ejecutar app
flutter run

# Generar código (si usas freezed)
flutter pub run build_runner build --delete-conflicting-outputs

# Tests
flutter test

# Análisis de código
flutter analyze
```

---

## 📖 Recursos para Aprender Más

- **BLoC Library:** https://bloclibrary.dev/
- **Flutter BLoC Tutorial:** https://bloclibrary.dev/tutorials/flutter-counter/
- **Clean Architecture:** https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html
- **Supabase Docs:** https://supabase.com/docs
- **TFLite Flutter:** https://pub.dev/packages/tflite_flutter

---

**Nota final:** Esta arquitectura puede parecer compleja al principio, pero es el estándar en aplicaciones profesionales. Cada capa tiene un propósito claro y el código es más fácil de entender, probar y mantener a largo plazo.
