// lib/modules/montecarlo/widgets/variable_list_widget.dart
import 'package:flutter/material.dart';
import '../models/montecarlo_models.dart';
import '../../../core/theme/app_colors.dart';

class VariableListWidget extends StatefulWidget {
  final List<McVariable> variables;
  final VoidCallback onAdd;
  final Function(int) onRemove;

  const VariableListWidget({
    super.key, 
    required this.variables, 
    required this.onAdd, 
    required this.onRemove
  });

  @override
  State<VariableListWidget> createState() => _VariableListWidgetState();
}

class _VariableListWidgetState extends State<VariableListWidget> {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.bgCard,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Variables del Sistema (Xi)", 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                ),
                TextButton.icon(
                  onPressed: widget.onAdd, 
                  icon: const Icon(Icons.add_circle, size: 20), 
                  label: const Text("NEW"),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.green,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
            if (widget.variables.isEmpty) 
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                alignment: Alignment.center,
                child: const Text("Agrega variables para iniciar", 
                  style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic)
                ),
              ),
            ...widget.variables.asMap().entries.map((e) {
              int i = e.key;
              McVariable v = e.value;
              String autoName = "X${i + 1}"; // Nombre automático visual

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10)
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // BADGE AUTOMÁTICO (X1, X2...)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                            ]
                          ),
                          child: Text(autoName, 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Selector de Distribución
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.bgPrimary.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8)
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<McDistType>(
                                value: v.type,
                                dropdownColor: AppColors.bgCard,
                                isExpanded: true,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                                items: const [
                                  DropdownMenuItem(value: McDistType.normal, child: Text("Normal")),
                                  DropdownMenuItem(value: McDistType.exponential, child: Text("Exponencial")),
                                  DropdownMenuItem(value: McDistType.uniform, child: Text("Uniforme")),
                                ],
                                onChanged: (val) => setState(() => v.type = val!),
                              ),
                            ),
                          ),
                        ),
                        
                        // Botón Eliminar
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 22, color: Colors.redAccent), 
                          onPressed: () => widget.onRemove(i),
                          tooltip: "Eliminar Variable",
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Inputs de Parámetros
                    Row(children: [
                      if(v.type == McDistType.normal) ...[
                         Expanded(child: _miniInput(v, 1, "Media (μ)")),
                         const SizedBox(width: 8),
                         Expanded(child: _miniInput(v, 2, "Varianza (σ²)")),
                      ],
                      if(v.type == McDistType.exponential) ...[
                         Expanded(child: _miniInput(v, 1, "Beta (Media)")),
                      ],
                      if(v.type == McDistType.uniform) ...[
                         Expanded(child: _miniInput(v, 1, "Mín (a)")),
                         const SizedBox(width: 8),
                         Expanded(child: _miniInput(v, 2, "Máx (b)")),
                      ]
                    ])
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _miniInput(McVariable v, int paramIdx, String label) {
    return TextFormField(
      initialValue: paramIdx == 1 ? v.param1.toString() : v.param2.toString(),
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label, 
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
        floatingLabelStyle: const TextStyle(color: AppColors.green),
        isDense: true, 
        filled: true,
        fillColor: Colors.black26, // Fondo oscuro
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.green)),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (val) {
        double d = double.tryParse(val) ?? 0;
        if(paramIdx == 1) v.param1 = d; else v.param2 = d;
      },
    );
  }
}