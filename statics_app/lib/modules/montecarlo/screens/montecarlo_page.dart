import 'dart:convert';
import 'dart:math' as math; // Para cálculos matemáticos si hiciera falta
import 'package:flutter/material.dart';
import '../../../core/ffi/native_service.dart';
import '../../../core/theme/app_colors.dart';
import '../models/montecarlo_models.dart';
import '../widgets/variable_list_widget.dart';
import '../widgets/inverse_cdf_dialog.dart'; // Asegúrate de que este archivo existe en la ruta correcta

class MonteCarloPage extends StatefulWidget {
  const MonteCarloPage({super.key});

  @override
  State<MonteCarloPage> createState() => _MonteCarloPageState();
}

class _MonteCarloPageState extends State<MonteCarloPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Controladores de Scroll para la Tabla (Los "Sliders")
  final ScrollController _verticalScrollCtrl = ScrollController();
  final ScrollController _horizontalScrollCtrl = ScrollController();

  final TextEditingController _nSimsCtrl = TextEditingController(text: "10"); 
  final List<McVariable> _variables = [
    // Iniciamos con una variable por defecto para que no esté vacío
    McVariable(name: "", type: McDistType.normal, param1: 10, param2: 4), 
  ];
  
  final TextEditingController _thresholdCtrl = TextEditingController(text: "6");
  final TextEditingController _costCtrl = TextEditingController(text: "75");
  final TextEditingController _popCtrl = TextEditingController(text: "50000");
  String _operator = "<=";

  McResult? _result;
  bool _loading = false;
  String _error = "";
  double? _theoreticalProb;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if(_tabController.indexIsChanging) setState(() { _result = null; _error = ""; _theoreticalProb = null; });
    });
  }

  @override
  void dispose() {
    _verticalScrollCtrl.dispose();
    _horizontalScrollCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _addVar() => setState(() => _variables.add(McVariable(name: "")));
  
  void _removeVar(int i) { 
    if(_variables.length > 0) setState(() => _variables.removeAt(i)); 
  }

  // --- Lógica Teórica (Probabilidad Real) ---
  void _calcTheoretical() {
    _theoreticalProb = null;
    if (_variables.length != 1) return;

    try {
      final v = _variables[0];
      final limit = double.parse(_thresholdCtrl.text);
      final isLess = _operator.contains("<"); 

      if (!isLess) return;

      if (v.type == McDistType.exponential) {
        double beta = v.param1;
        if (beta > 0) _theoreticalProb = 1 - math.exp(-limit / beta);
      } else if (v.type == McDistType.uniform) {
        double min = v.param1;
        double max = v.param2;
        if (limit < min) _theoreticalProb = 0.0;
        else if (limit > max) _theoreticalProb = 1.0;
        else _theoreticalProb = (limit - min) / (max - min);
      } else if (v.type == McDistType.normal) {
        double mu = v.param1;
        double variance = v.param2;
        double sigma = math.sqrt(variance);
        _theoreticalProb = _normalCdf(limit, mu, sigma);
      }
    } catch (e) {
      debugPrint("Error calc teórico: $e");
    }
  }

  double _normalCdf(double x, double mean, double stdDev) {
    return 0.5 * (1 + _erf((x - mean) / (stdDev * math.sqrt(2))));
  }

  double _erf(double x) {
    const a1 = 0.254829592;
    const a2 = -0.284496736;
    const a3 = 1.421413741;
    const a4 = -1.453152027;
    const a5 = 1.061405429;
    const p  = 0.3275911;
    int sign = 1;
    if (x < 0) sign = -1;
    x = x.abs();
    double t = 1.0 / (1.0 + p * x);
    double y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * math.exp(-x * x);
    return sign * y;
  }
  // ------------------------------------------

  Future<void> _run() async {
    setState(() { _loading = true; _error = ""; _result = null; _theoreticalProb = null; });
    try {
      int n = int.tryParse(_nSimsCtrl.text) ?? 10;
      bool isProbMode = _tabController.index == 1;

      if (_variables.isEmpty) throw Exception("Agrega al menos una variable.");

      Map<String, dynamic> analysis = {};
      if (isProbMode) {
        _calcTheoretical();
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

      List<Map<String, dynamic>> varsJson = [];
      for (int i = 0; i < _variables.length; i++) {
        var v = _variables[i];
        v.name = "X${i + 1}"; 
        varsJson.add(v.toJson());
      }

      Map<String, dynamic> config = {
        "n_simulations": n,
        "variables": varsJson,
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
        title: const Text("Laboratorio Montecarlo", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: "Calculadora Inversa",
            icon: const Icon(Icons.calculate_outlined, color: AppColors.green),
            onPressed: () {
               showDialog(context: context, builder: (_) => const InverseCdfDialog());
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.green,
          labelColor: AppColors.green,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Acumulador (Problema 1)", icon: Icon(Icons.functions)),
            Tab(text: "Riesgo (Problema 2)", icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            VariableListWidget(
              variables: _variables, 
              onAdd: _addVar, 
              onRemove: _removeVar
            ),
            const SizedBox(height: 16),
            
            AnimatedBuilder(
              animation: _tabController,
              builder: (ctx, _) => _tabController.index == 1 
                  ? _buildProbConfig() 
                  : const SizedBox.shrink(),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nSimsCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Tamaño de Muestra (n)",
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true, 
                      fillColor: AppColors.bgCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.numbers, color: Colors.white38),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _run,
                      icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgPrimary)) : const Icon(Icons.play_arrow),
                      label: const Text("GENERAR DATOS", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: AppColors.bgPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.3))),
                child: Text(_error, style: const TextStyle(color: Colors.red)),
              ),

            if (_result != null) _buildResultCard(context),

            // Espacio final para asegurar que se pueda scrollear hasta el fondo
            const SizedBox(height: 80), 
          ],
        ),
      ),
    );
  }

  Widget _buildProbConfig() {
    return Card(
      color: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Configuración de Riesgo", style: TextStyle(color: AppColors.green, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Row(children: [
              const Text("Condición: Suma ", style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _operator,
                    dropdownColor: AppColors.bgCard,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    items: ["<", "<=", ">", ">="].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _operator = v!),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _simpleInput(_thresholdCtrl, "Límite")),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _simpleInput(_costCtrl, "Costo (\$)")),
              const SizedBox(width: 12),
              Expanded(child: _simpleInput(_popCtrl, "Población")),
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
        filled: true, 
        fillColor: Colors.black26,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }

  Widget _buildResultCard(BuildContext context) {
    bool isProbMode = _tabController.index == 1;
    int varCount = 0;
    if (_result!.preview.isNotEmpty) {
      varCount = _result!.preview[0].variables.length;
    }

    // CÁLCULO DE ALTURA RESPONSIVE: 45% de la pantalla o mínimo 300px
    final screenHeight = MediaQuery.of(context).size.height;
    final tableHeight = math.max(300.0, screenHeight * 0.45);

    return Container(
      margin: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Resultados Estadísticos", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          Card(
            color: AppColors.bgCard,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _rowBigStat("Promedio Total", _result!.mean.toStringAsFixed(4)),
                  const Divider(color: Colors.white10, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _colStat("Desv. Std", _result!.stdDev.toStringAsFixed(4)),
                      _colStat("Mín Total", _result!.min.toStringAsFixed(2)),
                      _colStat("Máx Total", _result!.max.toStringAsFixed(2)),
                    ],
                  ),
                  
                  if (isProbMode && _result!.probability != null) ...[
                    const Divider(color: Colors.white10, height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15), 
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3))
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Prob. Simulada", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  Text("${(_result!.probability! * 100).toStringAsFixed(2)} %", style: const TextStyle(color: AppColors.green, fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              if (_theoreticalProb != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text("Prob. Real (Teórica)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    Text("${(_theoreticalProb! * 100).toStringAsFixed(2)} %", style: const TextStyle(color: Colors.cyanAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _rowBigStat("Costo Esperado", "\$ ${_result!.expectedCost!.toStringAsFixed(2)}", color: Colors.orangeAccent),
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
          
          const SizedBox(height: 24),
          const Text("Tabla Detallada (Muestra)", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          
          // --- TABLA RESPONSIVE CON SLIDERS VISIBLES ---
          Container(
            height: tableHeight, // Altura calculada dinámicamente
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10)
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.white24,
                iconTheme: const IconThemeData(color: Colors.white),
                // Personalizamos el scrollbar si es necesario
                scrollbarTheme: ScrollbarThemeData(
                  thumbColor: MaterialStateProperty.all(Colors.white30),
                )
              ),
              child: Scrollbar( // Slider Vertical
                controller: _verticalScrollCtrl,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _verticalScrollCtrl,
                  scrollDirection: Axis.vertical,
                  child: Scrollbar( // Slider Horizontal
                    controller: _horizontalScrollCtrl,
                    thumbVisibility: true,
                    notificationPredicate: (notif) => notif.depth == 1, // Evita conflictos de scroll anidado
                    child: SingleChildScrollView(
                      controller: _horizontalScrollCtrl,
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        border: const TableBorder(
                          horizontalInside: BorderSide(color: Colors.white10, width: 0.5),
                          verticalInside: BorderSide(color: Colors.white10, width: 0.5),
                        ),
                        headingRowColor: MaterialStateProperty.all(Colors.black26),
                        headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        dataTextStyle: const TextStyle(color: Colors.white70),
                        columnSpacing: 24,
                        columns: [
                          const DataColumn(label: Text("#")),
                          ...List.generate(varCount, (index) => DataColumn(
                            label: Text("X${index+1}", style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold))
                          )),
                          const DataColumn(label: Text("TOTAL", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold))),
                        ],
                        rows: List<DataRow>.generate(
                          _result!.preview.length, 
                          (index) {
                            final item = _result!.preview[index];
                            return DataRow(
                              cells: [
                                DataCell(Text("${index + 1}")),
                                ...item.variables.map((val) => DataCell(
                                  Text(val.toStringAsFixed(4))
                                )),
                                DataCell(Text(item.total.toStringAsFixed(4), style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold))),
                              ]
                            );
                          }
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
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