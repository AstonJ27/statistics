// lib/scaffolds/simulation.dart
import 'dart:convert';
import 'dart:math' as math;
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

      // Llamada al servicio (nativa Rust)
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

  // -----------------------
  // Helpers para Poisson y mapeo por inversión
  // -----------------------
  List<Map<String,double>> _buildPoissonTable(double lambda, int hours) {
    List<Map<String,double>> table = [];
    double e_minus_lambda = math.exp(-lambda);
    double pk = e_minus_lambda; // p0
    double cumulative = 0.0;
    for (int k = 0; k < hours; k++) {
      if (k == 0) {
        pk = e_minus_lambda;
      } else {
        pk = pk * lambda / k; // recurrencia p_k = p_{k-1} * λ / k
      }
      cumulative += pk;
      table.add({ 'x': k.toDouble(), 'cdf': cumulative });
    }
    return table;
  }

  List<Map<String, dynamic>> _buildRandomsMapped(List<Map<String,double>> cdfTable, int n) {
    final rnd = math.Random();
    List<Map<String, dynamic>> rows = [];
    for (int i = 0; i < n; i++) {
      double u = rnd.nextDouble();
      int xi = 0;
      for (final row in cdfTable) {
        if (u <= row['cdf']!) {
          xi = row['x']!.toInt();
          break;
        }
      }
      rows.add({'u': u, 'xi': xi});
    }
    return rows;
  }

  // -----------------------
  // Widgets de UI reutilizables
  // -----------------------

  // Donut circular simple usando CircularProgressIndicator (sin paquetes extra)
  Widget _donut(double pct, Color color, String label, {double size = 72}) {
    final value = (pct.clamp(0.0, 100.0)) / 100.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            value: value,
            strokeWidth: 10,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${pct.toStringAsFixed(0)}%", style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        )
      ]),
    );
  }

  // Card fijo con scroll (alto fijo adaptativo según ancho)
  Widget _fixedCardWithScroll({required Widget child, required double height}) {
    return LayoutBuilder(builder: (context, constraints) {
      final maxW = constraints.maxWidth;
      final h = height; // already chosen
      return Card(
        color: const Color(BG_CARD),
        child: SizedBox(
          height: h,
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: maxW - 24),
                child: child,
              ),
            ),
          ),
        ),
      );
    });
  }

  // Poisson horizontal: columnas X=0..hours-1, single row for F(X)
  Widget _poissonHorizontalTable(double lambda, int hours) {
    final table = _buildPoissonTable(lambda, hours);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: table.map((r) => DataColumn(label: Text('X=${r['x']!.toInt()}'))).toList(),
        rows: [
          DataRow(
            cells: table.map((r) => DataCell(Text(r['cdf']!.toStringAsFixed(4)))).toList(),
          ),
        ],
      ),
    );
  }

  // Randoms horizontal: columns 1..n, row0 = u, row1 = x_i
  Widget _randomsHorizontalTable(List<Map<String,double>> cdfTable, int n) {
    final rows = _buildRandomsMapped(cdfTable, n);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: List.generate(n, (i) => DataColumn(label: Text('${i+1}'))),
        rows: [
          DataRow(cells: rows.map((r) => DataCell(Text((r['u'] as double).toStringAsFixed(4)))).toList()),
          DataRow(cells: rows.map((r) => DataCell(Text('${r['xi']}'))).toList()),
        ],
      ),
    );
  }

  Widget _poissonAndRandomsCard() {
    final lambda = double.tryParse(_lambdaCtrl.text) ?? 3.0;
    final hrs = int.tryParse(_hoursCtrl.text) ?? 8;
    final poissonTable = _buildPoissonTable(lambda, hrs);
    // For mapping use hrs randoms
    final randomsCount = hrs;
    return _fixedCardWithScroll(
      height: 180,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Poisson (X across columns) y mapeo de #ran -> x_i (horizontales)", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        // Poisson horizontal table
        _poissonHorizontalTable(lambda, hrs),
        const SizedBox(height: 12),
        // Randoms horizontal table (u row and xi row)
        _randomsHorizontalTable(poissonTable, randomsCount),
      ]),
    );
  }

  Widget _buildResults() {
    final result = _result!;
  
    // Totales: Satisfechos = sum(h.served), Insatisfechos = sum(h.leftCount), Pendientes = sum(h.pending)
    int totalCars = result.totalCars;
    int totalSatisfied = 0;
    int totalUnsatisfied = 0;
    int totalPending = 0;
  
    for (final h in result.hours) {
      totalSatisfied += h.served;
      totalPending += h.pending;
      // Si el backend incluye leftCount, sumarlo
      try {
        if ((h as dynamic).leftCount != null) {
          totalUnsatisfied += (h as dynamic).leftCount as int;
        } else {
          // Si no hay leftCount, contar manualmente
          for (final c in h.cars) {
            try {
              if ((c as dynamic).left == true) totalUnsatisfied += 1;
            } catch (_) {}
          }
        }
      } catch (_) {
        // Contar manualmente si hay error
        for (final c in h.cars) {
          try {
            if ((c as dynamic).left == true) totalUnsatisfied += 1;
          } catch (_) {}
        }
      }
    }
  
    // Los porcentajes se calculan sobre el TOTAL de carros (satisfechos + insatisfechos + pendientes)
    final double satPct = totalCars == 0 ? 0.0 : (totalSatisfied / totalCars) * 100.0;
    final double unsatPct = totalCars == 0 ? 0.0 : (totalUnsatisfied+totalPending / totalCars) * 100.0;
    // NOTA: Los pendientes no se incluyen en los porcentajes de los donuts
  
    return Column(
      children: [
        const SizedBox(height: 20),
  
        // Card with Poisson + Randoms (fixed height, scrollable)
        _poissonAndRandomsCard(),
  
        const SizedBox(height: 12),
  
        // Resumen Global MODIFICADO: Donuts debajo de los números
        Card(
          color: Colors.grey.shade900,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila con los números (Total Autos y Espera Prom.)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.totalCars.toString(),
                            style: const TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Total Autos",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${result.avgWaitTime.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Espera Prom. (min)",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
  
                const SizedBox(height: 20),
  
                // Donuts debajo de los números
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Satisfacción del Cliente",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              _donut(satPct, Colors.green, "Satisfechos", size: 80),
                              const SizedBox(height: 8),
                              Text(
                                "$totalSatisfied autos",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              _donut(unsatPct, Colors.red, "Insatisfechos", size: 80),
                              const SizedBox(height: 8),
                              Text(
                                "$totalUnsatisfied autos",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      // Pendientes (centrados) - Se muestran aparte
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            "Pendientes hoy: $totalPending autos",
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
  
        const SizedBox(height: 12),
  
        // Cards por cada hora (plegables)
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: result.hours.length,
          itemBuilder: (ctx, idx) {
            final h = result.hours[idx];
            
            // Calcular satisfechos, insatisfechos y pendientes por hora
            int hSatisfied = h.served;
            int hPending = h.pending;
            int hUnsatisfied = 0;
            
            // Intentar obtener leftCount del backend
            try {
              if ((h as dynamic).leftCount != null) {
                hUnsatisfied = (h as dynamic).leftCount as int;
              } else {
                // Contar manualmente
                hUnsatisfied = h.cars.where((c) {
                  try {
                    return (c as dynamic).left == true;
                  } catch (_) {
                    return false;
                  }
                }).length;
              }
            } catch (_) {
              // Contar manualmente si hay error
              hUnsatisfied = h.cars.where((c) {
                try {
                  return (c as dynamic).left == true;
                } catch (_) {
                  return false;
                }
              }).length;
            }
  
            return Card(
              color: const Color(BG_CARD),
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Título (hora + llegadas)
                  Text("Hora ${h.hourIndex}  •  Llegadas estimadas: ${h.estimated}", style: const TextStyle(fontWeight: FontWeight.bold)),
  
                  const SizedBox(height: 8),
                  // Satisfechos/Insatisfechos/Pendientes
                  Row(children: [
                    _badge(Colors.green, "Satisfechos: $hSatisfied"),
                    const SizedBox(width: 8),
                    _badge(Colors.red, "Insatisfechos: ${hUnsatisfied+hPending}"),
                    const SizedBox(width: 8),
                    _badge(hPending > 0 ? Colors.orange : Colors.grey, "Pendientes: $hPending"),
                  ]),
  
                  const SizedBox(height: 10),
  
                  // Expansion area: plegable para ver los carros
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text("Detalle de carros", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    children: [
                      // Fixed height area with vertical scroll for car list
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            child: Column(
                              children: h.cars.map((c) {
                                final double hourEnd = (h.hourIndex as int) * 60.0;
                                
                                // Determinar estado del carro
                                bool isLeft = false;
                                bool isPending = false;
                                bool isSatisfied = false;
                                
                                try {
                                  isLeft = (c as dynamic).left == true;
                                  isPending = (c as dynamic).pending == true;
                                  isSatisfied = (c as dynamic).satisfied == true;
                                } catch (_) {
                                  // Si no hay nuevos campos, usar lógica anterior
                                  isLeft = (() {
                                    try { return (c as dynamic).left == true; } catch (_) { return false; }
                                  })();
                                  isPending = (!isLeft) && (c.end > hourEnd);
                                  isSatisfied = (!isLeft) && !isPending;
                                }
  
                                Color statusColor = Colors.white70;
                                String statusText = "";
                                
                                if (isLeft) {
                                  statusColor = Colors.redAccent;
                                  statusText = "Abandonó (insatisfecho)";
                                } else if (isPending) {
                                  statusColor = Colors.redAccent; //Colors.orangeAccent;
                                  statusText = "Pendiente (sigue en servicio)";
                                } else {
                                  statusColor = Colors.green;
                                  statusText = "Atendido (satisfecho)";
                                }
  
                                return Card(
                                  color: Colors.black12,
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [  //Se imprime la id del carro y su tiempo total
                                        Text("Carro ${c.id}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text("${(c.total-c.wait).toStringAsFixed(2)} min", style: const TextStyle(color: Color(GREEN), fontWeight: FontWeight.bold)),
                                      ]),
                                      const SizedBox(height: 6),
                                      // Estaciones como chips
                                      if ((c as dynamic).stageDurations != null && (c as dynamic).stageDurations.length > 0)
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: (c as dynamic).stageDurations.asMap().entries.map<Widget>((e) {
                                            final idxStage = e.key + 1;
                                            final val = e.value as double;
                                            return Chip(
                                              backgroundColor: Colors.black12,
                                              label: Text("Est${idxStage}: ${val.toStringAsFixed(2)} min"),
                                            );
                                          }).toList(),
                                        )
                                      else
                                        Text("Tiempos por estación no disponibles", style: TextStyle(color: Colors.white54)),
                                      const SizedBox(height: 8),
                                      // Estado del carro
                                      Text("$statusText — Espera: ${c.wait.toStringAsFixed(2)} min", style: TextStyle(color: statusColor)),
                                    ]),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ]),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _badge(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.4))),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _stat(String label, String val) {
    return Column(children: [Text(val, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70))]);
  }

  @override
  Widget build(BuildContext context) {
    // Usamos SafeArea + SingleChildScrollView (layout responsivo)
    return SafeArea(
      child: LayoutBuilder(builder: (context, constraints) {
        // ajustar paddings / tamaños si es pantalla ancha vs estrecha
        final isWide = constraints.maxWidth > 700;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 32.0 : 16.0, vertical: 16.0),
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
                child: Text("Estaciones del Autolavado", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))
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
        );
      }),
    );
  }
}