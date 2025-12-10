import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:ffi/ffi.dart';

import '../../../core/ffi/native_service.dart';
import '../../../core/theme/app_colors.dart';
import '../models/descriptive_models.dart';
import '../widgets/histogram_painter.dart';
import '../widgets/boxplot_widget.dart';
import '../widgets/stemleaf_widget.dart';
import '../widgets/freq_table_widget.dart';
import '../widgets/data_input_forms.dart';

// Constantes locales para restaurar apariencia original exacta
const int PRIMARY_INT = 0xFF4E2ECF;
const int GREEN_INT = 0xFF6FCF97;

enum Generator { normal, exponential, uniform }

class DescriptivePage extends StatefulWidget {
  const DescriptivePage({super.key});
  @override
  State<DescriptivePage> createState() => _DescriptivePageState();
}

class _DescriptivePageState extends State<DescriptivePage> {
  InputMode _inputMode = InputMode.generator;
  AnalyzeResult? _result;
  bool _running = false;
  String _error = '';

  // Controllers Generator
  Generator _generator = Generator.normal;
  int _n = 10000;
  double _mean = 0.0;
  double _std = 1.0;
  double _beta = 1.0;

  final TextEditingController _nController = TextEditingController();
  final TextEditingController _meanController = TextEditingController();
  final TextEditingController _stdController = TextEditingController();
  final TextEditingController _betaController = TextEditingController();

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
    // (Tu lógica original de parsing)
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

  Future<void> _generateAndAnalyze() async {
    _applyNumericInputs();
    setState(() { _running = true; _result = null; _error = ''; });
    final ptr = calloc<Double>(_n);
    try {
      String dist = _generator == Generator.normal ? 'normal' : (_generator == Generator.exponential ? 'exponential' : 'uniform');
      double p1 = _generator == Generator.normal ? _mean : (_generator == Generator.exponential ? _beta : 0.0);
      double p2 = _generator == Generator.normal ? _std : 0.0;

      try {
        NativeService.generateSamples(ptr, _n, dist: dist, param1: p1, param2: p2);
        // forcedK = 0 (Rust usa Sturges)
        final res = await Future.delayed(Duration.zero, () => NativeService.analyzeDistribution(ptr, _n, hRound: true, forcedK: 0, forcedMin: double.nan, forcedMax: double.nan));
        setState(() => _result = res);
      } catch (e) {
        setState(() => _error = "Error: $e");
      }
    } finally {
      calloc.free(ptr);
      setState(() => _running = false);
    }
  }

  // Modificado para recibir 'k'
  Future<void> _analyzeManualData(List<double> data, int k, double? min, double? max) async {
    setState(() { _running = true; _error = ''; _result = null; });
    try {
       final ptr = NativeService.copyDataToRust(data);
       try {
         // Convertir a NaN para que Rust sepa que "no hay dato" si es null
         double fMin = min ?? double.nan;
         double fMax = max ?? double.nan;
         
         final res = await Future.delayed(Duration.zero, () => 
            // Llamamos a la nueva firma del servicio nativo
            NativeService.analyzeDistribution(
                ptr, 
                data.length, 
                hRound: true, 
                forcedK: k,
                forcedMin: fMin, // <--- NUEVO
                forcedMax: fMax  // <--- NUEVO
            )
         );
         setState(() => _result = res);
       } finally {
         NativeService.freeDoublePtr(ptr);
       }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header con Selector de Modo (Diseño limpio arriba)
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
                      onChanged: (m) => setState(() { _inputMode = m!; _result = null; _error = ''; }),
                    ),
                  ),
                ),
              ),
            ),

            // Controles (Restaurando apariencia original para Generador)
            if (_inputMode == InputMode.generator)
              _buildOriginalGeneratorControls() // <--- TU DISEÑO ORIGINAL RESTAURADO
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  color: AppColors.bgCard,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: DataInputForms(mode: _inputMode, onDataReady: _analyzeManualData),
                  ),
                ),
              ),

            if (_error.isNotEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(_error, style: const TextStyle(color: Colors.red))),

            _buildSummaryCard(),
            
            if (_result != null) _buildResultContent(context)
          ],
        ),
      ),
    );
  }

  // --- UI ORIGINAL RESTAURADA ---
  Widget _buildOriginalGeneratorControls() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: const Color(PRIMARY_INT), // Color Original
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Configuración de Datos", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.start, //revisar aqui
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16.0, 
              runSpacing: 16.0,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    const Text("Distribución", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    _buildGeneratorDropdown(),
                  ]
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Tamaño (N)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    SizedBox(width: 120, child: _miniTextField(_nController)),
                ]),
              ],
            ),
            const SizedBox(height: 20),
            if (_generator != Generator.uniform)
              Wrap(spacing: 16, runSpacing: 16, children: [
                  if (_generator == Generator.normal) ...[
                    _buildLabeledMiniInput('Media (μ)', _meanController),
                    _buildLabeledMiniInput('Desv. (σ)', _stdController),
                  ],
                  if (_generator == Generator.exponential)
                    _buildLabeledMiniInput('Escala (β)', _betaController),
              ]),
            const SizedBox(height: 24),
            Row(children: [
                Expanded(child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(GREEN_INT), 
                      foregroundColor: AppColors.bgPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    icon: _running ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.analytics_outlined),
                    label: Text(_running ? 'PROCESANDO...' : 'GENERAR Y ANALIZAR', style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _running ? null : _generateAndAnalyze,
                )),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  style: IconButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(16)),
                  onPressed: _running ? null : () => setState(() => _result = null),
                  icon: const Icon(Icons.refresh),
                )
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratorDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Generator>(
          value: _generator, isDense: true,
          dropdownColor: Colors.grey.shade200,
          style: const TextStyle(color: Colors.black87, fontSize: 16),
          items: const [DropdownMenuItem(value: Generator.normal, child: Text('Normal')), DropdownMenuItem(value: Generator.exponential, child: Text('Exponencial')), DropdownMenuItem(value: Generator.uniform, child: Text('Uniforme'))],
          onChanged: (g) { setState(() => _generator = g ?? Generator.normal); _updateControllers(); },
        ),
      ),
    );
  }

  Widget _buildLabeledMiniInput(String label, TextEditingController ctrl) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        SizedBox(width: 140, child: _miniTextField(ctrl)),
    ]);
  }

  Widget _miniTextField(TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.black87),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        filled: true, fillColor: Colors.grey.shade200,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      onSubmitted: (_) => _applyNumericInputs(),
    );
  }

// Widget de Resumen Estadístico Completo
  Widget _buildSummaryCard() {
    if (_result == null) return const SizedBox.shrink();

    String modeText = "N/A";
    if (_result!.mode.isEmpty) {
      modeText = "Sin moda";
    } else if (_result!.mode.length > 3) {
      modeText = "Multimodal (${_result!.mode.length})";
    } else {
      modeText = _result!.mode.map((e) => e.toStringAsFixed(2)).join(', ');
    }

    // Lista dinámica de estadísticas
    // Usamos 'Object' para permitir bool en highlight
    final List<Map<String, Object>> stats = [
      {'label': 'Muestras (n)', 'value': '${_result!.n}'},
      {'label': 'Media', 'value': _result!.mean.toStringAsFixed(4)},
      {'label': 'CV (%)', 'value': '${_result!.cv.toStringAsFixed(2)}%'}, // Nuevo
      {'label': 'Mediana', 'value': _result!.median.toStringAsFixed(4)},
      {'label': 'Moda', 'value': modeText},
      {'label': 'Desv. Est. (S)', 'value': _result!.std.toStringAsFixed(4)},
      {'label': 'Varianza (S²)', 'value': _result!.variance.toStringAsFixed(4)},
      {'label': 'Mínimo', 'value': _result!.min.toStringAsFixed(4)},
      {'label': 'Máximo', 'value': _result!.max.toStringAsFixed(4)},
      {'label': 'Rango', 'value': _result!.range.toStringAsFixed(4)},      // Restaurado
      {'label': 'Asimetría', 'value': _result!.skewness.toStringAsFixed(4)},
      {'label': 'Curtosis', 'value': _result!.kurtosis.toStringAsFixed(4)},
      {'label': 'Clases (k)', 'value': '${_result!.k}'},
      {'label': 'Amplitud (A)', 'value': _result!.amplitude.toStringAsFixed(4)},
    ];

    // Agregar Best Fit y AIC si el cálculo fue exitoso (Restaurado)
    if (_result!.bestFit != null) {
      stats.add({
        'label': 'Mejor Ajuste', 
        'value': '${_result!.bestFit!['name']}', 
        'highlight': true
      });
      stats.add({
        'label': 'AIC', 
        'value': '${(_result!.bestFit!['aic'] as num).toStringAsFixed(2)}'
      });
    }

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Resumen Estadístico", 
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)
            ),
            const Divider(),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: stats.map((item) => _statItem(
                item['label'] as String, 
                item['value'] as String,
                isHighlight: item['highlight'] == true
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Helper para items individuales con estilos de AppColors
  Widget _statItem(String label, String value, {bool isHighlight = false}) {
    return Container(
      width: 100, // Ancho fijo para alineación tipo Grid
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(
            label, 
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600), 
            textAlign: TextAlign.center, 
            maxLines: 1, 
            overflow: TextOverflow.ellipsis
          ),
          const SizedBox(height: 4),
          Text(
            value, 
            style: TextStyle(
              // Usamos AppColors.primary para mantener la identidad visual en destacados
              color: isHighlight ? AppColors.primary : Colors.black87, 
              fontWeight: FontWeight.bold, 
              fontSize: 13
            ), 
            textAlign: TextAlign.center
          ),
        ],
      ),
    );
  }

  Widget _buildResultContent(BuildContext context) {
    // Restaurando Scroll y Colores
    return Column(
      children: [
        // Histograma (igual)
        Card(color: Colors.white, margin: const EdgeInsets.all(16), child: Padding(padding: const EdgeInsets.all(16), child: SizedBox(height: 300, width: double.infinity, child: CustomPaint(painter: HistogramPainter(edges: _result!.histogram.edges, counts: _result!.histogram.counts, curveX: _result!.curves?['x'] != null ? (_result!.curves!['x'] as List).map((e)=>e as double).toList() : null, curveY: _result!.curves?['best_freq'] != null ? (_result!.curves!['best_freq'] as List).map((e)=>e as double).toList() : null))))),
        
        // Boxplot
        _buildExpandableCard("Diagrama de Caja", SizedBox(height: 150, width: double.infinity, child: BoxplotWidget(box: _result!.boxplot))),
        
        // Tallo y Hoja (RESTAURADO SCROLL)
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
        
        // Tabla Frecuencias (RESTAURADO COLOR)
        _buildExpandableCard("Tabla de Frecuencias", SizedBox(
            height: 300,
            child: FrequencyTableWidget(
              table: _result!.freqTable,
              backgroundColor: AppColors.bgCard, // Color oscuro original
              textColor: Colors.white,
            )
        ), bgColor: AppColors.bgCard, titleColor: Colors.white),
      ],
    );
  }

  Widget _buildExpandableCard(String title, Widget content, {Color bgColor = Colors.white, Color titleColor = Colors.black87}) {
    return Card(color: bgColor, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: ExpansionTile(title: Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)), iconColor: titleColor == Colors.black87 ? const Color(PRIMARY_INT) : Colors.white, collapsedIconColor: Colors.grey, children: [Padding(padding: const EdgeInsets.all(16), child: content)]));
  }
}