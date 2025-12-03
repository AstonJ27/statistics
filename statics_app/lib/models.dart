// lib/models.dart
import 'dart:convert';

// --- Histogram Data ---

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

// --- Frequency Table ---

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

class StemLeafItem {
  final int stem;
  final List<int> leaves;
  StemLeafItem({required this.stem, required this.leaves});
  factory StemLeafItem.fromJson(Map<String, dynamic> j) {
    return StemLeafItem(stem: (j['stem'] as num).toInt(), leaves: (j['leaves'] as List).map((e) => (e as num).toInt()).toList());
  }
}

class AnalyzeResult {
  final HistogramData histogram;
  final FrequencyTable freqTable;
  final Boxplot boxplot;
  final List<StemLeafItem> stemLeaf;
  final Map<String, dynamic>? bestFit;
  final Map<String, dynamic>? curves;

  final int n;
  final double mean;
  final double std;       // Desviación Muestral
  final double variance;  // Varianza Muestral
  final double median;
  final List<double> mode; // Puede ser multimodal, por eso es lista
  final double skewness;
  final double kurtosis;
  final double min;
  final double max;
  final double range;
  final int k;            // Número de clases
  final double amplitude; // Amplitud (W)
  
  AnalyzeResult({
    required this.histogram, 
    required this.freqTable, 
    required this.boxplot, 
    required this.stemLeaf, 
    this.bestFit, 
    this.curves, 
    required this.n, 
    required this.mean, 
    required this.std,
    required this.variance,
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
  
  
  factory AnalyzeResult.fromJson(Map<String, dynamic> j) {
    
    double toD(dynamic v) => (v == null) ? 0.0 : (v as num).toDouble();
    int toI(dynamic v) => (v == null) ? 0 : (v as num).toInt();

    final hist = HistogramData.fromJson(j['histogram']);
    final freq = FrequencyTable.fromJson(j['freq_table']);
    final bp = Boxplot.fromJson(j['boxplot']);
    final sl = (j['stem_leaf'] as List).map((e) => StemLeafItem.fromJson(e as Map<String, dynamic>)).toList();
    final cur = j['curves'] != null ? Map<String,dynamic>.from(j['curves'] as Map) : null;
    final bf = j['best_fit'] != null ? Map<String,dynamic>.from(j['best_fit'] as Map) : null;
    
    // si algo falla cambiar summary por s
    final summary = j['summary'] as Map<String,dynamic>;
    
    return AnalyzeResult(
      histogram: hist,
      freqTable: freq,
      boxplot: bp,
      stemLeaf: sl,
      curves: cur,
      bestFit: bf,
      // Mapeo de los nuevos campos
      n: (summary['n'] as num).toInt(),
      mean: (summary['mean'] as num).toDouble(),
      // Nota: En Rust mandamos 'std_sample' y 'variance_sample'
      std: (summary['std_sample'] as num).toDouble(),
      variance: (summary['variance_sample'] as num).toDouble(),
      median: (summary['median'] as num).toDouble(),
      
      mode: (summary['mode'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [],
      skewness: (summary['skewness'] as num).toDouble(),
      kurtosis: (summary['kurtosis_excess'] as num).toDouble(),
      
      min: (summary['min'] as num).toDouble(),
      max: (summary['max'] as num).toDouble(),
      range: (summary['range'] as num).toDouble(),
      k: (summary['k'] as num).toInt(),
      amplitude: (summary['amplitude'] as num).toDouble(),
    );
  }
}

// --- SIMULATION MODELS ---

class SimResult {
  final List<SimHour> hours;
  final int totalCars;
  final double avgTotalTime;
  final double stdTotalTime;

  SimResult({
    required this.hours,
    required this.totalCars,
    required this.avgTotalTime,
    required this.stdTotalTime,
  });

  factory SimResult.fromJson(Map<String, dynamic> json) {
    return SimResult(
      hours: (json['hours'] as List).map((e) => SimHour.fromJson(e)).toList(),
      totalCars: json['total_cars'] as int,
      avgTotalTime: (json['avg_total_time'] as num).toDouble(),
      stdTotalTime: (json['std_total_time'] as num).toDouble(),
    );
  }
}

class SimHour {
  final int hourIndex;
  final int carsArrived;
  final List<SimCar> cars;

  SimHour({required this.hourIndex, required this.carsArrived, required this.cars});

  factory SimHour.fromJson(Map<String, dynamic> json) {
    return SimHour(
      hourIndex: json['hour_index'] as int,
      carsArrived: json['cars_arrived'] as int,
      cars: (json['cars'] as List).map((e) => SimCar.fromJson(e)).toList(),
    );
  }
}

class SimCar {
  final int carId;
  final double cleanTime;
  final double washTime;
  final double dryTime;
  final double totalTime;

  SimCar({
    required this.carId,
    required this.cleanTime,
    required this.washTime,
    required this.dryTime,
    required this.totalTime,
  });

  factory SimCar.fromJson(Map<String, dynamic> json) {
    return SimCar(
      carId: json['car_id'] as int,
      cleanTime: (json['clean_time'] as num).toDouble(),
      washTime: (json['wash_time'] as num).toDouble(),
      dryTime: (json['dry_time'] as num).toDouble(),
      totalTime: (json['total_time'] as num).toDouble(),
    );
  }
}