// lib/main.dart
import 'dart:convert'; // Necesario para decodificar el JSON de la simulación
import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:ffi/ffi.dart';

// Asegúrate de que estos archivos existan y estén actualizados en tu proyecto
import 'ffi_bindings.dart';
import 'services.dart';
import 'models.dart';
import 'widgets/histogram_painter.dart';
import 'widgets/boxplot_widget.dart';
import 'widgets/stemleaf_widget.dart';
import 'widgets/freq_table_widget.dart';

// --- PALETA DE COLORES ---
const int PRIMARY = 0xFF4E2ECF;       // #4E2ECF (Morado Principal)
const int BG_PRIMARY = 0xFF1D1D42;    // #1D1D42 (Fondo Oscuro)
const int GREEN = 0xFF6FCF97;         // #6FCF97 (Acción / Éxito)
const int BG_CARD = 0xFF161632;       // #161632

// Para debugg y prueba de colores
bool COLOR_TRY = false;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StaticsApp());
}

class StaticsApp extends StatelessWidget {
  const StaticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Statics App',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(PRIMARY),
        scaffoldBackgroundColor: const Color(BG_PRIMARY),
        cardTheme: CardThemeData(
          color: const Color(BG_CARD),
          surfaceTintColor: const Color(BG_CARD),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        // Estilo base para inputs
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade200, 
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(GREEN), width: 2),
          ),
          labelStyle: TextStyle(color: Colors.grey.shade700),
          floatingLabelStyle: const TextStyle(color: Colors.white),
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),
        // Estilo para ExpansionTiles
        dividerTheme: const DividerThemeData(color: Colors.transparent),
      ),
      // En lugar de HomePage directo, vamos al Shell de navegación
      home: const MainNavigationShell(),
    );
  }
}

// =============================================================================
// NAVIGATOR SHELL (SIDEBAR & APPBAR)
// =============================================================================

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;

  // Lista de páginas. Note que DescriptivePage ya no tiene Scaffold propio.
  final List<Widget> _pages = [
    const DescriptivePage(),
    const SimulationPage(),
  ];

  final List<String> _titles = [
    'Análisis Descriptivo',
    'Simulación Montecarlo'
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // Cierra el Drawer
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // App Bar Global
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _titles[_selectedIndex], 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // Sidebar (Drawer)
      drawer: Drawer(
        backgroundColor: const Color(BG_CARD),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(PRIMARY)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_rounded, size: 48, color: Colors.white),
                  SizedBox(height: 10),
                  Text('Rust Stats Core', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart, color: Colors.white70),
              title: const Text('Distribuciones', style: TextStyle(color: Colors.white)),
              selected: _selectedIndex == 0,
              selectedTileColor: const Color(PRIMARY).withOpacity(0.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              leading: const Icon(Icons.local_car_wash, color: Colors.white70),
              title: const Text('Simulación Autolavado', style: TextStyle(color: Colors.white)),
              selected: _selectedIndex == 1,
              selectedTileColor: const Color(PRIMARY).withOpacity(0.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () => _onItemTapped(1),
            ),
          ],
        ),
      ),
      // Cuerpo dinámico
      body: _pages[_selectedIndex],
    );
  }
}

// =============================================================================
// PAGINA 1: DESCRIPTIVA (Tu código original refactorizado)
// =============================================================================

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
    // NOTA: Aquí hemos quitado el Scaffold y AppBar porque el MainNavigationShell ya los provee.
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

// =============================================================================
// PAGINA 2: SIMULACIÓN DE AUTOLAVADO
// =============================================================================

class SimulationPage extends StatefulWidget {
  const SimulationPage({super.key});

  @override
  State<SimulationPage> createState() => _SimulationPageState();
}

class _SimulationPageState extends State<SimulationPage> {
  // Lambda = 3 (default)
  final TextEditingController _lambdaCtrl = TextEditingController(text: "3.0");
  final TextEditingController _hoursCtrl = TextEditingController(text: "10");
  
  SimResult? _result;
  bool _loading = false;
  String _error = '';

  Future<void> _runSimulation() async {
    setState(() { _loading = true; _error = ''; _result = null; });
    try {
      double lambda = double.tryParse(_lambdaCtrl.text) ?? 3.0;
      int hours = int.tryParse(_hoursCtrl.text) ?? 10;
      
      if(lambda < 0) throw Exception("Lambda no puede ser negativo");
      if(hours <= 0) throw Exception("Horas deben ser mayor a 0");

      // Llamada al servicio Rust
      final jsonStr = await Future.delayed(Duration.zero, () => NativeService.simulateCarwash(hours, lambda));
      
      // Decodificación
      final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);
      
      // Verificación de errores que vienen en el JSON (del backend)
      if (jsonMap.containsKey('error')) {
        throw Exception(jsonMap['error']);
      }

      setState(() {
        _result = SimResult.fromJson(jsonMap);
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
            // Panel de Control
            Card(
              color: const Color(BG_CARD),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Parámetros de Simulación (Poisson)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 5),
                    const Text(
                      "Simula llegadas por hora (λ) y tiempos de servicio (Normal + Exp + Unif).", 
                      style: TextStyle(color: Colors.white54, fontSize: 12)
                    ),
                    const SizedBox(height: 15),
                    
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Llegadas/Hora (λ)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _lambdaCtrl,
                                style: const TextStyle(color: Colors.black87),
                                decoration: const InputDecoration(hintText: "Ej. 3.0"),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Horas a Simular", style: TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _hoursCtrl,
                                style: const TextStyle(color: Colors.black87),
                                decoration: const InputDecoration(hintText: "Ej. 10"),
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(PRIMARY),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _loading ? null : _runSimulation,
                        icon: _loading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.play_arrow_rounded),
                        label: const Text("EJECUTAR SIMULACIÓN"),
                      ),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_error.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text(_error, style: const TextStyle(color: Colors.redAccent)),
              ),

            // Resultados
            if (_result != null) ...[
              // Resumen Global
              Card(
                color: const Color(GREEN).withOpacity(0.2),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(GREEN))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem("Total Autos", "${_result!.totalCars}", Icons.directions_car),
                      Container(width: 1, height: 40, color: Colors.white24),
                      _buildSummaryItem("Promedio Total", "${_result!.avgTotalTime.toStringAsFixed(2)} min", Icons.timer),
                      Container(width: 1, height: 40, color: Colors.white24),
                      _buildSummaryItem("Desv. Estándar", "${_result!.stdTotalTime.toStringAsFixed(2)} min", Icons.show_chart),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              const Align(
                alignment: Alignment.centerLeft, 
                child: Text("Detalle por Hora", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))
              ),
              const SizedBox(height: 10),
              
              // Lista de Horas (No usamos Expanded porque ya estamos en un SingleScrollView)
              ListView.builder(
                shrinkWrap: true, // Importante dentro de scroll
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _result!.hours.length,
                itemBuilder: (ctx, i) {
                  final h = _result!.hours[i];
                  return Card(
                    color: const Color(BG_CARD),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ExpansionTile(
                      shape: const Border(), // Quita bordes extra
                      title: Text(
                        "Hora ${h.hourIndex}", 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
                      ),
                      subtitle: Text(
                        "${h.carsArrived} vehículos llegaron", 
                        style: const TextStyle(color: Colors.grey)
                      ),
                      iconColor: const Color(PRIMARY),
                      collapsedIconColor: Colors.grey,
                      children: h.cars.isEmpty 
                      ? [
                          const Padding(
                            padding: EdgeInsets.all(16.0), 
                            child: Text("Sin actividad en esta hora.", style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic))
                          )
                        ]
                      : h.cars.map((car) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                        leading: CircleAvatar(
                          backgroundColor: Colors.white10,
                          radius: 16,
                          child: Text("${car.carId}", style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Tiempo Total:", style: TextStyle(color: Colors.white70, fontSize: 14)),
                            Text("${car.totalTime.toStringAsFixed(2)} min", style: const TextStyle(color: Color(GREEN), fontWeight: FontWeight.bold)),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "Limpieza: ${car.cleanTime.toStringAsFixed(1)}  |  Lavado: ${car.washTime.toStringAsFixed(1)}  |  Secado: ${car.dryTime.toStringAsFixed(1)}",
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ),
                      )).toList(),
                    ),
                  );
                },
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(GREEN), size: 28),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}