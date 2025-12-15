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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Variables Aleatorias (Xi)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: widget.onAdd, 
                  icon: const Icon(Icons.add, size: 16), 
                  label: const Text("Agregar"),
                  style: TextButton.styleFrom(foregroundColor: AppColors.green),
                )
              ],
            ),
            if (widget.variables.isEmpty) 
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Agrega variables para simular", style: TextStyle(color: Colors.white38)),
              ),
            ...widget.variables.asMap().entries.map((e) {
              int i = e.key;
              McVariable v = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: v.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                            onChanged: (val) => v.name = val,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent), 
                          onPressed: () => widget.onRemove(i)
                        )
                      ],
                    ),
                    Row(children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<McDistType>(
                            value: v.type,
                            dropdownColor: AppColors.bgCard,
                            isExpanded: true,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            items: const [
                              DropdownMenuItem(value: McDistType.normal, child: Text("Normal")),
                              DropdownMenuItem(value: McDistType.exponential, child: Text("Exponencial")),
                              DropdownMenuItem(value: McDistType.uniform, child: Text("Uniforme")),
                            ],
                            onChanged: (val) => setState(() => v.type = val!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Inputs dinámicos según distribución
                      if(v.type == McDistType.normal) ...[
                         Expanded(flex: 2, child: _miniInput(v, 1, "Media")),
                         const SizedBox(width: 4),
                         Expanded(flex: 2, child: _miniInput(v, 2, "StdDev")),
                      ],
                      if(v.type == McDistType.exponential) ...[
                         Expanded(flex: 4, child: _miniInput(v, 1, "Beta (Media)")),
                      ],
                      if(v.type == McDistType.uniform) ...[
                         Expanded(flex: 2, child: _miniInput(v, 1, "Min")),
                         const SizedBox(width: 4),
                         Expanded(flex: 2, child: _miniInput(v, 2, "Max")),
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
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 11),
        isDense: true, 
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
      ),
      keyboardType: TextInputType.number,
      onChanged: (val) {
        double d = double.tryParse(val) ?? 0;
        if(paramIdx == 1) v.param1 = d; else v.param2 = d;
      },
    );
  }
}