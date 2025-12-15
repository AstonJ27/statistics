// lib/modules/simulation/screens/simulation_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../core/ffi/native_service.dart';
import '../../../core/theme/app_colors.dart';
import '../models/simulation_models.dart';

// Widgets
import '../widgets/stage_input_list.dart';
import '../widgets/simulation_config_card.dart';
import '../widgets/simulation_kpi_card.dart';
import '../widgets/server_stats_card.dart';
import '../widgets/simulation_tables_card.dart'; // <--- Importamos el nuevo widget

class SimulationPage extends StatefulWidget {
  const SimulationPage({super.key});
  @override
  State<SimulationPage> createState() => _SimulationPageState();
}

class _SimulationPageState extends State<SimulationPage> {
  final _hoursCtrl = TextEditingController(text: "8");
  final _lambdaCtrl = TextEditingController(text: "15");
  final _toleranceCtrl = TextEditingController(text: "15");
  final _probAbandonCtrl = TextEditingController(text: "0.5");
  bool _allowAbandon = true;

  final List<StageInput> _stages = [
    StageInput(name: "Estación 1", type: Generator.normal)..p1Ctrl.text="5",
  ];

  SimulationResult? _result;
  bool _loading = false;
  String _error = '';

  void _addStage() => setState(() => _stages.add(StageInput(name: "Estación ${_stages.length + 1}", type: Generator.normal)));
  void _removeStage(int index) { if (_stages.length > 1) setState(() => _stages.removeAt(index)); }

  Future<void> _runSimulation() async {
    setState(() { _loading = true; _error = ''; _result = null; });
    try {
      double lambda = double.tryParse(_lambdaCtrl.text) ?? 15.0;
      int hours = int.tryParse(_hoursCtrl.text) ?? 8;
      
      List<Map<String, dynamic>> stagesConfig = _stages.map((s) {
        String typeStr = s.type == Generator.exponential ? 'exponential' : (s.type == Generator.uniform ? 'uniform' : 'normal');
        return {
          "name": s.name,
          "dist_type": typeStr,
          "p1": double.tryParse(s.p1Ctrl.text) ?? 1.0, 
          "p2": double.tryParse(s.p2Ctrl.text) ?? 0.0,
        };
      }).toList();

      Map<String, dynamic> fullConfig = {
        "hours": hours,
        "lambda_arrival": lambda,
        "tolerance": double.tryParse(_toleranceCtrl.text) ?? 15.0,
        "abandon_prob": _allowAbandon ? (double.tryParse(_probAbandonCtrl.text) ?? 0.5) : 0.0,
        "stages": stagesConfig
      };

      final jsonStr = await Future.delayed(Duration.zero, () => NativeService.runSimulationDynamic(fullConfig));
      final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);
      
      if (jsonMap.containsKey('error')) throw Exception(jsonMap['error']);

      setState(() {
        _result = SimulationResult.fromJson(jsonMap);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = "Error: ${e.toString().replaceAll('Exception:', '')}"; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 32.0 : 16.0, vertical: 16.0),
          child: Column(
            children: [
              SimulationConfigCard(
                hoursCtrl: _hoursCtrl,
                lambdaCtrl: _lambdaCtrl,
                toleranceCtrl: _toleranceCtrl,
                probAbandonCtrl: _probAbandonCtrl,
                allowAbandon: _allowAbandon,
                onAbandonChanged: (v) => setState(() => _allowAbandon = v),
              ),
              const SizedBox(height: 10),
              StageInputList(
                stages: _stages,
                onAdd: _addStage,
                onRemove: _removeStage,
                onTypeChanged: (_, __) => setState(() {}),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: AppColors.bgPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _loading ? null : _runSimulation,
                  icon: _loading ? const SizedBox(height:20, width:20, child: CircularProgressIndicator()) : const Icon(Icons.play_circle_fill),
                  label: const Text("INICIAR SIMULACIÓN"),
                ),
              ),
              if (_error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(_error, style: const TextStyle(color: Colors.red))),
              
              if (_result != null) ...[
                 const SizedBox(height: 20),
                 // 1. Tablas (Recuperadas del repo original)
                 SimulationTablesCard(
                   lambda: double.tryParse(_lambdaCtrl.text) ?? 15.0, 
                   hours: int.tryParse(_hoursCtrl.text) ?? 8
                 ),
                 const SizedBox(height: 10),
                 // 2. KPIs (Con gráficos y métricas nuevas)
                 SimulationKpiCard(result: _result!),
                 const SizedBox(height: 10),
                 // 3. Detalles (Con lista de ocio/espera)
                 ServerStatsCard(result: _result!),
              ]
            ],
          ),
        );
      }),
    );
  }
}