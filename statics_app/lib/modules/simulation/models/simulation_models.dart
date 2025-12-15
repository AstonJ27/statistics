// lib/modules/simulation/models/simulation_models.dart
import 'package:flutter/material.dart';

enum Generator { normal, exponential, uniform }

class SimulationResult {
  final List<HourMetrics> hours;
  final int totalCars;
  final double avgWaitTime;
  final double maxWaitTime; // <--- Nuevo campo

  SimulationResult.fromJson(Map<String, dynamic> json)
      : hours = (json['hours'] as List).map((e) => HourMetrics.fromJson(e)).toList(),
        totalCars = json['total_cars'],
        avgWaitTime = (json['avg_wait_time'] as num).toDouble(),
        maxWaitTime = (json['max_wait_time'] as num? ?? 0.0).toDouble();
}

class HourMetrics {
  final int hourIndex;
  final int estimated;
  final int served;
  final int pending;
  final int leftCount;
  final List<CarResult> cars;
  
  HourMetrics.fromJson(Map<String, dynamic> json)
      : hourIndex = json['hour_index'],
        estimated = json['estimated_arrivals'],
        served = json['served_count'],
        pending = json['pending_count'],
        leftCount = json['left_count'] ?? 0,
        cars = (json['cars'] as List? ?? []).map((e) => CarResult.fromJson(e)).toList();
}

class CarResult {
  final int id;
  final double arrivalMinute;
  final double waitTime;
  final double idleTime; // <--- Nuevo campo
  final double totalDuration;
  final bool left;
  final bool pending;
  final bool satisfied;

  CarResult.fromJson(Map<String, dynamic> json)
      : id = json['car_id'],
        arrivalMinute = (json['arrival_minute'] as num).toDouble(),
        waitTime = (json['wait_time'] as num).toDouble(),
        idleTime = (json['idle_time'] as num? ?? 0.0).toDouble(),
        totalDuration = (json['total_duration'] as num).toDouble(),
        left = json['left'],
        pending = json['pending'],
        satisfied = json['satisfied'];
}
// --- CONFIGURACIÓN (Dart -> Rust) ---

class SimulationConfig {
  final int hours;
  final double arrivalRate;
  final List<StageConfig> stages;
  final double toleranceT;
  final double abandonProbability;
  final bool stayUntilFinish;

  SimulationConfig({
    required this.hours,
    required this.arrivalRate,
    required this.stages,
    required this.toleranceT,
    required this.abandonProbability,
    required this.stayUntilFinish,
  });

  Map<String, dynamic> toJson() => {
        'hours': hours,
        'arrival_rate_lambda': arrivalRate,
        'stages': stages.map((e) => e.toJson()).toList(),
        'tolerance_t': toleranceT,
        'abandon_probability': abandonProbability,
        'stay_until_finish': stayUntilFinish,
      };
}

class StageConfig {
  final String name;
  final String distType;
  final double p1;
  final double p2;
  final int capacity;

  StageConfig({
    required this.name,
    required this.distType,
    required this.p1,
    required this.p2,
    required this.capacity,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'dist_type': distType,
        'p1': p1,
        'p2': p2,
        'capacity': capacity,
      };
}

// Clase auxiliar para manejar los controladores de texto en la UI
class StageInput {
  String name;
  Generator type;
  TextEditingController p1Ctrl; 
  TextEditingController p2Ctrl;
  TextEditingController capacityCtrl;

  StageInput({required this.name, required this.type})
      : p1Ctrl = TextEditingController(text: '10'),
        p2Ctrl = TextEditingController(text: '2'),
        capacityCtrl = TextEditingController(text: '1');
}