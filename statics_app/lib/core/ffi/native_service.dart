// lib/core/ffi/native_service.dart
import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart'; // <--- IMPORTANTE: Necesario para usar 'compute'
import 'ffi_bindings.dart';

import '../../modules/descriptive/models/descriptive_models.dart';
class NativeService {
  /// Genera N muestras en la librería nativa
  /// dist: 'normal' | 'exponential' | 'uniform'
  static void generateSamples(Pointer<Double> ptr, int n, {String dist = 'normal', double param1 = 0.0, double param2 = 1.0}) {
    final seed = DateTime.now().microsecondsSinceEpoch & 0xFFFFFFFFFFFF; // fit into 64-bit
    if (dist == 'normal' && generateNormalNative != null) {
      generateNormalNative!(ptr, n, param1, param2, seed.toInt());
      return;
    }
    if (dist == 'exponential' && generateExpNative != null) {
      generateExpNative!(ptr, n, param1, seed.toInt());
      return;
    }
    if (generateUniformNative != null) {
      generateUniformNative!(ptr, n, seed.toInt());
      return;
    }
    throw Exception('No native generator disponible (revisa libstat_core.so y nombres exportados).');
  }

  /// Llama a analyze_distribution_json(ptr, n, h_round, forced_k) y parsea resultados
  static AnalyzeResult analyzeDistribution(
    Pointer<Double> ptr, 
    int n, 
    {
      bool hRound = true, 
      int forcedK = 0,
      double forcedMin = double.nan,
      double forcedMax = double.nan
    }
  ) {
    // Reutilizamos el método Raw para no duplicar lógica
    final jsonStr = analyzeDistributionRaw(ptr, n, hRound: hRound, forcedK: forcedK, forcedMin: forcedMin, forcedMax: forcedMax);
    final Map<String, dynamic> j = jsonDecode(jsonStr);
    return AnalyzeResult.fromJson(j);
  }

  /// NUEVO MÉTODO: Obtiene el JSON crudo (String) desde Rust.
  /// Útil para guardar el resultado en base de datos sin serializar/deserializar objetos.
  static String analyzeDistributionRaw(
    Pointer<Double> ptr, 
    int n, 
    {
      bool hRound = true, 
      int forcedK = 0,
      double forcedMin = double.nan,
      double forcedMax = double.nan
    }
  ) {
    if (analyzeDistributionNative == null || freeCStringNative == null) {
      throw Exception('Bindings no disponibles.');
    }
    
    final int hr = hRound ? 1 : 0;
    
    // Pasamos forcedK al nativo
    final Pointer<Utf8> resPtr = analyzeDistributionNative!(ptr, n, hr, forcedK, forcedMin, forcedMax);
    
    if (resPtr.address == 0) {
      throw Exception('analyze_distribution_json devolvió NULL');
    }
    
    final jsonStr = resPtr.toDartString();
    freeCStringNative!(resPtr);
    return jsonStr;
  }

  // --- Simulacion --
  /// Ejecuta la simulación dinámica (Multietapa + Concurrencia)
  /// Recibe un Map (configuración) -> Serializa a JSON -> Envía a Rust -> Retorna JSON String
  static Future<String> simulateCarwashDynamic(Map<String, dynamic> config) async {
    // Verificamos que el binding exista (definido en ffi_bindings.dart)
    if (simulateDynamicNative == null || freeCStringNative == null) {
      throw Exception('Binding simulate_carwash_dynamic no encontrado en ffi_bindings.dart');
    }
    
    // 1. Serializar el mapa a JSON string
    final jsonString = jsonEncode(config);
    
    // 2. Convertir String Dart -> Puntero C (UTF-8)
    final ptrName = jsonString.toNativeUtf8();
    
    try {
      // 3. Llamar a Rust
      // simulateDynamicNative debe estar mapeado a "simulate_carwash_dynamic"
      final ptr = simulateDynamicNative!(ptrName);
      
      if (ptr.address == 0) {
        return "{\"error\": \"Error interno en Rust: Puntero nulo retornado\"}";
      }
      
      // 4. Convertir Puntero C -> String Dart
      final resJson = ptr.toDartString();
      
      // 5. Liberar memoria del string retornado por Rust
      freeCStringNative!(ptr);
      
      return resJson;
    } finally {
      // 6. Liberar memoria del input (jsonString) que creamos con malloc
      calloc.free(ptrName);
    }
  }

  static String runSimulationDynamic(Map<String, dynamic> config) {
    if (simulateDynamicNative == null || freeCStringNative == null) {
      throw Exception('Binding simulate_carwash_dynamic no encontrado');
    }
    
    // Serializar el mapa a JSON string
    final jsonString = jsonEncode(config);
    final ptrName = jsonString.toNativeUtf8();
    
    try {
      final ptr = simulateDynamicNative!(ptrName);
      if (ptr.address == 0) return "{\"error\": \"Error interno en Rust\"}";
      
      final resJson = ptr.toDartString();
      freeCStringNative!(ptr);
      return resJson;
    } finally {
      calloc.free(ptrName);
    }
  }

  /// Copia una lista de Dart a un puntero en el Heap nativo (para pasar a Rust)
  static Pointer<Double> copyDataToRust(List<double> data) {
    final ptr = calloc<Double>(data.length);
    for (int i = 0; i < data.length; i++) {
      ptr[i] = data[i];
    }
    return ptr;
  }

  // Agrega esto dentro de la clase NativeService
  static Future<String> runMonteCarlo(Map<String, dynamic> config) async {
    final jsonString = jsonEncode(config);
    // Usamos compute como en los otros métodos
    return await compute(_runMonteCarloIsolate, jsonString);
  }

  // Dentro de la clase NativeService:
  static Future<String> calculateInverseCdf(Map<String, dynamic> req) async {
    final jsonStr = jsonEncode(req);
    return await compute(_runInverseCdfIsolate, jsonStr);
  }

  /// Libera el puntero de datos (importante para evitar fugas de memoria)
  static void freeDoublePtr(Pointer<Double> ptr) {
    calloc.free(ptr);
  }
}

// Debe estar fuera de la clase NativeService para que 'compute' la pueda llamar
String _runMonteCarloIsolate(String jsonConfig) {
  // 1. Convertir String Dart -> Puntero C
  final ptr = jsonConfig.toNativeUtf8();
  
  try {
    // 2. Llamar a la función nativa (Importada directamente de ffi_bindings.dart)
    if (simulateMonteCarloNative == null) {
      return jsonEncode({"error": "Función nativa simulation_montecarlo no encontrada"});
    }
    
    final resultPtr = simulateMonteCarloNative!(ptr);
    
    // 3. Convertir Puntero C -> String Dart
    final resultJson = resultPtr.toDartString();
    
    // 4. Liberar memoria del resultado en Rust
    if (freeCStringNative != null) {
      freeCStringNative!(resultPtr);
    }
    
    return resultJson;
  } finally {
    // 5. Liberar memoria del input
    calloc.free(ptr);
  }
}

// Fuera de la clase (Top Level), al final del archivo:
String _runInverseCdfIsolate(String jsonConfig) {
  final ptr = jsonConfig.toNativeUtf8();
  try {
    if (calculateInverseCdfNative == null) return jsonEncode({"error": "Binding calculate_inverse_cdf not found"});
    final resPtr = calculateInverseCdfNative!(ptr);
    final resJson = resPtr.toDartString();
    if (freeCStringNative != null) freeCStringNative!(resPtr);
    return resJson;
  } finally {
    calloc.free(ptr);
  }
}