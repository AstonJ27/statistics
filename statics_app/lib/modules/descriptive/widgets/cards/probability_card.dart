import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/descriptive_models.dart';
import '../../utils/probability_calculator.dart';

class ProbabilityCard extends StatefulWidget {
  final AnalyzeResult result;

  const ProbabilityCard({super.key, required this.result});

  @override
  State<ProbabilityCard> createState() => _ProbabilityCardState();
}

class _ProbabilityCardState extends State<ProbabilityCard> {
  ProbabilityType _type = ProbabilityType.between;
  
  final TextEditingController _x1Ctrl = TextEditingController();
  final TextEditingController _x2Ctrl = TextEditingController();
  
  ProbabilityResult? _resultData;

  @override
  void initState() {
    super.initState();
    _initializeDefaults();
  }

  @override
  void didUpdateWidget(covariant ProbabilityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result) {
       _initializeDefaults();
       _resultData = null;
    }
  }

  void _initializeDefaults() {
    double mean = widget.result.mean;
    double std = widget.result.std;
    _x1Ctrl.text = (mean - std).toStringAsFixed(2);
    _x2Ctrl.text = (mean + std).toStringAsFixed(2);
  }

  void _calculate() {
    final x1 = double.tryParse(_x1Ctrl.text);
    final x2 = double.tryParse(_x2Ctrl.text);

    if (x1 == null) return;
    if ((_type == ProbabilityType.between || _type == ProbabilityType.tails) && x2 == null) return;

    setState(() {
      _resultData = ProbabilityCalculator.calculate(_type, x1, x2 ?? 0, widget.result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ExpansionTile(
        title: const Text("Calculadora de Probabilidades", 
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)
        ),
        subtitle: const Text("Interpolación lineal detallada", 
          style: TextStyle(color: Colors.grey, fontSize: 12)
        ),
        iconColor: AppColors.primary, 
        collapsedIconColor: Colors.grey,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ProbabilityType>(
                      value: _type,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                      items: const [
                        DropdownMenuItem(value: ProbabilityType.lessThan, child: Text("Menor que: P(X ≤ x₁)")),
                        DropdownMenuItem(value: ProbabilityType.greaterThan, child: Text("Mayor que: P(X ≥ x₁)")),
                        DropdownMenuItem(value: ProbabilityType.between, child: Text("Entre: P(x₁ ≤ X ≤ x₂)")),
                        DropdownMenuItem(value: ProbabilityType.tails, child: Text("Colas: P(X ≤ x₁) + P(X ≥ x₂)")),
                      ],
                      onChanged: (v) => setState(() { _type = v!; _resultData = null; }),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Inputs
                Row(children: [
                    Expanded(child: _buildInput(_x1Ctrl, "Valor x₁")),
                    if (_type == ProbabilityType.between || _type == ProbabilityType.tails) ...[
                      const SizedBox(width: 12),
                      Expanded(child: _buildInput(_x2Ctrl, "Valor x₂")),
                    ]
                ]),
                
                const SizedBox(height: 16),
                
                // Botón
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                    ),
                    onPressed: _calculate,
                    child: const Text("CALCULAR", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),

                // Resultados
                if (_resultData != null) _buildResultView()
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildResultView() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.green.withOpacity(0.5))
          ),
          child: Column(
            children: [
              const Text("Probabilidad Total Estimada", style: TextStyle(fontSize: 12, color: Colors.black54)),
              Text(
                "${(_resultData!.probability * 100).toStringAsFixed(4)}%", 
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.bgPrimary)
              ),
            ],
          ),
        ),
        
        const Divider(height: 24, thickness: 1),
        
        const Align(
          alignment: Alignment.centerLeft,
          child: Text("Desglose del Cálculo:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))
        ),
        const SizedBox(height: 10),
        
        // --- LISTA DE PASOS ---
        Container(
          constraints: const BoxConstraints(maxHeight: 250),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _resultData!.steps.map((step) => _buildStepItem(step)).toList(),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildStepItem(CalcStep step) {
    // 1. ENCABEZADOS
    if (step is HeaderStep) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(step.message, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13)),
      );
    } 
    
    // 2. SUMA TRIVIAL (Probabilidades)
    if (step is TrivialSumStep) {
      // Formateamos los doubles
      String sumText = step.probabilities.map((e) => e.toStringAsFixed(4)).join(" + ");
      if (sumText.length > 50) sumText = "${sumText.substring(0, 47)}..."; 
      
      return Container(
        margin: const EdgeInsets.only(bottom: 4, left: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6)),
        child: Row(
          children: [
            const Text("P_bins: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
            Expanded(
              child: Text(
                "$sumText = ${step.total.toStringAsFixed(4)}", 
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    
    // 3. INTERPOLACIONES (Visualmente fraccionaria)
    if (step is InterpolationStep) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8, left: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.orange.withOpacity(0.3))
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${step.label}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  "Calc: ", 
                  style: TextStyle(fontSize: 11, color: Colors.black54)
                ),
                // Fracción visual
                Column(
                  children: [
                    Text(
                      step.overlap.toStringAsFixed(2),
                      // AGREGADO: color: Colors.black87
                      style: const TextStyle(fontSize: 10, color: Colors.black87) 
                    ),
                    Container(height: 1, width: 24, color: Colors.black87), // Línea divisoria
                    Text(
                      step.width.toStringAsFixed(2), 
                      // AGREGADO: color: Colors.black87
                      style: const TextStyle(fontSize: 10, color: Colors.black87)
                    ),
                  ],
                ),
                // Multiplicado por frecuencia relativa
                // AGREGADO: color: Colors.black87
                Text(" × ${step.classRelFreq.toStringAsFixed(4)} = ", style: const TextStyle(fontSize: 11, color: Colors.black87)),
                
                Text(step.result.toStringAsFixed(4), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
              ],
            ),
          ],
        ),
      );
    }

    // 4. ECUACIÓN FINAL (Suma de partes)
    if (step is FinalEquationStep) {
      return Container(
        margin: const EdgeInsets.only(top: 8, left: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("P = ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text(
              "${step.trivialSum.toStringAsFixed(4)}", 
              style: const TextStyle(color: Colors.white70, fontSize: 12)
            ),
            const Text(" + ", style: TextStyle(color: Colors.white, fontSize: 12)),
            Text(
              "${step.interpSum.toStringAsFixed(4)}", 
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)
            ),
            const Text(" = ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text(
              step.probability.toStringAsFixed(4), 
              style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold, fontSize: 16)
            ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildInput(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      // 1. Color del texto que se escribe (Cursor y Texto)
      style: const TextStyle(color: Colors.black87), 
      cursorColor: AppColors.primary, // Opcional: cursor morado para que combine
      decoration: InputDecoration(
        labelText: label,
        // 2. Color de la etiqueta ("Valor x1") cuando está en reposo y flotando
        labelStyle: const TextStyle(color: Colors.black54), 
        floatingLabelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
        
        filled: true,
        // 3. Fondo grisaceo claro para diferenciar el input del card blanco
        fillColor: Colors.grey.shade100, 
        
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        
        // Bordes suaves en gris
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        
        // Borde morado al enfocar
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), 
          borderSide: const BorderSide(color: AppColors.primary, width: 2)
        ),
      ),
    );
  }
}