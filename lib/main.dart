import 'package:facial_recognition/presentation/screens/error_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/camera_screen_real.dart';
import 'presentation/screens/persons_screen.dart';
import 'presentation/screens/add_person_screen.dart';
import 'presentation/screens/person_detail_screen.dart';
import 'data/datasources/supabase_remote_datasource.dart';
import 'data/datasources/tflite_local_datasource.dart';
import 'data/repositories/person_repository_impl.dart';
import 'data/repositories/face_recognition_repository_impl.dart';
import 'presentation/bloc/persons/persons_bloc.dart';
import 'presentation/bloc/persons/persons_event.dart';
import 'presentation/bloc/recognition/recognition_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Inicializar Supabase
    await Supabase.initialize(
      url: 'https://uvdiwniodvndsxembmxz.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV2ZGl3bmlvZHZuZHN4ZW1ibXh6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ4ODYzMDYsImV4cCI6MjA4MDQ2MjMwNn0.qBgh6Xjfi-mnSxES_4bVwrgQPxtqBrIqx8ryWPAoY4U',
    );

    // Inicializar TFLite
    final tfliteDataSource = TFliteLocalDataSource();
    await tfliteDataSource.initialize();

    print('✅ Aplicación inicializada correctamente');

    runApp(FacialRecognitionApp(
      supabaseClient: Supabase.instance.client,
      tfliteDataSource: tfliteDataSource,
    ));
  } catch (e) {
    print('❌ Error inicializando la aplicación: $e');
    runApp(const ErrorApp());
  }
}

class FacialRecognitionApp extends StatelessWidget {
  final SupabaseClient supabaseClient;
  final TFliteLocalDataSource tfliteDataSource;

  const FacialRecognitionApp({
    super.key,
    required this.supabaseClient,
    required this.tfliteDataSource,
  });

  @override
  Widget build(BuildContext context) {
    // Crear datasources
    final supabaseDataSource = SupabaseRemoteDataSource(supabaseClient);

    // Crear repositorios
    final personRepository = PersonRepositoryImpl(
      remoteDataSource: supabaseDataSource,
      localDataSource: tfliteDataSource,
    );

    final faceRecognitionRepository = FaceRecognitionRepositoryImpl(
      localDataSource: tfliteDataSource,
      remoteDataSource: supabaseDataSource,
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              PersonsBloc(repository: personRepository)..add(LoadPersons()),
        ),
        BlocProvider(
          create: (context) =>
              RecognitionBloc(repository: faceRecognitionRepository),
        ),
      ],
      child: MaterialApp(
        title: 'Reconocimiento Facial Inteligente',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 2,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          // CORREGIDO: La propiedad correcta es cardTheme (con "c" minúscula)
          // y el tipo es CardTheme, no CardThemeData
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(8),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 4,
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.white,
            selectedItemColor: Colors.blue,
            unselectedItemColor: Colors.grey,
            selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
            type: BottomNavigationBarType.fixed,
            elevation: 8,
          ),
        ),
        home: const MainNavigationScreen(),
        debugShowCheckedModeBanner: false,
        routes: {
          '/home': (context) => const HomeScreen(),
          '/camera': (context) => const CameraScreenReal(),
          '/persons': (context) => const PersonsScreen(),
          '/add-person': (context) => const AddPersonScreen(),
          '/person-detail': (context) => const PersonDetailScreen(),
        },
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const CameraScreenReal(),
    const PersonsScreen(),
  ];

  final List<String> _titles = [
    'Inicio',
    'Reconocimiento',
    'Personas',
  ];

  final List<IconData> _icons = [
    Icons.home,
    Icons.camera_alt,
    Icons.people,
  ];

  final List<IconData> _outlinedIcons = [
    Icons.home_outlined,
    Icons.camera_alt_outlined,
    Icons.people_outline,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: _currentIndex == 2
            ? [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 28),
                  onPressed: () {
                    Navigator.pushNamed(context, '/add-person');
                  },
                  tooltip: 'Añadir nueva persona',
                ),
                const SizedBox(width: 10),
              ]
            : null,
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: List.generate(_screens.length, (index) {
          return BottomNavigationBarItem(
            icon: Icon(_outlinedIcons[index]),
            activeIcon: Icon(_icons[index]),
            label: _titles[index],
          );
        }),
      ),
    );
  }
}
