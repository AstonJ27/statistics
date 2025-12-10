// lib/modules/simulation/models/simulation_models.dart
import 'package:flutter/material.dart'; // Necesario para TextEditingController

enum Generator { normal, exponential, uniform }

//class AppColors {
//  // Colores principales
//  static const Color primary = Color(0xFF4E2ECF);
//  static const Color bgPrimary = Color(0xFF1D1D42);
//  static const Color green = Color(0xFF6FCF97);
//  static const Color bgCard = Color(0xFF161632);
//  
//  // Helpers opcionales
//  static const Color textWhite = Colors.white;
//  static const Color textWhite70 = Colors.white70;
//}
// --- SIMULATION MODELS ---
 
class HourMetrics {
  final int hourIndex;
  final int estimated; // Poisson
  final int served;    // Satisfechos en tiempo
  final int pending;   // Se pasaron de hora
  final List<CarResult> cars;

  HourMetrics.fromJson(Map<String, dynamic> json)
      : hourIndex = json['hour_index'],
        estimated = json['estimated_arrivals'],
        served = json['served_count'],
        pending = json['pending_count'],
        cars = (json['cars'] as List).map((e) => CarResult.fromJson(e)).toList();
}

class CarResult {
  final int id;
  final double arrival;
  final double start;
  final double end;
  final double total;
  final double wait;
  final List<double> stageDurations;
  final bool left; // nuevo

  CarResult.fromJson(Map<String, dynamic> json)
      : id = json['car_id'],
        arrival = (json['arrival_time_abs'] as num).toDouble(),
        start = (json['start_time'] as num).toDouble(),
        end = (json['end_time'] as num).toDouble(),
        total = (json['total_duration'] as num).toDouble(),
        wait = (json['wait_time'] as num).toDouble(),
        stageDurations = (json['stage_durations'] != null)
            ? (json['stage_durations'] as List).map((e) => (e as num).toDouble()).toList()
            : <double>[],
        left = json['left'] != null ? (json['left'] as bool) : false;
}

class SimResultV2 {
  final List<HourMetrics> hours;
  final int totalCars;
  final double avgWaitTime;

  SimResultV2.fromJson(Map<String, dynamic> json)
      : hours = (json['hours'] as List).map((e) => HourMetrics.fromJson(e)).toList(),
        totalCars = json['total_cars'],
        avgWaitTime = (json['avg_wait_time'] as num).toDouble();
}

class StageInput {
  String name;
  Generator type;
  TextEditingController p1Ctrl; 
  TextEditingController p2Ctrl;

  StageInput({required this.name, required this.type})
      : p1Ctrl = TextEditingController(),
        p2Ctrl = TextEditingController();
}