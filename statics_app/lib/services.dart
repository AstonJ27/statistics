// lib/services.dart
import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'ffi_bindings.dart';
import 'models.dart';

class NativeService {
  /// Genera N muestras en la librería nativa
  /// dist: 'normal' | 'exponential' | 'uniform'
  static void generateSamples(Pointer<Double> ptr, int n, {String dist = 'normal', double param1 = 0.0, double param2 = 1.0}) {
    final seed = DateTime.now().microsecondsSinceEpoch & 0xFFFFFFFFFFFF; // fit into 64-bit
    if (dist == 'normal' && generateNormalNative != null) {
      // generate_normal(ptr, len, mean, std, seed)
      generateNormalNative!(ptr, n, param1, param2, seed.toInt());
      return;
    }
    if (dist == 'exponential' && generateExpNative != null) {
      // generate_exponential_inverse(ptr, len, beta, seed)
      generateExpNative!(ptr, n, param1, seed.toInt());
      return;
    }
    if (generateUniformNative != null) {
      // generate_uniform(ptr, len, seed)
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
    // liberar memoria en C
    freeCStringNative!(resPtr);
    final Map<String, dynamic> j = jsonDecode(jsonStr);
    return AnalyzeResult.fromJson(j);
  }

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

}
