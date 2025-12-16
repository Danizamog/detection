# 📐 Arquitectura BLoC - Sistema de Reconocimiento Facial

Este documento describe la migración completa del proyecto a **arquitectura BLoC (Business Logic Component)** siguiendo los principios de **Clean Architecture**.

---

## 🎯 Cambios Principales

### ✅ De Arquitectura Monolítica → Arquitectura en Capas

**ANTES:**
```
lib/
├── main.dart
├── supabase_service.dart          ❌ Servicios estáticos
├── face_recognition_service.dart  ❌ Servicios estáticos  
├── home_screen.dart               ❌ UI mezclada con lógica
├── persons_screen.dart
└── camera_screen_real.dart
```

**AHORA:**
```
lib/
├── main.dart                       ✅ Inyección de dependencias
├── data/                           ✅ Capa de datos
│   ├── models/
│   ├── datasources/
│   └── repositories/
├── domain/                         ✅ Capa de negocio
│   ├── entities/
│   └── repositories/
└── presentation/                   ✅ Capa de presentación
    ├── bloc/
    └── screens/
```

---

## 📂 Estructura de Carpetas Detallada

### 🗂️ **`lib/data/` - Capa de Datos**

Maneja toda la comunicación con fuentes de datos externas (Supabase, TFLite).

#### **`data/models/`**
- **`person_model.dart`**
  - Modelo de datos que representa una persona con sus imágenes
  - Convierte JSON de Supabase a objetos Dart
  - Calcula embeddings promedio de todas las imágenes
  - Hereda de la entidad del dominio

#### **`data/datasources/`**
- **`supabase_remote_datasource.dart`**
  - Comunicación directa con Supabase (API REST)
  - CRUD de personas e imágenes
  - Subida de imágenes al storage
  - Stream en tiempo real de cambios en la BD
  
- **`tflite_local_datasource.dart`**
  - Carga y ejecuta modelos TFLite (FaceNet + YOLO)
  - Detección de rostros en imágenes
  - Generación de embeddings faciales (512 dimensiones)
  - Cálculo de similitud coseno entre embeddings
  - Pre-procesamiento de imágenes para los modelos

#### **`data/repositories/`**
- **`person_repository_impl.dart`**
  - Implementación del repositorio de personas
  - Combina datasources remoto y local
  - Orquesta operaciones complejas (upload + embedding)
  
- **`face_recognition_repository_impl.dart`**
  - Implementación del repositorio de reconocimiento
  - Coordina detección y reconocimiento facial
  - Compara embeddings con la base de datos

---

### 🧠 **`lib/domain/` - Capa de Dominio (Lógica de Negocio)**

Define las reglas de negocio sin depender de frameworks externos.

#### **`domain/entities/`**
- **`person.dart`**
  - Entidad pura de Persona (sin lógica de BD)
  - Usa `Equatable` para comparaciones
  - Propiedades: id, name, description, images, averageEmbedding
  - Clase `FaceImage` anidada para imágenes individuales

- **`recognition_result.dart`**
  - Resultado de un reconocimiento facial exitoso
  - Incluye: personId, personName, similarity, faceImage

#### **`domain/repositories/`**
- **`person_repository.dart`**
  - Interfaz (contrato) del repositorio de personas
  - Define operaciones: getPersons, addPerson, updatePerson, deletePerson
  - Métodos para imágenes: uploadImage, addFaceImage, generateFaceEmbedding

- **`face_recognition_repository.dart`**
  - Interfaz del repositorio de reconocimiento
  - Define: detectFaces, getFaceEmbedding, recognizeFace, calculateSimilarity

---

### 🎨 **`lib/presentation/` - Capa de Presentación (UI)**

Todo lo visual y la gestión de estados.

#### **`presentation/bloc/persons/`**
Gestiona el estado de la lista de personas y operaciones CRUD.

- **`persons_event.dart`** - Eventos que dispara la UI:
  - `LoadPersons` - Cargar lista de personas
  - `AddPerson` - Añadir nueva persona
  - `UpdatePerson` - Actualizar datos de persona
  - `DeletePerson` - Eliminar persona
  - `AddFaceImageToPerson` - Añadir imagen a una persona
  - `DeleteFaceImage` - Eliminar imagen específica

- **`persons_state.dart`** - Estados posibles:
  - `PersonsInitial` - Estado inicial
  - `PersonsLoading` - Cargando datos
  - `PersonsLoaded(persons)` - Datos cargados exitosamente
  - `PersonsError(message)` - Error al cargar
  - `PersonAdding` - Añadiendo persona
  - `PersonAdded(personId)` - Persona añadida
  - Estados para update/delete de personas e imágenes

- **`persons_bloc.dart`** - Lógica del BLoC:
  - Escucha eventos y emite estados
  - Gestiona stream de Supabase en tiempo real
  - Coordina operaciones con el repositorio

#### **`presentation/bloc/recognition/`**
Gestiona el reconocimiento facial en tiempo real.

- **`recognition_event.dart`** - Eventos:
  - `RecognizeFaceFromImage(imageBytes)` - Reconocer rostro en imagen
  - `ResetRecognition` - Resetear estado
  - `DetectFacesOnly(imageBytes)` - Solo detectar sin reconocer
  - `GetFaceEmbedding(faceImageBytes)` - Generar embedding

- **`recognition_state.dart`** - Estados:
  - `RecognitionInitial` - Sin reconocimiento activo
  - `RecognitionProcessing` - Procesando imagen
  - `RecognitionSuccess(result)` - Rostro reconocido
  - `RecognitionNotFound(message)` - No se encontró coincidencia
  - `RecognitionError(message)` - Error en el proceso
  - `FacesDetected(faces)` - Rostros detectados
  - `EmbeddingGenerated(embedding)` - Embedding generado

- **`recognition_bloc.dart`** - Lógica del BLoC:
  - Procesa reconocimiento facial
  - Coordina con repository de reconocimiento
  - Maneja umbrales de confianza

#### **`presentation/screens/`**
Pantallas de la aplicación.

- **`home_screen.dart`**
  - Pantalla principal con estadísticas
  - Usa `BlocBuilder<PersonsBloc>` para mostrar datos
  - Tarjetas de acceso rápido a funcionalidades

- **`persons_screen.dart`**
  - Lista de todas las personas registradas
  - Grid responsive de tarjetas con fotos
  - Usa `BlocBuilder<PersonsBloc>` para actualización en tiempo real

- **`camera_screen_real.dart`**
  - Cámara en tiempo real con reconocimiento continuo
  - Usa `BlocListener<RecognitionBloc>` para recibir resultados
  - Dispara eventos de reconocimiento cada 2 segundos
  - Captura y guarda nuevas imágenes

- **`add_person_screen.dart`**
  - Formulario para registrar nueva persona
  - Permite seleccionar múltiples imágenes
  - Genera embeddings antes de guardar
  - Valida que haya rostros en las imágenes

- **`person_detail_screen.dart`**
  - Detalles de una persona específica
  - Editar nombre y descripción
  - Añadir/eliminar imágenes
  - Ver todas las fotos en grid

---

## 🔄 Flujo de Datos

### **Ejemplo: Reconocer Rostro en Cámara**

```
1. UI (CameraScreen) → Captura frame
2. UI → Dispara evento: RecognizeFaceFromImage(imageBytes)
3. RecognitionBloc → Recibe evento
4. RecognitionBloc → Llama a repository.recognizeFace()
5. Repository → Llama a localDataSource.detectFaces()
6. LocalDataSource (TFLite) → Procesa con YOLO, detecta rostro
7. Repository → Llama a localDataSource.getFaceEmbedding()
8. LocalDataSource (TFLite) → Procesa con FaceNet, genera embedding
9. Repository → Llama a remoteDataSource.getPersons()
10. RemoteDataSource (Supabase) → Obtiene todas las personas con sus embeddings
11. Repository → Calcula similitud coseno con todos los embeddings
12. Repository → Retorna resultado si similitud > umbral
13. RecognitionBloc → Emite RecognitionSuccess(result)
14. UI → BlocListener escucha estado, actualiza UI con nombre de persona
```

### **Ejemplo: Añadir Nueva Persona**

```
1. UI (AddPersonScreen) → Usuario llena formulario + selecciona fotos
2. UI → Llama directamente a repository.addPerson()
3. Repository → remoteDataSource.addPerson() → Crea persona en BD
4. UI → Por cada foto:
   a. repository.generateFaceEmbedding() → Valida rostro y genera embedding
   b. repository.uploadImage() → Sube a Supabase Storage
   c. repository.addFaceImage() → Guarda URL + embedding en BD
5. PersonsBloc → Stream de Supabase detecta cambio automáticamente
6. PersonsBloc → Emite PersonsLoaded con lista actualizada
7. UI → Todas las pantallas que usan BlocBuilder se actualizan
```

---

## 🆚 Comparación: Antes vs Ahora

| Aspecto | ANTES (Servicios Estáticos) | AHORA (BLoC + Clean Architecture) |
|---------|------------------------------|-----------------------------------|
| **Estado** | `Provider` con `Map<String, dynamic>` | `BLoC` con entidades tipadas |
| **Lógica de negocio** | Mezclada en servicios y UI | Separada en BLoCs y repositories |
| **Datos** | `SupabaseService.getPersons()` | `personRepository.getPersons()` |
| **Testabilidad** | Difícil (dependencias estáticas) | Fácil (inyección de dependencias) |
| **Tipos** | `Map<String, dynamic>` | `Person`, `FaceImage` (type-safe) |
| **Actualizaciones** | Manual con `StreamProvider` | Automático con `BlocBuilder` |
| **Errores** | Manejados en UI | Estados específicos de error |
| **Escalabilidad** | Baja (todo acoplado) | Alta (capas independientes) |

---

## 🧪 Testabilidad

Con la nueva arquitectura, ahora puedes hacer tests unitarios fácilmente:

```dart
// Mock del repository
class MockPersonRepository extends Mock implements PersonRepository {}

// Test del BLoC
test('PersonsBloc emite PersonsLoaded cuando LoadPersons se dispara', () {
  final mockRepository = MockPersonRepository();
  when(mockRepository.getPersonsStream())
      .thenAnswer((_) => Stream.value([mockPerson]));
  
  final bloc = PersonsBloc(repository: mockRepository);
  
  expectLater(
    bloc.stream,
    emitsInOrder([PersonsLoading(), PersonsLoaded([mockPerson])]),
  );
  
  bloc.add(LoadPersons());
});
```

---

## 📦 Dependencias Nuevas

```yaml
dependencies:
  flutter_bloc: ^8.1.6    # Gestión de estado
  equatable: ^2.0.5       # Comparación de objetos
```

**Eliminadas:**
- ❌ `provider` (reemplazado por `flutter_bloc`)

---

## 🗑️ Archivos Eliminados (Obsoletos)

Los siguientes archivos fueron eliminados porque ahora tienen versiones actualizadas en la arquitectura BLoC:

- ❌ `lib/supabase_service.dart` → Ahora: `data/datasources/supabase_remote_datasource.dart`
- ❌ `lib/face_recognition_service.dart` → Ahora: `data/datasources/tflite_local_datasource.dart`
- ❌ `lib/home_screen.dart` → Ahora: `presentation/screens/home_screen.dart`
- ❌ `lib/persons_screen.dart` → Ahora: `presentation/screens/persons_screen.dart`
- ❌ `lib/camera_screen_real.dart` → Ahora: `presentation/screens/camera_screen_real.dart`
- ❌ `lib/add_person_screen.dart` → Ahora: `presentation/screens/add_person_screen.dart`
- ❌ `lib/person_detail_screen.dart` → Ahora: `presentation/screens/person_detail_screen.dart`

---

## ✅ Verificación de Funcionalidad

### Todas las funcionalidades anteriores se mantienen:

✅ **Reconocimiento en tiempo real** - Funciona igual, ahora con RecognitionBloc  
✅ **Lista de personas** - Actualización en tiempo real con stream de Supabase  
✅ **Añadir persona** - Valida rostros y genera embeddings antes de guardar  
✅ **Editar persona** - Actualizar nombre y descripción  
✅ **Eliminar persona** - Borra persona y todas sus imágenes  
✅ **Añadir imágenes** - Sube múltiples fotos y genera embeddings  
✅ **Eliminar imágenes** - Elimina imágenes individuales de una persona  
✅ **Captura con cámara** - Toma fotos y las añade a personas existentes  
✅ **Estadísticas** - Total de personas e imágenes en HomeScreen  

---

## 🚀 Ventajas de la Nueva Arquitectura

1. **Separación de responsabilidades** - Cada capa tiene un propósito claro
2. **Testeable** - Puedes mockear cualquier capa fácilmente
3. **Mantenible** - Cambios en una capa no afectan a las otras
4. **Escalable** - Fácil añadir nuevas features sin tocar código existente
5. **Type-safe** - Entidades tipadas en lugar de mapas genéricos
6. **Reactiva** - UI se actualiza automáticamente con cambios en los datos
7. **Profesional** - Sigue mejores prácticas de la industria

---

## 📚 Recursos para Aprender Más

- [Flutter BLoC Official Docs](https://bloclibrary.dev/)
- [Clean Architecture by Uncle Bob](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Flutter Architecture Samples](https://github.com/brianegan/flutter_architecture_samples)

---

**Fecha de migración:** 15 de diciembre de 2025  
**Versión:** 2.0.0 (Arquitectura BLoC)
