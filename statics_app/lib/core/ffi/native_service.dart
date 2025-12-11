// lib/core/ffi/native_service.dart
import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
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
  static String simulateCarwash(int hours, double lambda) {
    if (simulateCarwashNative == null || freeCStringNative == null) {
      throw Exception('Binding simulate_carwash_json no encontrado');
    }

    final ptr = simulateCarwashNative!(hours, lambda);
    if (ptr.address == 0) return "{}";

    final jsonStr = ptr.toDartString();
    freeCStringNative!(ptr);
    return jsonStr;
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

  /// Libera el puntero de datos (importante para evitar fugas de memoria)
  static void freeDoublePtr(Pointer<Double> ptr) {
    calloc.free(ptr);
  }
}