class FrequencyClass {
  final double lower;
  final double upper;
  final double midpoint;
  final int absFreq;
  final double relFreq;
  final int cumAbs;
  final double cumRel;
  
  FrequencyClass({
    required this.lower, 
    required this.upper, 
    required this.midpoint, 
    required this.absFreq, 
    required this.relFreq, 
    required this.cumAbs, 
    required this.cumRel
  });
  
  factory FrequencyClass.fromJson(Map<String, dynamic> j) {
    return FrequencyClass(
      lower: (j['lower'] as num).toDouble(),
      upper: (j['upper'] as num).toDouble(),
      midpoint: (j['midpoint'] as num).toDouble(),
      absFreq: (j['abs_freq'] as num).toInt(),
      relFreq: (j['rel_freq'] as num).toDouble(),
      cumAbs: (j['cum_abs'] as num).toInt(),
      cumRel: (j['cum_rel'] as num).toDouble(),
    );
  }
}

class FrequencyTable {
  final List<FrequencyClass> classes;
  final double amplitude;

  FrequencyTable({required this.classes, required this.amplitude});
  
  factory FrequencyTable.fromJson(Map<String, dynamic> j) {
    final cls = (j['classes'] as List).map((e) => FrequencyClass.fromJson(e as Map<String, dynamic>)).toList();
    return FrequencyTable(
      classes: cls, amplitude: (j['amplitude'] as num).toDouble());
  }
}