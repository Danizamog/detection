import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'camera_screen_real.dart';
import 'persons_screen.dart';
import 'add_person_screen.dart';
import 'person_detail_screen.dart';
import 'supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await SupabaseService.initialize();
    print('✅ Aplicación inicializada correctamente');
  } catch (e) {
    print('❌ Error inicializando la aplicación: $e');
  }
  
  runApp(const FacialRecognitionApp());
}

class FacialRecognitionApp extends StatelessWidget {
  const FacialRecognitionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        StreamProvider<List<Map<String, dynamic>>>(
          create: (_) => SupabaseService.getPersonsStream(),
          initialData: const [],
          catchError: (_, error) {
            print('⚠️ Error en stream de personas: $error');
            return const [];
          },
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
  void dispose() {
    SupabaseService.dispose();
    super.dispose();
  }

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