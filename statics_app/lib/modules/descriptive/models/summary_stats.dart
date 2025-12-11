class SummaryStats {
  final int n;
  final double mean;
  final double std;       // Desviación Muestral
  final double variance;  // Varianza Muestral
  final double cv;        // Coeficiente de Variación
  final double median;
  final List<double> mode; 
  final double skewness;
  final double kurtosis;
  final double min;
  final double max;
  final double range;
  final int k;            
  final double amplitude;

  SummaryStats({
    required this.n,
    required this.mean,
    required this.std,
    required this.variance,
    required this.cv,
    required this.median,
    required this.mode,
    required this.skewness,
    required this.kurtosis,
    required this.min,
    required this.max,
    required this.range,
    required this.k,
    required this.amplitude,
  });

  factory SummaryStats.fromJson(Map<String, dynamic> json) {
    return SummaryStats(
      n: (json['n'] as num).toInt(),
      mean: (json['mean'] as num).toDouble(),
      std: (json['std_sample'] as num).toDouble(),
      variance: (json['variance_sample'] as num).toDouble(),
      cv: (json['cv'] ?? 0.0).toDouble(),
      median: (json['median'] as num).toDouble(),
      mode: (json['mode'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [],
      skewness: (json['skewness'] as num).toDouble(),
      kurtosis: (json['kurtosis_excess'] as num).toDouble(),
      min: (json['min'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
      range: (json['range'] as num).toDouble(),
      k: (json['k'] as num).toInt(),
      amplitude: (json['amplitude'] as num).toDouble(),
    );
  }
}