import 'package:flutter/material.dart';
import '../models/simulation_models.dart';
import '../../../core/theme/app_colors.dart';

class SimulationKpiCard extends StatelessWidget {
  final SimulationResult result;
  const SimulationKpiCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    int totalServed = result.hours.fold(0, (sum, item) => sum + item.served);
    int totalLeft = result.hours.fold(0, (sum, item) => sum + item.leftCount);
    int totalPending = result.hours.fold(0, (sum, item) => sum + item.pending);
    int totalUnsatisfied = totalLeft + totalPending;

    double satPct = result.totalCars == 0 ? 0 : (totalServed / result.totalCars);
    double unsatPct = result.totalCars == 0 ? 0 : (totalUnsatisfied / result.totalCars);

    return Card(
      color: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Resultados Generales", 
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _kpiTextItem("Total Coches", "${result.totalCars}", Colors.blueAccent),
                _kpiTextItem("Espera Prom.", "${result.avgWaitTime.toStringAsFixed(2)} m", Colors.orangeAccent),
                // Nueva métrica visible
                _kpiTextItem("Espera Máx.", "${result.maxWaitTime.toStringAsFixed(2)} m", Colors.redAccent),
              ],
            ),
            
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 10),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDonut(satPct, AppColors.green, "Satisfechos", totalServed),
                _buildDonut(unsatPct, Colors.redAccent, "Insatisfechos", totalUnsatisfied),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ... (Resto de los métodos auxiliares _kpiTextItem y _buildDonut iguales que en la versión anterior) ...
  Widget _kpiTextItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildDonut(double pct, Color color, String label, int count) {
     // ... (Código del Donut igual) ...
     return Column(
      children: [
        SizedBox(
          width: 70, height: 70,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(value: 1, strokeWidth: 8, valueColor: AlwaysStoppedAnimation(color.withOpacity(0.1))),
              CircularProgressIndicator(value: pct, strokeWidth: 8, valueColor: AlwaysStoppedAnimation(color), strokeCap: StrokeCap.round),
              Text("${(pct * 100).toStringAsFixed(0)}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text("$count autos", style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}