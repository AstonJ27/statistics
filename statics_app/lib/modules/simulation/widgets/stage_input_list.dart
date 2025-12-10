import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/simulation_models.dart'; 

class StageInputList extends StatelessWidget {
  final List<StageInput> stages;
  final Function(int) onRemove;
  final VoidCallback onAdd;
  final Function(StageInput, Generator) onTypeChanged; // Callback para actualizar el tipo

  const StageInputList({
    super.key,
    required this.stages,
    required this.onRemove,
    required this.onAdd,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text("Estaciones del Autolavado", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))
        ),
        const SizedBox(height: 5),
        
        ...stages.asMap().entries.map((entry) {
          int idx = entry.key;
          StageInput stage = entry.value;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: AppColors.bgCard,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary, 
                        radius: 12, 
                        child: Text("${idx+1}", style: const TextStyle(fontSize: 12, color: Colors.white))
                      ),
                      const SizedBox(width: 10),
                      // Dropdown
                      Expanded(
                        child: DropdownButton<Generator>(
                          value: stage.type,
                          dropdownColor: AppColors.bgCard,
                          isDense: true,
                          style: const TextStyle(color: Colors.white),
                          underline: Container(),
                          items: const [
                            DropdownMenuItem(value: Generator.normal, child: Text("Normal")),
                            DropdownMenuItem(value: Generator.exponential, child: Text("Exponencial")),
                            DropdownMenuItem(value: Generator.uniform, child: Text("Uniforme")),
                          ],
                          onChanged: (g) {
                            if (g != null) onTypeChanged(stage, g);
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                        onPressed: () => onRemove(idx),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Inputs
                  Row(
                    children: [
                      if (stage.type == Generator.normal) ...[
                        Expanded(child: _buildInput(stage.p1Ctrl, "Media (μ)")),
                        const SizedBox(width: 10),
                        Expanded(child: _buildInput(stage.p2Ctrl, "Varianza (σ²)")),
                      ] else if (stage.type == Generator.exponential) ...[
                        Expanded(child: _buildInput(stage.p1Ctrl, "Beta (β)")),
                      ] else ...[
                        Expanded(child: _buildInput(stage.p1Ctrl, "Mínimo")),
                        const SizedBox(width: 10),
                        Expanded(child: _buildInput(stage.p2Ctrl, "Máximo")),
                      ]
                    ],
                  )
                ],
              ),
            ),
          );
        }).toList(),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white),
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text("Agregar Estación"),
        ),
      ],
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.black12,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }
}