import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SimulationConfigCard extends StatelessWidget {
  final TextEditingController hoursCtrl;
  final TextEditingController lambdaCtrl;
  final TextEditingController toleranceCtrl;
  final TextEditingController probAbandonCtrl;
  final bool allowAbandon;
  final ValueChanged<bool> onAbandonChanged;

  const SimulationConfigCard({
    super.key,
    required this.hoursCtrl,
    required this.lambdaCtrl,
    required this.toleranceCtrl,
    required this.probAbandonCtrl,
    required this.allowAbandon,
    required this.onAbandonChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Configuración General", 
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 16),
            
            // Fila 1: Horas y Llegadas
            Row(
              children: [
                Expanded(child: _buildInput(hoursCtrl, "Horas Totales", icon: Icons.timer)),
                const SizedBox(width: 12),
                Expanded(child: _buildInput(lambdaCtrl, "Llegadas (Poisson λ/h)", icon: Icons.people)),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Switch Abandono
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Permitir Abandono de Cola", style: TextStyle(color: Colors.white)),
              value: allowAbandon,
              onChanged: onAbandonChanged,
              activeColor: AppColors.green,
            ),
            
            // Fila 2: Tolerancia y Probabilidad (Solo si abandono está activo)
             if (allowAbandon) ...[
               const SizedBox(height: 8),
               Row(
                 children: [
                   Expanded(child: _buildInput(toleranceCtrl, "Tolerancia", icon: Icons.hourglass_empty)),
                   const SizedBox(width: 12),
                   Expanded(child: _buildInput(probAbandonCtrl, "Prob. Irse", icon: Icons.calculate)),
                 ],
               ),
             ]
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, {IconData? icon}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: icon != null ? Icon(icon, color: Colors.white38, size: 20) : null,
        filled: true,
        fillColor: Colors.black12,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }
}