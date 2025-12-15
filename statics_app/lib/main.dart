import 'package:flutter/material.dart';

import 'modules/descriptive/screens/descriptive_page.dart';
import 'modules/simulation/screens/simulation_page.dart';
import 'modules/montecarlo/screens/montecarlo_page.dart'; 

// --- PALETA DE COLORES (Global) ---
const int PRIMARY = 0xFF4E2ECF;       // #4E2ECF (Morado Principal)
const int BG_PRIMARY = 0xFF1D1D42;    // #1D1D42 (Fondo Oscuro)
const int GREEN = 0xFF6FCF97;         // #6FCF97 (Acción / Éxito)
const int BG_CARD = 0xFF161632;       // #161632

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StaticsApp());
}

class StaticsApp extends StatelessWidget {
  const StaticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Statics App',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(PRIMARY),
        scaffoldBackgroundColor: const Color(BG_PRIMARY),
        cardTheme: CardThemeData(
          color: const Color(BG_CARD),
          surfaceTintColor: const Color(BG_CARD),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        // Estilo base para inputs
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade200, 
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(GREEN), width: 2),
          ),
          labelStyle: TextStyle(color: Colors.grey.shade700),
          floatingLabelStyle: const TextStyle(color: Colors.white),
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),
        dividerTheme: const DividerThemeData(color: Colors.transparent),
      ),
      home: const MainNavigationShell(),
    );
  }
}

// =============================================================================
// NAVIGATOR SHELL (SIDEBAR & APPBAR)
// =============================================================================

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;

  // Lista de páginas importadas
  final List<Widget> _pages = [
    const DescriptivePage(), // Desde descriptive.dart
    const SimulationPage(),  // Desde simulation.dart
    const MonteCarloPage(),

  ];

  final List<String> _titles = [
    'Análisis Descriptivo',
    'Simulación (Colas)',
    'Laboratorio Montecarlo'
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // Cierra el Drawer
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // App Bar Global
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _titles[_selectedIndex], 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // Sidebar (Drawer)
      drawer: Drawer(
        backgroundColor: const Color(BG_CARD),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(PRIMARY)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_rounded, size: 48, color: Colors.white),
                  SizedBox(height: 10),
                  Text('Rust Stats Core', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart, color: Colors.white70),
              title: const Text('Analisis Exploratorio de Datos', style: TextStyle(color: Colors.white)),
              selected: _selectedIndex == 0,
              selectedTileColor: const Color(PRIMARY).withOpacity(0.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              leading: const Icon(Icons.local_car_wash, color: Colors.white70),
              title: const Text('Simulación Autolavado', style: TextStyle(color: Colors.white)),
              selected: _selectedIndex == 1,
              selectedTileColor: const Color(PRIMARY).withOpacity(0.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: const Icon(Icons.casino, color: Colors.white70), // Icono de dado/azar
              title: const Text('Laboratorio Montecarlo', style: TextStyle(color: Colors.white)),
              selected: _selectedIndex == 2, // <--- Índice 2
              selectedTileColor: const Color(PRIMARY).withOpacity(0.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () => _onItemTapped(2), // <--- Índice 2
            ),
          ],
        ),
      ),
      // Cuerpo dinámico
      body: _pages[_selectedIndex],
    );
  }
}