import 'histogram_model.dart';
import 'frequency_table_model.dart';
import 'boxplot_model.dart';
import 'stem_leaf_model.dart';
import 'summary_stats.dart';

class AnalyzeResult {
  final HistogramData histogram;
  final FrequencyTable freqTable;
  final Boxplot boxplot;
  final List<StemLeafItem> stemLeaf;
  final SummaryStats summary; // <--- Nuevo objeto encapsulado
  
  final Map<String, dynamic>? bestFit;
  final Map<String, dynamic>? curves;

  AnalyzeResult({
    required this.histogram, 
    required this.freqTable, 
    required this.boxplot, 
    required this.stemLeaf, 
    required this.summary,
    this.bestFit, 
    this.curves, 
  });
  
  factory AnalyzeResult.fromJson(Map<String, dynamic> j) {
    return AnalyzeResult(
      histogram: HistogramData.fromJson(j['histogram']),
      freqTable: FrequencyTable.fromJson(j['freq_table']),
      boxplot: Boxplot.fromJson(j['boxplot']),
      stemLeaf: (j['stem_leaf'] as List).map((e) => StemLeafItem.fromJson(e as Map<String, dynamic>)).toList(),
      summary: SummaryStats.fromJson(j['summary']),
      curves: j['curves'] != null ? Map<String,dynamic>.from(j['curves'] as Map) : null,
      bestFit: j['best_fit'] != null ? Map<String,dynamic>.from(j['best_fit'] as Map) : null,
    );
  }

  // --- Getters de Compatibilidad (Delegados) ---
  // Esto permite que el código UI existente siga funcionando sin cambios (ej: result.mean)
  int get n => summary.n;
  double get mean => summary.mean;
  double get std => summary.std;
  double get variance => summary.variance;
  double get cv => summary.cv;
  double get median => summary.median;
  List<double> get mode => summary.mode;
  double get skewness => summary.skewness;
  double get kurtosis => summary.kurtosis;
  double get min => summary.min;
  double get max => summary.max;
  double get range => summary.range;
  int get k => summary.k;
  double get amplitude => summary.amplitude;
}