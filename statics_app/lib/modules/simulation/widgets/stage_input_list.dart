import 'package:flutter/material.dart';
import '../models/simulation_models.dart';
import '../../../core/theme/app_colors.dart'; // Asegúrate de la ruta correcta

class StageInputList extends StatelessWidget {
  final List<StageInput> stages;
  final Function(int) onRemove;
  final VoidCallback onAdd;
  // Callback para notificar cambios y reconstruir la UI (importante para actualizar los labels)
  final Function(StageInput, Generator)? onTypeChanged; 

  const StageInputList({
    super.key, 
    required this.stages, 
    required this.onRemove,
    required this.onAdd,
    this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...stages.asMap().entries.map((entry) {
          int idx = entry.key;
          StageInput stage = entry.value;

          // Lógica para etiquetas dinámicas
          String labelP1 = "Parámetro 1";
          String labelP2 = "Parámetro 2";
          bool showP2 = true;

          switch (stage.type) {
            case Generator.normal:
              labelP1 = "Media (μ)";
              labelP2 = "Desviación (σ)";
              break;
            case Generator.exponential:
              // Aquí cumplimos tu requerimiento: Beta es el parámetro principal
              labelP1 = "Beta"; 
              showP2 = false; // La exponencial solo necesita 1 parámetro
              break;
            case Generator.uniform:
              labelP1 = "Mínimo (a)";
              labelP2 = "Máximo (b)";
              break;
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: AppColors.bgCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Estación ${idx + 1}: ${stage.name}", 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                      if (stages.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent), 
                          onPressed: () => onRemove(idx)
                        )
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Selector de Distribución
                  DropdownButtonFormField<Generator>(
                    value: stage.type,
                    dropdownColor: AppColors.bgPrimary,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Distribución",
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.black12,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: Generator.values.map((g) => DropdownMenuItem(
                      value: g, 
                      child: Text(g.toString().split('.').last.toUpperCase())
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        stage.type = v;
                        // Forzamos la reconstrucción si el padre pasa el callback, 
                        // o confiamos en que el setState del padre reconstruya este widget.
                        if (onTypeChanged != null) onTypeChanged!(stage, v);
                      }
                    }, 
                  ),
                  const SizedBox(height: 12),

                  // Inputs Dinámicos
                  Row(
                    children: [
                      Expanded(child: _buildInput(stage.p1Ctrl, labelP1)),
                      const SizedBox(width: 8),
                      // Ocultamos visualmente el segundo input si es exponencial
                      if (showP2) ...[
                        Expanded(child: _buildInput(stage.p2Ctrl, labelP2)),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: _buildInput(stage.capacityCtrl, "Capacidad")),
                    ],
                  )
                ],
              ),
            ),
          );
        }).toList(),
        
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text("AGREGAR NUEVA ESTACIÓN"),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.green,
              side: const BorderSide(color: AppColors.green),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
        isDense: true,
        filled: true,
        fillColor: Colors.black12,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      keyboardType: TextInputType.number,
    );
  }
}