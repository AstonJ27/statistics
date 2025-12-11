import 'dart:convert';
import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:ffi/ffi.dart';
import 'package:uuid/uuid.dart';

// Imports de Core y Modelos
import '../../../core/ffi/native_service.dart';
import '../../../core/theme/app_colors.dart';
import '../models/descriptive_models.dart';

// Imports de Widgets Generales
import '../widgets/histogram_painter.dart';
import '../widgets/boxplot_widget.dart';
import '../widgets/stemleaf_widget.dart';
import '../widgets/freq_table_widget.dart';
import '../widgets/data_input_forms.dart';

// Imports de Servicios y Pantallas
import '../services/analysis_storage_service.dart';
import 'saved_analyses_page.dart';

// --- IMPORTS DE CARDS MODULARIZADOS ---
// Asegúrate de que los archivos estén en lib/modules/descriptive/widgets/cards/
import '../widgets/cards/probability_card.dart';
import '../widgets/cards/summary_stats_card.dart';
import '../widgets/cards/generator_form_card.dart';

// Constantes locales
const int PRIMARY_INT = 0xFF4E2ECF;

// Enum Generator para el estado local
//enum Generator { normal, exponential, uniform }

class DescriptivePage extends StatefulWidget {
  const DescriptivePage({super.key});
  @override
  State<DescriptivePage> createState() => _DescriptivePageState();
}

class _DescriptivePageState extends State<DescriptivePage> {
  // Estado de la UI
  InputMode _inputMode = InputMode.generator;
  AnalyzeResult? _result;
  Map<String, dynamic>? _lastRawJson; // JSON crudo para guardar/restaurar
  bool _running = false;
  String _error = '';

  // Controladores para el Generador
  Generator _generator = Generator.normal;
  int _n = 10000;
  double _mean = 0.0;
  double _std = 1.0;
  double _beta = 1.0;

  final TextEditingController _nController = TextEditingController();
  final TextEditingController _meanController = TextEditingController();
  final TextEditingController _stdController = TextEditingController();
  final TextEditingController _betaController = TextEditingController();

  // Key para acceder al estado del formulario manual y guardar los inputs
  final GlobalKey<DataInputFormsState> _formKey = GlobalKey<DataInputFormsState>();
  
  // Datos restaurados para pasar al formulario manual
  Map<String, dynamic>? _restoredInputData; 

  @override
  void initState() {
    super.initState();
    _updateControllers();
  }

  void _updateControllers() {
    _nController.text = _n.toString();
    _meanController.text = _mean.toStringAsFixed(2);
    _stdController.text = _std.toStringAsFixed(2);
    _betaController.text = _beta.toStringAsFixed(2);
  }

  void _applyNumericInputs() {
    final parsedN = int.tryParse(_nController.text.replaceAll(',', '').trim());
    final parsedMean = double.tryParse(_meanController.text.replaceAll(',', '').trim());
    final parsedStd = double.tryParse(_stdController.text.replaceAll(',', '').trim());
    final parsedBeta = double.tryParse(_betaController.text.replaceAll(',', '').trim());
    
    setState(() {
      if (parsedN != null && parsedN > 0) _n = parsedN;
      if (parsedMean != null) _mean = parsedMean;
      if (parsedStd != null && parsedStd > 0) _std = parsedStd;
      if (parsedBeta != null && parsedBeta > 0) _beta = parsedBeta;
    });
  }

  // Lógica: Generar datos aleatorios y analizar
  Future<void> _generateAndAnalyze() async {
    _applyNumericInputs();
    setState(() { _running = true; _result = null; _error = ''; _lastRawJson = null; });
    final ptr = calloc<Double>(_n);
    
    try {
      String dist = _generator == Generator.normal ? 'normal' : (_generator == Generator.exponential ? 'exponential' : 'uniform');
      double p1 = _generator == Generator.normal ? _mean : (_generator == Generator.exponential ? _beta : 0.0);
      double p2 = _generator == Generator.normal ? _std : 0.0;

      NativeService.generateSamples(ptr, _n, dist: dist, param1: p1, param2: p2);
      
      // Obtener RAW JSON (Optimizado para guardar)
      final jsonStr = await Future.delayed(Duration.zero, () => 
        NativeService.analyzeDistributionRaw(ptr, _n, hRound: true, forcedK: 0, forcedMin: double.nan, forcedMax: double.nan)
      );

      final jsonMap = jsonDecode(jsonStr);
      
      setState(() {
        _lastRawJson = jsonMap; 
        _result = AnalyzeResult.fromJson(jsonMap);
      });
      
    } catch (e) {
      setState(() => _error = "Error: $e");
    } finally {
      calloc.free(ptr);
      setState(() => _running = false);
    }
  }

  // Lógica: Analizar datos manuales (CSV/Tabla)
  Future<void> _analyzeManualData(List<double> data, int k, double? min, double? max) async {
    setState(() { _running = true; _error = ''; _result = null; _lastRawJson = null; });
    try {
       final ptr = NativeService.copyDataToRust(data);
       try {
         double fMin = min ?? double.nan;
         double fMax = max ?? double.nan;
         
         final jsonStr = await Future.delayed(Duration.zero, () => 
            NativeService.analyzeDistributionRaw(
                ptr, 
                data.length, 
                hRound: true, 
                forcedK: k,
                forcedMin: fMin, 
                forcedMax: fMax
            )
         );

         final jsonMap = jsonDecode(jsonStr);
         
         setState(() {
            _lastRawJson = jsonMap; 
            _result = AnalyzeResult.fromJson(jsonMap);
         });

       } finally {
         NativeService.freeDoublePtr(ptr);
       }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _running = false);
    }
  }

  // Lógica: Guardar Análisis en Historial
  Future<void> _saveCurrentAnalysis() async {
    if (_result == null || _lastRawJson == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay resultados para guardar")));
      return;
    }

    final TextEditingController nameCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text("Guardar Análisis", style: TextStyle(color: Colors.white)),
        content: TextField(
            controller: nameCtrl, 
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Nombre (ej. Caso 1)", 
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30))
            )
        ),
        actions: [
            TextButton(child: const Text("Cancelar"), onPressed: () => Navigator.pop(context)),
            TextButton(
                child: const Text("Guardar", style: TextStyle(color: AppColors.green, fontWeight: FontWeight.bold)), 
                onPressed: () async {
                    if (nameCtrl.text.isEmpty) return;
                    
                    // Obtener configuración de inputs
                    Map<String, dynamic> inputConfig = {};
                    if (_inputMode == InputMode.generator) {
                        inputConfig = {
                            'gen_type': _generator.index,
                            'n': _n,
                            'mean': _mean,
                            'std': _std,
                            'beta': _beta
                        };
                    } else {
                        // Obtener del formulario usando la Key
                        if (_formKey.currentState != null) {
                            inputConfig = _formKey.currentState!.getCurrentInputState();
                        }
                    }

                    final item = SavedAnalysis(
                        id: const Uuid().v4(),
                        name: nameCtrl.text,
                        date: DateTime.now(),
                        mode: _inputMode,
                        inputs: inputConfig,
                        rawResult: _lastRawJson!
                    );

                    final error = await AnalysisStorageService().saveAnalysis(item);
                    Navigator.pop(context); // Cerrar dialogo
                    
                    if (error != null) {
                        _showLimitError();
                    } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Guardado exitosamente")));
                    }
                }
            )
        ],
      )
    );
  }

  void _showLimitError() {
      showDialog(
        context: context, 
        builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.bgCard,
            title: const Text("Límite Alcanzado", style: TextStyle(color: Colors.white)),
            content: const Text("Has llegado al límite de 20 análisis. Por favor, elimina uno antiguo.", style: TextStyle(color: Colors.white70)),
            actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("OK"))],
        )
      );
  }

  // Lógica: Restaurar Análisis desde Historial
  void _restoreAnalysis(SavedAnalysis item) {
      setState(() {
          _inputMode = item.mode;
          _error = '';
          
          // Restaurar Inputs
          if (item.mode == InputMode.generator) {
              _restoredInputData = null; // Limpiar data manual
              _generator = Generator.values[item.inputs['gen_type'] ?? 0];
              _n = item.inputs['n'] ?? 1000;
              _mean = item.inputs['mean'] ?? 0.0;
              _std = item.inputs['std'] ?? 1.0;
              _beta = item.inputs['beta'] ?? 1.0;
              _updateControllers();
          } else {
              // Para modos manuales, pasamos la data al formulario
              _restoredInputData = item.inputs;
          }
          
          // Restaurar Resultado Directamente
          _lastRawJson = item.rawResult;
          _result = item.parsedResult;
      });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold( 
        appBar: AppBar(
             title: const Text("Análisis Descriptivo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
             backgroundColor: Colors.transparent,
             elevation: 0,
             centerTitle: true,
             iconTheme: const IconThemeData(color: Colors.white),
             actions: [
                 IconButton(
                     icon: const Icon(Icons.history),
                     tooltip: "Historial Guardado",
                     onPressed: () => Navigator.push(
                         context, 
                         MaterialPageRoute(builder: (_) => SavedAnalysesPage(onLoad: _restoreAnalysis))
                     ),
                 ),
                 IconButton(
                     icon: const Icon(Icons.save),
                     tooltip: "Guardar Análisis Actual",
                     onPressed: _saveCurrentAnalysis,
                 )
             ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header con Selector de Modo
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  color: AppColors.bgCard,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<InputMode>(
                        value: _inputMode,
                        dropdownColor: AppColors.bgCard,
                        isExpanded: true,
                        icon: const Icon(Icons.source, color: Colors.white70),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        items: const [
                          DropdownMenuItem(value: InputMode.generator, child: Text("Fuente: Generador Aleatorio")),
                          DropdownMenuItem(value: InputMode.csv, child: Text("Fuente: CSV / Datos")),
                          DropdownMenuItem(value: InputMode.frequencyTable, child: Text("Fuente: Tabla de Frecuencias")),
                          DropdownMenuItem(value: InputMode.histogram, child: Text("Fuente: Datos de Histograma")),
                        ],
                        onChanged: (m) => setState(() { 
                          _inputMode = m!; 
                          _result = null; 
                          _error = ''; 
                          _lastRawJson = null;
                          _restoredInputData = null; // Limpiar restauración al cambiar modo manual
                        }),
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Controles de Entrada (Refactorizados)
              if (_inputMode == InputMode.generator)
                GeneratorFormCard(
                  selectedGenerator: _generator,
                  nCtrl: _nController,
                  meanCtrl: _meanController,
                  stdCtrl: _stdController,
                  betaCtrl: _betaController,
                  isRunning: _running,
                  onGenerate: _generateAndAnalyze,
                  onReset: () => setState(() { _result = null; _lastRawJson = null; }),
                  onGeneratorChanged: (g) { setState(() => _generator = g); _updateControllers(); }
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    color: AppColors.bgCard,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: DataInputForms(
                        key: _formKey, // Key vital para guardar
                        mode: _inputMode, 
                        onDataReady: _analyzeManualData,
                        initialData: _restoredInputData, // Data vital para restaurar
                      ),
                    ),
                  ),
                ),

              if (_error.isNotEmpty) 
                Padding(padding: const EdgeInsets.all(16), child: Text(_error, style: const TextStyle(color: Colors.red))),

              // 3. Resumen Estadístico (Refactorizado)
              if (_result != null)
                SummaryStatsCard(result: _result!),
              
              // 4. Gráficos y Tablas
              if (_result != null) _buildResultContent(context)
            ],
          ),
        ),
      ),
    );
  }

  // Lista de Gráficos y Tablas
  Widget _buildResultContent(BuildContext context) {
    return Column(
      children: [
        // Histograma
        Card(
          color: Colors.white, 
          margin: const EdgeInsets.all(16), 
          child: Padding(
            padding: const EdgeInsets.all(16), 
            child: SizedBox(
              height: 300, 
              width: double.infinity, 
              child: CustomPaint(
                painter: HistogramPainter(
                  edges: _result!.histogram.edges, 
                  counts: _result!.histogram.counts, 
                  curveX: _result!.curves?['x'] != null ? (_result!.curves!['x'] as List).map((e)=>e as double).toList() : null, 
                  curveY: _result!.curves?['best_freq'] != null ? (_result!.curves!['best_freq'] as List).map((e)=>e as double).toList() : null
                )
              )
            )
          )
        ),
        
        // --- Nuevo: Calculadora de Probabilidades ---
        ProbabilityCard(result: _result!),
        // -------------------------------------------

        _buildExpandableCard("Diagrama de Caja", SizedBox(height: 150, width: double.infinity, child: BoxplotWidget(box: _result!.boxplot))),
        
        _buildExpandableCard("Tallo y Hoja", SizedBox(
            height: 200,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: StemLeafWidget(items: _result!.stemLeaf),
              ),
            )
        )),
        
        _buildExpandableCard("Tabla de Frecuencias", SizedBox(
            height: 300,
            child: FrequencyTableWidget(
              table: _result!.freqTable,
              backgroundColor: AppColors.bgCard,
              textColor: Colors.white,
            )
        ), bgColor: AppColors.bgCard, titleColor: Colors.white),
      ],
    );
  }

  Widget _buildExpandableCard(String title, Widget content, {Color bgColor = Colors.white, Color titleColor = Colors.black87}) {
    return Card(
      color: bgColor, 
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), 
      child: ExpansionTile(
        title: Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)), 
        iconColor: titleColor == Colors.black87 ? const Color(PRIMARY_INT) : Colors.white, 
        collapsedIconColor: Colors.grey, 
        children: [Padding(padding: const EdgeInsets.all(16), child: content)]
      )
    );
  }
}