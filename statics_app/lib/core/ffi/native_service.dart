// lib/core/ffi/native_service.dart
import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'ffi_bindings.dart';

// CORRECCIÓN: Importar el modelo desde su nueva ubicación en el módulo descriptivo
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

  /// Llama a analyze_distribution_json(ptr, n, h_round) y parsea resultados
  static AnalyzeResult analyzeDistribution(Pointer<Double> ptr, int n, {bool hRound = true}) {
    if (analyzeDistributionNative == null || freeCStringNative == null) {
      throw Exception('El binding nativo para analyze_distribution_json o free_c_string no está disponible.');
    }
    final int hr = hRound ? 1 : 0;
    final Pointer<Utf8> resPtr = analyzeDistributionNative!(ptr, n, hr);
    if (resPtr.address == 0) {
      throw Exception('analyze_distribution_json devolvió NULL');
    }
    final jsonStr = resPtr.toDartString();
    freeCStringNative!(resPtr);
    final Map<String, dynamic> j = jsonDecode(jsonStr);
    return AnalyzeResult.fromJson(j);
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
}