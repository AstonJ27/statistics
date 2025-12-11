import '../models/descriptive_models.dart';

enum ProbabilityType {
  lessThan,       // P(X <= x1)
  greaterThan,    // P(X >= x1)
  between,        // P(x1 <= X <= x2)
  tails           // P(X <= x1) + P(X >= x2)
}

// --- CLASES PARA EL REPORTE DETALLADO (Ahora con Probabilidades) ---

abstract class CalcStep {}

class HeaderStep extends CalcStep {
  final String message;
  HeaderStep(this.message);
}

// Paso 1: Suma de probabilidades de intervalos completos
class TrivialSumStep extends CalcStep {
  final List<double> probabilities; // Antes int frequencies
  final double total;
  TrivialSumStep(this.probabilities, this.total);
}

// Paso 2: Cálculo de interpolación usando Frecuencia Relativa
class InterpolationStep extends CalcStep {
  final String label;
  final double overlap;   
  final double width;     
  final double classRelFreq; // Frecuencia Relativa de la clase (hi)
  final double result;       // Probabilidad aportada
  
  InterpolationStep({
    required this.label, 
    required this.overlap, 
    required this.width, 
    required this.classRelFreq, 
    required this.result
  });
}

// Paso 3: Suma final (P = Trivial + Interp)
class FinalEquationStep extends CalcStep {
  final double trivialSum;
  final double interpSum;
  final double probability;

  FinalEquationStep({
    required this.trivialSum, 
    required this.interpSum, 
    required this.probability
  });
}

class ProbabilityResult {
  final double probability;
  final List<CalcStep> steps;

  ProbabilityResult({
    required this.probability,
    required this.steps,
  });
}

// --- CALCULADORA ---

class ProbabilityCalculator {
  
  static ProbabilityResult calculate(ProbabilityType type, double x1, double x2, AnalyzeResult result) {
    final table = result.freqTable;
    
    // 1. Definir rangos
    List<List<double>> ranges = [];
    // Límites prácticos "infinitos"
    double minData = table.classes.isNotEmpty ? table.classes.first.lower - 1.0 : x1 - 1000;
    double maxData = table.classes.isNotEmpty ? table.classes.last.upper + 1.0 : x1 + 1000;

    switch (type) {
      case ProbabilityType.lessThan:
        ranges.add([minData, x1]);
        break;
      case ProbabilityType.greaterThan:
        ranges.add([x1, maxData]);
        break;
      case ProbabilityType.between:
        double minV = x1 < x2 ? x1 : x2;
        double maxV = x1 < x2 ? x2 : x1;
        ranges.add([minV, maxV]);
        break;
      case ProbabilityType.tails:
        double left = x1 < x2 ? x1 : x2;
        double right = x1 < x2 ? x2 : x1;
        ranges.add([minData, left]);
        ranges.add([right, maxData]);
        break;
    }

    // 2. Procesar intersecciones
    List<double> trivialProbs = [];
    List<InterpolationStep> interpolations = [];
    double totalProbCalculated = 0.0;
    List<CalcStep> displaySteps = [];

    if (table.classes.isEmpty) {
      return ProbabilityResult(probability: 0, steps: [HeaderStep("No hay datos disponibles.")]);
    }

    for (var range in ranges) {
      double rStart = range[0];
      double rEnd = range[1];
      
      // Solo mostramos header de rango si es complejo (colas)
      if (ranges.length > 1) {
         // Opcional: displaySteps.add(HeaderStep("Rango..."));
      }

      for (var c in table.classes) {
        double intersectStart = rStart > c.lower ? rStart : c.lower;
        double intersectEnd = rEnd < c.upper ? rEnd : c.upper;

        if (intersectEnd > intersectStart) {
          double overlapWidth = intersectEnd - intersectStart;
          double classWidth = c.upper - c.lower;
          
          if (classWidth <= 0) continue;

          double fraction = overlapWidth / classWidth;
          // Usamos Frecuencia Relativa (probabilidad de la clase)
          double contribution = c.relFreq * fraction;
          
          bool isFull = fraction > 0.999999; 
          totalProbCalculated += contribution;

          if (isFull) {
            trivialProbs.add(c.relFreq);
          } else {
            interpolations.add(InterpolationStep(
              label: "[${c.lower.toStringAsFixed(2)}, ${c.upper.toStringAsFixed(2)})",
              overlap: overlapWidth,
              width: classWidth,
              classRelFreq: c.relFreq,
              result: contribution
            ));
          }
        }
      }
    }

    // --- CONSTRUCCIÓN DE PASOS VISUALES ---
    
    // 1. Suma Trivial (Probabilidades directas)
    double trivialSum = trivialProbs.fold(0.0, (a, b) => a + b);
    if (trivialProbs.isNotEmpty) {
      displaySteps.add(HeaderStep("1. Suma Trivial (Probabilidades completas):"));
      displaySteps.add(TrivialSumStep(trivialProbs, trivialSum));
    } else {
      displaySteps.add(HeaderStep("1. Suma Trivial: 0 (Ningún intervalo completo)"));
    }

    // 2. Interpolaciones (Probabilidades parciales)
    double interpSum = 0.0;
    if (interpolations.isNotEmpty) {
      displaySteps.add(HeaderStep("2. Interpolaciones (Proporciones):"));
      for (var step in interpolations) {
        displaySteps.add(step);
        interpSum += step.result;
      }
    } else {
      displaySteps.add(HeaderStep("2. Interpolaciones: 0"));
    }

    // 3. Suma Final
    displaySteps.add(HeaderStep("3. Cálculo Final:"));
    displaySteps.add(FinalEquationStep(
      trivialSum: trivialSum,
      interpSum: interpSum,
      probability: totalProbCalculated
    ));

    return ProbabilityResult(
      probability: totalProbCalculated,
      steps: displaySteps
    );
  }
}