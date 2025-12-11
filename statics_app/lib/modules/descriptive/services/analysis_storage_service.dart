// lib/modules/descriptive/services/analysis_storage_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/descriptive_models.dart';
import '../widgets/data_input_forms.dart'; // Necesitamos el Enum InputMode

class SavedAnalysis {
  final String id;
  final String name;
  final DateTime date;
  final InputMode mode; // generator, csv, table...
  final Map<String, dynamic> inputs; // Configuración guardada (ej. tabla llena, o parámetros del generador)
  final Map<String, dynamic> rawResult; // El JSON que devolvió Rust

  SavedAnalysis({
    required this.id,
    required this.name,
    required this.date,
    required this.mode,
    required this.inputs,
    required this.rawResult,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'date': date.toIso8601String(),
    'mode': mode.index, // Guardamos índice del enum
    'inputs': inputs,
    'raw_result': rawResult,
  };

  factory SavedAnalysis.fromJson(Map<String, dynamic> json) {
    return SavedAnalysis(
      id: json['id'],
      name: json['name'],
      date: DateTime.parse(json['date']),
      mode: InputMode.values[json['mode']],
      inputs: Map<String, dynamic>.from(json['inputs'] ?? {}),
      rawResult: Map<String, dynamic>.from(json['raw_result'] ?? {}),
    );
  }

  // Helper para convertir el JSON crudo en objeto Dart usable en la UI
  AnalyzeResult get parsedResult => AnalyzeResult.fromJson(rawResult);
}

class AnalysisStorageService {
  static const String _key = 'saved_analyses_v1';
  static const int _maxLimit = 20;

  /// Obtener todos los análisis guardados
  Future<List<SavedAnalysis>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final String? listString = prefs.getString(_key);
    if (listString == null) return [];

    final List<dynamic> jsonList = jsonDecode(listString);
    return jsonList.map((e) {
      try {
        return SavedAnalysis.fromJson(e);
      } catch (_) {
        return null;
      }
    }).whereType<SavedAnalysis>().toList();
  }

  /// Guardar un nuevo análisis (retorna String con error si falla, null si éxito)
  Future<String?> saveAnalysis(SavedAnalysis item) async {
    final prefs = await SharedPreferences.getInstance();
    List<SavedAnalysis> current = await getAll();

    if (current.length >= _maxLimit) {
      return "Límite alcanzado (20). Elimina un análisis antiguo para continuar.";
    }

    // Insertar al principio de la lista (más reciente primero)
    current.insert(0, item);

    List<Map<String, dynamic>> saveList = current.map((a) => a.toJson()).toList();
    await prefs.setString(_key, jsonEncode(saveList));
    return null; // Éxito
  }

  /// Eliminar un análisis por ID
  Future<void> deleteAnalysis(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<SavedAnalysis> current = await getAll();
    
    current.removeWhere((element) => element.id == id);
    
    List<Map<String, dynamic>> saveList = current.map((a) => a.toJson()).toList();
    await prefs.setString(_key, jsonEncode(saveList));
  }
}