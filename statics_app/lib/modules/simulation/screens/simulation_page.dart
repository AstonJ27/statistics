import 'dart:convert';
import 'package:flutter/material.dart';

// Imports de lógica y Tema
import '../../../core/ffi/native_service.dart';
import '../../../core/theme/app_colors.dart';
import '../models/simulation_models.dart';

// Widgets Modularizados
import '../widgets/stage_input_list.dart';
import '../widgets/simulation_results.dart';

class SimulationPage extends StatefulWidget {
  const SimulationPage({super.key});
  @override
  State<SimulationPage> createState() => _SimulationPageState();
}

class _SimulationPageState extends State<SimulationPage> {
  final TextEditingController _lambdaCtrl = TextEditingController(text: "3.0");
  final TextEditingController _hoursCtrl = TextEditingController(text: "8");
  
  // Lista dinámica de etapas
  final List<StageInput> _stages = [
    StageInput(name: "Limpieza", type: Generator.normal)..p1Ctrl.text="10"..p2Ctrl.text="2",
    StageInput(name: "Lavado", type: Generator.exponential)..p1Ctrl.text="12",
    StageInput(name: "Secado", type: Generator.uniform)..p1Ctrl.text="8"..p2Ctrl.text="12",
  ];

  SimResultV2? _result;
  bool _loading = false;
  String _error = '';

  void _addStage() {
    setState(() {
      _stages.add(StageInput(name: "Etapa ${_stages.length + 1}", type: Generator.normal));
    });
  }

  void _removeStage(int index) {
    if (_stages.length > 1) {
      setState(() => _stages.removeAt(index));
    }
  }

  // Callback para cuando cambia el dropdown en el widget hijo
  void _onStageTypeChanged(StageInput stage, Generator newType) {
    setState(() {
      stage.type = newType;
    });
  }

  Future<void> _runSimulation() async {
    setState(() { _loading = true; _error = ''; _result = null; });
    try {
      double lambda = double.tryParse(_lambdaCtrl.text) ?? 3.0;
      int hours = int.tryParse(_hoursCtrl.text) ?? 8;
      
      List<Map<String, dynamic>> stagesConfig = [];
      for (var s in _stages) {
        double val1 = double.tryParse(s.p1Ctrl.text) ?? 0.0;
        double val2 = double.tryParse(s.p2Ctrl.text) ?? 0.0;
        
        String typeStr = '';
        if (s.type == Generator.normal) typeStr = 'normal';
        if (s.type == Generator.exponential) typeStr = 'exponential';
        if (s.type == Generator.uniform) typeStr = 'uniform';

        stagesConfig.add({
          "name": s.name,
          "dist_type": typeStr,
          "p1": val1, 
          "p2": val2,
        });
      }

      Map<String, dynamic> fullConfig = {
        "hours": hours,
        "lambda_arrival": lambda,
        "stages": stagesConfig
      };

      final jsonStr = await Future.delayed(Duration.zero, () => NativeService.runSimulationDynamic(fullConfig));
      final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);
      
      if (jsonMap.containsKey('error')) throw Exception(jsonMap['error']);

      setState(() {
        _result = SimResultV2.fromJson(jsonMap);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Error: ${e.toString().replaceAll('Exception:', '')}";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Layout responsive básico
    return SafeArea(
      child: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 32.0 : 16.0, vertical: 16.0),
          child: Column(
            children: [
              // 1. CONFIGURACIÓN GLOBAL
              Card(
                color: AppColors.bgCard,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Configuración General", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildInput(_lambdaCtrl, "Llegadas/Hora", icon: Icons.people)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildInput(_hoursCtrl, "Horas", icon: Icons.timer)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // 2. LISTA DE ETAPAS (Widget Modularizado)
              StageInputList(
                stages: _stages,
                onAdd: _addStage,
                onRemove: _removeStage,
                onTypeChanged: _onStageTypeChanged,
              ),

              const SizedBox(height: 20),

              // BOTÓN INICIAR
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

              if (_error.isNotEmpty) 
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(_error, style: const TextStyle(color: Colors.red)),
                ),

              // 3. RESULTADOS (Widget Modularizado)
              if (_result != null) 
                SimulationResults(
                  result: _result!, 
                  lambda: double.tryParse(_lambdaCtrl.text) ?? 3.0,
                  hours: int.tryParse(_hoursCtrl.text) ?? 8,
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, {IconData? icon}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: Colors.white38, size: 16) : null,
        filled: true,
        fillColor: Colors.black12,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }
}