enum McDistType { normal, exponential, uniform }

class McVariable {
  String name;
  McDistType type;
  double param1; // Mean, Beta, Min
  double param2; // Std, -, Max
  double multiplier; // 1.0 = suma, -1.0 = resta

  McVariable({
    required this.name,
    this.type = McDistType.normal,
    this.param1 = 10,
    this.param2 = 2,
    this.multiplier = 1.0,
  });

  Map<String, dynamic> toJson() {
    Map<String, dynamic> distMap = {};
    if (type == McDistType.normal) distMap = {'Normal': {'mean': param1, 'std': param2}};
    if (type == McDistType.exponential) distMap = {'Exponential': {'beta': param1}};
    if (type == McDistType.uniform) distMap = {'Uniform': {'min': param1, 'max': param2}};

    return {
      'name': name,
      'multiplier': multiplier,
      'distribution': distMap
    };
  }
}

class McResult {
  final double mean;
  final double stdDev;
  final double min;
  final double max;
  final List<double> preview;
  final double? probability;
  final double? expectedCost;
  final int? successCount;
  final int iterations;

  McResult.fromJson(Map<String, dynamic> json)
      : mean = (json['mean'] as num).toDouble(),
        stdDev = (json['std_dev'] as num).toDouble(),
        min = (json['min'] as num).toDouble(),
        max = (json['max'] as num).toDouble(),
        preview = (json['samples_preview'] as List).map((e) => (e as num).toDouble()).toList(),
        probability = (json['probability'] as num?)?.toDouble(),
        expectedCost = (json['expected_cost'] as num?)?.toDouble(),
        successCount = json['success_count'],
        iterations = json['iterations'];
}