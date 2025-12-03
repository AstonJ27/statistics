// lib/ffi_bindings.dart
import 'dart:ffi';
import 'package:ffi/ffi.dart';

typedef GenerateUniformNative = Void Function(Pointer<Double>, IntPtr, Uint64);
typedef GenerateUniformDart = void Function(Pointer<Double>, int, int);

typedef GenerateNormalNative = Void Function(Pointer<Double>, IntPtr, Double, Double, Uint64);
typedef GenerateNormalDart = void Function(Pointer<Double>, int, double, double, int);

typedef GenerateExpNative = Void Function(Pointer<Double>, IntPtr, Double, Uint64);
typedef GenerateExpDart = void Function(Pointer<Double>, int, double, int);

// Native: Pointer<Utf8> analyze_distribution_json(Pointer<Double> ptr, IntPtr len, Int32 h_round)
typedef AnalyzeNative = Pointer<Utf8> Function(Pointer<Double>, IntPtr, Int32);
typedef AnalyzeDart = Pointer<Utf8> Function(Pointer<Double>, int, int);

typedef FreeNative = Void Function(Pointer<Utf8>);
typedef FreeDart = void Function(Pointer<Utf8>);

final DynamicLibrary nativeLib = DynamicLibrary.open('libstat_core.so');

GenerateUniformDart? _lookupGenerateUniform() {
  try {
    return nativeLib.lookupFunction<GenerateUniformNative, GenerateUniformDart>('generate_uniform');
  } catch (_) {
    return null;
  }
}
final GenerateUniformDart? generateUniformNative = _lookupGenerateUniform();

GenerateNormalDart? _lookupGenerateNormal() {
  try {
    return nativeLib.lookupFunction<GenerateNormalNative, GenerateNormalDart>('generate_normal');
  } catch (_) {
    return null;
  }
}
final GenerateNormalDart? generateNormalNative = _lookupGenerateNormal();

GenerateExpDart? _lookupGenerateExp() {
  try {
    return nativeLib.lookupFunction<GenerateExpNative, GenerateExpDart>('generate_exponential_inverse');
  } catch (_) {
    return null;
  }
}
final GenerateExpDart? generateExpNative = _lookupGenerateExp();

AnalyzeDart? _lookupAnalyze() {
  try {
    return nativeLib.lookupFunction<AnalyzeNative, AnalyzeDart>('analyze_distribution_json');
  } catch (_) {
    return null;
  }
}
final AnalyzeDart? analyzeDistributionNative = _lookupAnalyze();

FreeDart? _lookupFree() {
  try {
    return nativeLib.lookupFunction<FreeNative, FreeDart>('free_c_string');
  } catch (_) {
    return null;
  }
}
final FreeDart? freeCStringNative = _lookupFree();

// Agrega los typedefs para la nueva función
typedef SimulateCarwashNative = Pointer<Utf8> Function(Int32, Double);
typedef SimulateCarwashDart = Pointer<Utf8> Function(int, double);

// Agrega el lookup
SimulateCarwashDart? _lookupSimulateCarwash() {
  try {
    return nativeLib.lookupFunction<SimulateCarwashNative, SimulateCarwashDart>('simulate_carwash_json');
  } catch (_) {
    return null;
  }
}
final SimulateCarwashDart? simulateCarwashNative = _lookupSimulateCarwash();