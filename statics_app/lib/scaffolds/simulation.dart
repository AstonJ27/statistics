import 'dart:convert';
import 'package:flutter/material.dart';

// Imports de lógica
import '../services.dart';
import '../models.dart';

// --- PALETA DE COLORES (Local) ---
const int PRIMARY = 0xFF4E2ECF;
const int BG_PRIMARY = 0xFF1D1D42;
const int GREEN = 0xFF6FCF97;
const int BG_CARD = 0xFF161632;

// Usamos el mismo enum Generator para reutilizar conceptos
enum Generator { normal, exponential, uniform }

// Clase auxiliar para manejar la entrada de las etapas dinámicas
class StageInput {
  String name;
  Generator type;
  TextEditingController p1Ctrl; // Media, Beta, Min
  TextEditingController p2Ctrl; // Varianza, -, Max

  StageInput({required this.name, required this.type})
      : p1Ctrl = TextEditingController(),
        p2Ctrl = TextEditingController();
}

class SimulationPage extends StatefulWidget {
  const SimulationPage({super.key});
  @override
  State<SimulationPage> createState() => _SimulationPageState();
}

class _SimulationPageState extends State<SimulationPage> {
  final TextEditingController _lambdaCtrl = TextEditingController(text: "3.0");
  final TextEditingController _hoursCtrl = TextEditingController(text: "8");
  
  // Lista dinámica de etapas con valores iniciales
  final List<StageInput> _stages = [
    StageInput(name: "Limpieza", type: Generator.normal)..p1Ctrl.text="10"..p2Ctrl.text="2", // Varianza 2
    StageInput(name: "Lavado", type: Generator.exponential)..p1Ctrl.text="12", // Beta 12
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

  Future<void> _runSimulation() async {
    setState(() { _loading = true; _error = ''; _result = null; });
    try {
      double lambda = double.tryParse(_lambdaCtrl.text) ?? 3.0;
      int hours = int.tryParse(_hoursCtrl.text) ?? 8;
      
      // Construir el objeto de configuración JSON para Rust
      List<Map<String, dynamic>> stagesConfig = [];
      for (var s in _stages) {
        double val1 = double.tryParse(s.p1Ctrl.text) ?? 0.0;
        double val2 = double.tryParse(s.p2Ctrl.text) ?? 0.0;
        
        String typeStr = '';
        if (s.type == Generator.normal) typeStr = 'normal';
        if (s.type == Generator.exponential) typeStr = 'exponential';
        if (s.type == Generator.uniform) typeStr = 'uniform';

        // Nota: Enviamos los valores tal cual. 
        // Rust se encarga de convertir Varianza -> StdDev y Beta -> Lambda
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

      // Llamada al servicio
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. CONFIGURACIÓN GLOBAL
            Card(
              color: const Color(BG_CARD),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Configuración General", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildInput(_lambdaCtrl, "Llegadas/Hora (Poisson)", icon: Icons.people)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildInput(_hoursCtrl, "Horas a Simular", icon: Icons.timer)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 2. CONFIGURACIÓN DE ETAPAS (Dinámica)
            const Align(
              alignment: Alignment.centerLeft, 
              child: Text("Estaciones del Autolavado (Pipeline)", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))
            ),
            const SizedBox(height: 5),
            
            // Renderizamos la lista de etapas
            ..._stages.asMap().entries.map((entry) {
              int idx = entry.key;
              StageInput stage = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: const Color(BG_CARD),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(backgroundColor: const Color(PRIMARY), radius: 12, child: Text("${idx+1}", style: const TextStyle(fontSize: 12, color: Colors.white))),
                          const SizedBox(width: 10),
                          // Dropdown para tipo de distribución
                          Expanded(
                            child: DropdownButton<Generator>(
                              value: stage.type,
                              dropdownColor: const Color(BG_CARD),
                              isDense: true,
                              style: const TextStyle(color: Colors.white),
                              underline: Container(),
                              items: const [
                                DropdownMenuItem(value: Generator.normal, child: Text("Normal")),
                                DropdownMenuItem(value: Generator.exponential, child: Text("Exponencial")),
                                DropdownMenuItem(value: Generator.uniform, child: Text("Uniforme")),
                              ],
                              onChanged: (g) => setState(() => stage.type = g!),
                            ),
                          ),
                          // Botón borrar
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                            onPressed: () => _removeStage(idx),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Inputs dinámicos según la distribución
                      Row(
                        children: [
                          if (stage.type == Generator.normal) ...[
                            Expanded(child: _buildInput(stage.p1Ctrl, "Media (μ)")),
                            const SizedBox(width: 10),
                            Expanded(child: _buildInput(stage.p2Ctrl, "Varianza (σ²)")),
                          ] else if (stage.type == Generator.exponential) ...[
                            Expanded(child: _buildInput(stage.p1Ctrl, "Beta (β)")),
                          ] else ...[
                            Expanded(child: _buildInput(stage.p1Ctrl, "Mínimo")),
                            const SizedBox(width: 10),
                            Expanded(child: _buildInput(stage.p2Ctrl, "Máximo")),
                          ]
                        ],
                      )
                    ],
                  ),
                ),
              );
            }).toList(),

            // Botón Agregar
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white),
              onPressed: _addStage,
              icon: const Icon(Icons.add),
              label: const Text("Agregar Estación"),
            ),

            const SizedBox(height: 20),

            // Botón Iniciar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(GREEN),
                  foregroundColor: const Color(BG_PRIMARY),
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

            // 3. RESULTADOS
            if (_result != null) _buildResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, {IconData? icon}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

  Widget _buildResults() {
    return Column(
      children: [
        const SizedBox(height: 20),
        // Resumen Global
        Card(
          color: const Color(GREEN).withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat("Total Autos", "${_result!.totalCars}"),
                _stat("Espera Prom.", "${_result!.avgWaitTime.toStringAsFixed(2)} min"),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        
        // Detalle por Horas
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _result!.hours.length,
          itemBuilder: (ctx, i) {
            final h = _result!.hours[i];
            return Card(
              color: const Color(BG_CARD),
              child: ExpansionTile(
                title: Text("Hora ${h.hourIndex}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _badge(Colors.blue, "Est: ${h.estimated}"),
                      const SizedBox(width: 5),
                      _badge(Colors.green, "Ok: ${h.served}"),
                      const SizedBox(width: 5),
                      // Pendientes (Insatisfechos/En cola al final de la hora)
                      _badge(h.pending > 0 ? Colors.orange : Colors.grey, "Pend: ${h.pending}"),
                    ],
                  ),
                ),
                children: h.cars.map((c) => ListTile(
                  dense: true,
                  leading: Text(
                    "${(c.arrival % 60).toStringAsFixed(0)}'", 
                    style: const TextStyle(color: Colors.white54, fontSize: 12)
                  ),
                  title: Text("Carro ${c.id}", style: const TextStyle(color: Colors.white)),
                  trailing: Text(
                    "${c.total.toStringAsFixed(1)} min", 
                    style: const TextStyle(color: Color(GREEN), fontWeight: FontWeight.bold)
                  ),
                  subtitle: Text(
                    c.wait > 0.1 ? "Espera en cola: ${c.wait.toStringAsFixed(1)} min" : "Entrada inmediata",
                    style: TextStyle(color: c.wait > 5 ? Colors.redAccent : Colors.white30, fontSize: 11),
                  ),
                )).toList(),
              ),
            );
          },
        )
      ],
    );
  }

  Widget _badge(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _stat(String label, String val) {
    return Column(children: [Text(val, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70))]);
  }
}