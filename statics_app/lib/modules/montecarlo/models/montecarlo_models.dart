import 'package:flutter/material.dart';

enum McDistType { normal, exponential, uniform }

class McVariable {
  String name;
  McDistType type;
  double param1;
  double param2;
  double multiplier;

  McVariable({
    required this.name,
    this.type = McDistType.normal,
    this.param1 = 10,
    this.param2 = 4,
    this.multiplier = 1.0,
  });

  Map<String, dynamic> toJson() {
    Map<String, dynamic> distMap = {};
    if (type == McDistType.normal) {
      distMap = {'Normal': {'mean': param1, 'variance': param2}};
    }
    if (type == McDistType.exponential) {
      distMap = {'Exponential': {'beta': param1}};
    }
    if (type == McDistType.uniform) {
      distMap = {'Uniform': {'min': param1, 'max': param2}};
    }

    return {
      'name': name,
      'multiplier': multiplier,
      'distribution': distMap
    };
  }
}

// NUEVA CLASE PARA EL DETALLE DE CADA ITERACIÓN
class IterationDetail {
  final List<double> variables;
  final double total;

  IterationDetail.fromJson(Map<String, dynamic> json)
      : variables = (json['variables'] as List).map((e) => (e as num).toDouble()).toList(),
        total = (json['total'] as num).toDouble();
}

class McResult {
  final double mean;
  final double stdDev;
  final double min;
  final double max;
  
  // CAMBIO CLAVE: Lista de IterationDetail, no de double
  final List<IterationDetail> preview; 
  
  final double? probability;
  final double? expectedCost;
  final int? successCount;
  final int iterations;

  McResult.fromJson(Map<String, dynamic> json)
      : mean = (json['mean'] as num).toDouble(),
        stdDev = (json['std_dev'] as num).toDouble(),
        min = (json['min'] as num).toDouble(),
        max = (json['max'] as num).toDouble(),
        // CAMBIO CLAVE: Mapeo correcto de la lista de objetos
        preview = (json['samples_preview'] as List)
            .map((e) => IterationDetail.fromJson(e))
            .toList(),
        probability = (json['probability'] as num?)?.toDouble(),
        expectedCost = (json['expected_cost'] as num?)?.toDouble(),
        successCount = json['success_count'],
        iterations = json['iterations'];
}