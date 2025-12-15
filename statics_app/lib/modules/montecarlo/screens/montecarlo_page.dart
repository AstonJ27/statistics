import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/ffi/native_service.dart';
import '../../../core/theme/app_colors.dart';
import '../models/montecarlo_models.dart';
import '../widgets/variable_list_widget.dart';

class MonteCarloPage extends StatefulWidget {
  const MonteCarloPage({super.key});

  @override
  State<MonteCarloPage> createState() => _MonteCarloPageState();
}

class _MonteCarloPageState extends State<MonteCarloPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Estado General
  final TextEditingController _nSimsCtrl = TextEditingController(text: "10000");
  final List<McVariable> _variables = [
    McVariable(name: "Variable 1", type: McDistType.normal, param1: 10, param2: 2),
  ];
  
  // Estado Probabilidad (Tab 2)
  final TextEditingController _thresholdCtrl = TextEditingController(text: "6");
  final TextEditingController _costCtrl = TextEditingController(text: "75");
  final TextEditingController _popCtrl = TextEditingController(text: "50000");
  String _operator = "<=";

  McResult? _result;
  bool _loading = false;
  String _error = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Limpiar resultados al cambiar de pestaña para evitar confusiones
    _tabController.addListener(() {
      if(_tabController.indexIsChanging) setState(() { _result = null; _error = ""; });
    });
  }

  void _addVar() => setState(() => _variables.add(McVariable(name: "Var ${_variables.length+1}")));
  void _removeVar(int i) { if(_variables.length > 0) setState(() => _variables.removeAt(i)); } // Permitimos borrar todas si se quiere

  Future<void> _run() async {
    setState(() { _loading = true; _error = ""; _result = null; });
    try {
      int n = int.tryParse(_nSimsCtrl.text) ?? 10000;
      bool isProbMode = _tabController.index == 1;

      if (_variables.isEmpty) throw Exception("Agrega al menos una variable.");

      Map<String, dynamic> analysis = {};
      if (isProbMode) {
        analysis = {
          "mode_type": "Probability",
          "params": {
            "threshold": double.parse(_thresholdCtrl.text),
            "operator": _operator,
            "cost_per_event": double.parse(_costCtrl.text),
            "population_size": double.parse(_popCtrl.text),
          }
        };
      } else {
        analysis = {"mode_type": "Aggregation", "params": null};
      }

      Map<String, dynamic> config = {
        "n_simulations": n,
        "variables": _variables.map((v) => v.toJson()).toList(),
        "analysis": analysis
      };

      final jsonStr = await Future.delayed(Duration.zero, () => NativeService.runMonteCarlo(config));
      final jsonMap = jsonDecode(jsonStr);
      
      if (jsonMap.containsKey('error')) throw Exception(jsonMap['error']);

      setState(() {
        _result = McResult.fromJson(jsonMap);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString().replaceAll("Exception:", ""); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text("Laboratorio Montecarlo"),
        backgroundColor: AppColors.bgCard,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.green,
          labelColor: AppColors.green,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Acumulador (Suma)", icon: Icon(Icons.functions)),
            Tab(text: "Probabilidad / Riesgo", icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Configuración de Variables (Común)
            VariableListWidget(
              variables: _variables, 
              onAdd: _addVar, 
              onRemove: _removeVar
            ),
            
            const SizedBox(height: 16),
            
            // 2. Configuración Específica (Según Tab)
            AnimatedBuilder(
              animation: _tabController,
              builder: (ctx, _) => _tabController.index == 1 
                  ? _buildProbConfig() 
                  : const SizedBox.shrink(), // En modo suma no hay extra config
            ),
            
            const SizedBox(height: 16),
            
            // 3. Input Simulaciones y Botón
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nSimsCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Iteraciones (N)",
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true, fillColor: AppColors.bgCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.refresh, color: Colors.white38),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56, // Altura estándar del TextField
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _run,
                      icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow),
                      label: const Text("SIMULAR"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: AppColors.bgPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_error.isNotEmpty) 
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(_error, style: const TextStyle(color: Colors.red)),
              ),

            // 4. Resultados
            if (_result != null) _buildResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildProbConfig() {
    return Card(
      color: Colors.blueGrey.shade900.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withOpacity(0.1))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Configuración de Riesgo (Problema 2)", style: TextStyle(color: AppColors.green, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(children: [
              const Text("Condición: Suma ", style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _operator,
                dropdownColor: AppColors.bgCard,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                items: ["<", "<=", ">", ">="].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _operator = v!),
              ),
              const SizedBox(width: 8),
              Expanded(child: _simpleInput(_thresholdCtrl, "Valor Límite")),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _simpleInput(_costCtrl, "Costo Unitario (\$)")),
              const SizedBox(width: 12),
              Expanded(child: _simpleInput(_popCtrl, "Población Total")),
            ])
          ],
        ),
      ),
    );
  }

  Widget _simpleInput(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        isDense: true,
        filled: true, fillColor: Colors.black12,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)
      ),
      keyboardType: TextInputType.number,
    );
  }

  Widget _buildResultCard() {
    bool isProbMode = _tabController.index == 1;
    
    return Container(
      margin: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Resultados del Análisis", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          // Tarjeta Principal
          Card(
            color: AppColors.bgCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _rowBigStat("Promedio (Media)", _result!.mean.toStringAsFixed(4)),
                  const Divider(color: Colors.white10, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _colStat("Desviación Std.", _result!.stdDev.toStringAsFixed(4)),
                      _colStat("Mínimo", _result!.min.toStringAsFixed(2)),
                      _colStat("Máximo", _result!.max.toStringAsFixed(2)),
                    ],
                  ),
                  
                  if (isProbMode && _result!.probability != null) ...[
                    const Divider(color: Colors.white10, height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          _rowBigStat("Probabilidad", "${(_result!.probability! * 100).toStringAsFixed(2)} %", color: Colors.yellowAccent),
                          const SizedBox(height: 8),
                          _rowBigStat("Costo Esperado", "\$ ${_result!.expectedCost!.toStringAsFixed(2)}", color: Colors.redAccent),
                          const SizedBox(height: 8),
                          Text(
                            "Eventos: ${_result!.successCount} de ${_result!.iterations}", 
                            style: const TextStyle(color: Colors.white54, fontSize: 12)
                          ),
                        ],
                      ),
                    )
                  ]
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          const Text("Muestra de datos (Primeros 10 simulados):", style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _result!.preview.take(10).map((e) => Chip(
              label: Text(e.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.black26,
            )).toList(),
          )
        ],
      ),
    );
  }

  Widget _rowBigStat(String label, String val, {Color color = Colors.white}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }

  Widget _colStat(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}