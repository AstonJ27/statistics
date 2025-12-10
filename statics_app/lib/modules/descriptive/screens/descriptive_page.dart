import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:ffi/ffi.dart';

// Imports de lógica
import '../../../core/ffi/native_service.dart';
import '../models/descriptive_models.dart';

// Imports de widgets 
import '../widgets/histogram_painter.dart';
import '../widgets/boxplot_widget.dart';
import '../widgets/stemleaf_widget.dart';
import '../widgets/freq_table_widget.dart';

// --- PALETA DE COLORES (Local para este archivo) ---
const int PRIMARY = 0xFF4E2ECF;
const int BG_PRIMARY = 0xFF1D1D42;
const int GREEN = 0xFF6FCF97;
const int BG_CARD = 0xFF161632;
bool COLOR_TRY = false;

// Enum local (o podría moverse a models)
enum Generator { normal, exponential, uniform }

class DescriptivePage extends StatefulWidget {
  const DescriptivePage({super.key});
  @override
  State<DescriptivePage> createState() => _DescriptivePageState();
}

class _DescriptivePageState extends State<DescriptivePage> {
  Generator _generator = Generator.normal;
  int _n = 10000;
  double _mean = 0.0;
  double _std = 1.0;
  double _beta = 1.0;

  AnalyzeResult? _result;
  bool _running = false;

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

  List<double> _toDoubles(dynamic maybeList) {
    if (maybeList == null) return <double>[];
    try {
      final List l = maybeList as List;
      return l.map((e) => (e as num).toDouble()).toList();
    } catch (e) {
      return <double>[];
    }
  }

  Future<void> _generateAndAnalyze() async {
    _applyNumericInputs();
    
    setState(() {
      _running = true;
      _result = null;
    });

    final Pointer<Double> ptr = calloc<Double>(_n);
    try {
      String dist;
      double p1 = 0.0, p2 = 1.0;
      switch (_generator) {
        case Generator.normal:
          dist = 'normal';
          p1 = _mean;
          p2 = _std;
          break;
        case Generator.exponential:
          dist = 'exponential';
          p1 = _beta;
          p2 = 0.0;
          break;
        case Generator.uniform:
        default:
          dist = 'uniform';
          p1 = 0.0;
          p2 = 0.0;
          break;
      }

      try {
        NativeService.generateSamples(ptr, _n, dist: dist, param1: p1, param2: p2);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar: $e')));
        }
        return;
      }

      try {
        final res = await Future.delayed(Duration.zero, () => NativeService.analyzeDistribution(ptr, _n, hRound: true));
        setState(() {
          _result = res;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error en análisis: $e')));
        }
        return;
      }
    } finally {
      calloc.free(ptr);
      setState(() {
        _running = false;
      });
    }
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

  // --- WIDGETS DE DISEÑO ---

  Widget _buildGeneratorDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200, 
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Generator>(
          value: _generator,
          isExpanded: false,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
          style: const TextStyle(color: Colors.black87, fontSize: 16),
          dropdownColor: Colors.grey.shade200,
          items: const [
            DropdownMenuItem(value: Generator.normal, child: Text('Normal')),
            DropdownMenuItem(value: Generator.exponential, child: Text('Exponencial')),
            DropdownMenuItem(value: Generator.uniform, child: Text('Uniforme')),
          ],
          onChanged: (g) {
            setState(() => _generator = g ?? Generator.normal);
            _updateControllers();
          },
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: const Color(PRIMARY),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Configuración de Datos",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            Wrap(
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16.0,
              runSpacing: 16.0,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Distribución", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    _buildGeneratorDropdown(),
                  ],
                ),
                
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Tamaño (N)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _nController,
                        style: const TextStyle(color: Colors.black87),
                        keyboardType: TextInputType.number,
                        onSubmitted: (_) => _applyNumericInputs(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            if (_generator != Generator.uniform)
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  if (_generator == Generator.normal) ...[
                    _buildMiniInput('Media (μ)', _meanController),
                    _buildMiniInput('Desv. (σ)', _stdController),
                  ],
                  if (_generator == Generator.exponential)
                    _buildMiniInput('Escala (β)', _betaController),
                ],
              )
            else 
               Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                 child: const Text("Distribución Uniforme (0, 1)", style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic))
               ),

            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(GREEN),
                      foregroundColor: const Color(BG_PRIMARY),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: _running 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(BG_PRIMARY), strokeWidth: 2)) 
                        : const Icon(Icons.analytics_outlined, weight: 600),
                    label: Text(
                      _running ? 'PROCESANDO...' : 'GENERAR Y ANALIZAR',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    onPressed: _running ? null : _generateAndAnalyze,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.all(16)
                  ),
                  onPressed: _running ? null : () => setState(() => _result = null),
                  icon: const Icon(Icons.refresh),
                  tooltip: "Limpiar",
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniInput(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        SizedBox(
          width: 140,
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.black87),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => _applyNumericInputs(),
          ),
        ),
      ],
    );
  }

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

    final stats = [
      {'label': 'Muestras (n)', 'value': '${_result!.n}'},
      {'label': 'Mínimo', 'value': _result!.min.toStringAsFixed(4)},
      {'label': 'Máximo', 'value': _result!.max.toStringAsFixed(4)},
      {'label': 'Rango', 'value': _result!.range.toStringAsFixed(4)},
      {'label': 'Media', 'value': _result!.mean.toStringAsFixed(4)},
      {'label': 'Mediana', 'value': _result!.median.toStringAsFixed(4)},
      {'label': 'Moda', 'value': modeText},
      {'label': 'Varianza (S²)', 'value': _result!.variance.toStringAsFixed(4)},
      {'label': 'Desv. Est. (S)', 'value': _result!.std.toStringAsFixed(4)},
      {'label': 'Asimetría', 'value': _result!.skewness.toStringAsFixed(4)},
      {'label': 'Curtosis', 'value': _result!.kurtosis.toStringAsFixed(4)},
      {'label': 'Clases (k)', 'value': '${_result!.k}'},
      {'label': 'Amplitud (A)', 'value': _result!.amplitude.toStringAsFixed(4)},
      if (_result!.bestFit != null)
        {'label': 'Mejor Ajuste', 'value': '${_result!.bestFit!['name']}', 'highlight': true},
      if (_result!.bestFit != null)
        {'label': 'AIC', 'value': '${(_result!.bestFit!['aic'] as num).toStringAsFixed(2)}'},
    ];

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Resumen Estadístico Completo", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(height: 24),
            
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth < 400 ? 2 : 3;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: stats.length,
                  itemBuilder: (context, index) {
                    final item = stats[index];
                    return _statItem(
                      item['label'] as String, 
                      item['value'] as String, 
                      isHighlight: item['highlight'] == true
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label, 
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            maxLines: 1, 
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value, 
            style: TextStyle(
              color: isHighlight ? const Color(PRIMARY) : Colors.black87, 
              fontWeight: FontWeight.bold, 
              fontSize: 13
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildControls(),
            _buildSummaryCard(),
            if (_result != null) 
              _buildResultContent(context)
            else 
              Padding(
                padding: const EdgeInsets.all(40.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.bar_chart_rounded, size: 80, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text(
                        'Configura los parámetros arriba\ny pulsa "Generar"', 
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54)
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultContent(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth > 900;
        final hist = _result!.histogram;
        final curves = _result!.curves;
        final curveX = curves != null && curves['x'] != null ? _toDoubles(curves['x']) : null;
        final curveBest = curves != null && curves['best_freq'] != null ? _toDoubles(curves['best_freq']) : null;

        final histogramWidget = Card(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Histograma y Curva", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 350,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: HistogramPainter(
                      edges: hist.edges,
                      counts: hist.counts,
                      curveX: curveX,
                      curveY: curveBest,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        final detailsColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildExpandableCard("Diagrama de Caja", 
              SizedBox(height: 150, width: double.infinity, child: BoxplotWidget(box: _result!.boxplot))),
            
            _buildExpandableCard("Tallo y Hoja", 
              SizedBox(
                height: 200, 
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: StemLeafWidget(items: _result!.stemLeaf),
                    ),
                  ),
                ),
              )
            ),
            
            _buildExpandableCard(
              "Tabla de Frecuencias", 
              SizedBox(
                height: 300, 
                child: FrequencyTableWidget(
                  table: _result!.freqTable,
                  backgroundColor: const Color(BG_CARD),
                  textColor: Colors.white,
                )
              ),
              bgColor: const Color(BG_CARD), 
              titleColor: Colors.white,
            ),
            
            if(COLOR_TRY) ...[
              _buildExpandableCard("#080812",
                SizedBox(height: 300, child: FrequencyTableWidget(table: _result!.freqTable, backgroundColor: const Color(0xFF080812), textColor: Colors.white)),
                bgColor: const Color(0xFF080812), titleColor: Colors.white,
              ),
              _buildExpandableCard("#161632",
                SizedBox(height: 300, child: FrequencyTableWidget(table: _result!.freqTable, backgroundColor: const Color(0xFF161632), textColor: Colors.white)),
                bgColor: const Color(0xFF161632), titleColor: Colors.white,
              ),
              _buildExpandableCard("#404091",
                SizedBox(height: 300, child: FrequencyTableWidget(table: _result!.freqTable, backgroundColor: const Color(0xFF404091), textColor: Colors.white)),
                bgColor: const Color(0xFF404091), titleColor: Colors.white,
              ),
              _buildExpandableCard("#4E4EB1",
                SizedBox(height: 300, child: FrequencyTableWidget(table: _result!.freqTable, backgroundColor: const Color(0xFF4E4EB1), textColor: Colors.white)),
                bgColor: const Color(0xFF4E4EB1), titleColor: Colors.white,
              ),
            ]
          ],
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: histogramWidget),
              Expanded(flex: 2, child: Padding(padding: const EdgeInsets.only(right: 16), child: detailsColumn)),
            ],
          );
        } else {
          return Column(
            children: [
              histogramWidget,
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: detailsColumn),
            ],
          );
        }
      },
    );
  }

  Widget _buildExpandableCard(String title, Widget content, {Color bgColor = Colors.white, Color titleColor = Colors.black87}) {
    return Card(
      color: bgColor, 
      surfaceTintColor: bgColor,
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          iconTheme: IconThemeData(color: titleColor == Colors.black87 ? const Color(PRIMARY) : Colors.white),
        ),
        child: ExpansionTile(
          title: Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
          iconColor: titleColor == Colors.black87 ? const Color(PRIMARY) : Colors.white,
          collapsedIconColor: titleColor == Colors.black87 ? Colors.grey : Colors.grey.shade400,
          initiallyExpanded: false,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: content,
            )
          ],
        ),
      ),
    );
  }
}