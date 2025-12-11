class HistogramData {
  final int k;
  final double amplitude;
  final List<double> edges;
  final List<double> centers;
  final List<int> counts;
  final List<double>? densities;
  
  HistogramData({
    required this.k, 
    required this.amplitude, 
    required this.edges, 
    required this.centers, 
    required this.counts, 
    this.densities
  });
  
  factory HistogramData.fromJson(Map<String, dynamic> j) {
    return HistogramData(
      k: j['k'] as int,
      amplitude: (j['amplitude'] as num).toDouble(),
      edges: (j['edges'] as List).map((e) => (e as num).toDouble()).toList(),
      centers: (j['centers'] as List).map((e) => (e as num).toDouble()).toList(),
      counts: (j['counts'] as List).map((e) => (e as num).toInt()).toList(),
      densities: j['densities'] != null ? (j['densities'] as List).map((e) => (e as num).toDouble()).toList() : null,
    );
  }
}