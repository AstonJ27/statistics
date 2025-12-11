import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/descriptive_models.dart';   // Ahora trae el Enum Generator
//import '../screens/descriptive_page.dart'; // Para el Enum Generator

class GeneratorFormCard extends StatelessWidget {
  final Generator selectedGenerator;
  final TextEditingController nCtrl;
  final TextEditingController meanCtrl;
  final TextEditingController stdCtrl;
  final TextEditingController betaCtrl;
  final bool isRunning;
  final VoidCallback onGenerate;
  final VoidCallback onReset;
  final Function(Generator) onGeneratorChanged;

  // Constantes de color (importadas o redefinidas si son locales)
  static const int PRIMARY_INT = 0xFF4E2ECF;
  static const int GREEN_INT = 0xFF6FCF97;

  const GeneratorFormCard({
    super.key,
    required this.selectedGenerator,
    required this.nCtrl,
    required this.meanCtrl,
    required this.stdCtrl,
    required this.betaCtrl,
    required this.isRunning,
    required this.onGenerate,
    required this.onReset,
    required this.onGeneratorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: const Color(PRIMARY_INT),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Configuración de Datos", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.start, 
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16.0, 
              runSpacing: 16.0,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    const Text("Distribución", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    _buildGeneratorDropdown(),
                  ]
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Tamaño (N)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    SizedBox(width: 120, child: _miniTextField(nCtrl)),
                ]),
              ],
            ),
            const SizedBox(height: 20),
            if (selectedGenerator != Generator.uniform)
              Wrap(spacing: 16, runSpacing: 16, children: [
                  if (selectedGenerator == Generator.normal) ...[
                    _buildLabeledMiniInput('Media (μ)', meanCtrl),
                    _buildLabeledMiniInput('Desv. (σ)', stdCtrl),
                  ],
                  if (selectedGenerator == Generator.exponential)
                    _buildLabeledMiniInput('Escala (β)', betaCtrl),
              ]),
            const SizedBox(height: 24),
            Row(children: [
                Expanded(child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(GREEN_INT), 
                      foregroundColor: AppColors.bgPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    icon: isRunning ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.analytics_outlined),
                    label: Text(isRunning ? 'PROCESANDO...' : 'GENERAR Y ANALIZAR', style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: isRunning ? null : onGenerate,
                )),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  style: IconButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(16)),
                  onPressed: isRunning ? null : onReset,
                  icon: const Icon(Icons.refresh),
                )
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratorDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Generator>(
          value: selectedGenerator, isDense: true,
          dropdownColor: Colors.grey.shade200,
          style: const TextStyle(color: Colors.black87, fontSize: 16),
          items: const [DropdownMenuItem(value: Generator.normal, child: Text('Normal')), DropdownMenuItem(value: Generator.exponential, child: Text('Exponencial')), DropdownMenuItem(value: Generator.uniform, child: Text('Uniforme'))],
          onChanged: (g) { if(g != null) onGeneratorChanged(g); },
        ),
      ),
    );
  }

  Widget _buildLabeledMiniInput(String label, TextEditingController ctrl) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        SizedBox(width: 140, child: _miniTextField(ctrl)),
    ]);
  }

  Widget _miniTextField(TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.black87),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        filled: true, fillColor: Colors.grey.shade200,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      // Nota: Al sacar esto, perdemos el _applyNumericInputs automático en 'submit',
      // pero el usuario apretará el botón "GENERAR" de todas formas.
    );
  }
}