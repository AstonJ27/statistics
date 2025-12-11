class Boxplot {
  final double min;
  final double q1;
  final double median;
  final double q3;
  final double max;
  final double iqr;
  final double lowerFence;
  final double upperFence;
  final List<double> outliers;
  
  Boxplot({
    required this.min, 
    required this.q1, 
    required this.median, 
    required this.q3, 
    required this.max, 
    required this.iqr, 
    required this.lowerFence, 
    required this.upperFence, 
    required this.outliers
  });
  
  factory Boxplot.fromJson(Map<String, dynamic> j) {
    return Boxplot(
      min: (j['min'] as num).toDouble(),
      q1: (j['q1'] as num).toDouble(),
      median: (j['median'] as num).toDouble(),
      q3: (j['q3'] as num).toDouble(),
      max: (j['max'] as num).toDouble(),
      iqr: (j['iqr'] as num).toDouble(),
      lowerFence: (j['lower_fence'] as num).toDouble(),
      upperFence: (j['upper_fence'] as num).toDouble(),
      outliers: (j['outliers'] as List).map((e) => (e as num).toDouble()).toList(),
    );
  }
}