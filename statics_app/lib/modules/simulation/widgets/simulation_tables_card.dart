import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/theme/app_colors.dart';

class SimulationTablesCard extends StatelessWidget {
  final double lambda;
  final int hours;

  const SimulationTablesCard({super.key, required this.lambda, required this.hours});

  List<Map<String, double>> _buildPoissonTable(double lambda, int hours) {
    List<Map<String, double>> table = [];
    double eMinusLambda = math.exp(-lambda);
    double pk = eMinusLambda;
    double cumulative = 0.0;
    
    // Generamos suficientes filas para cubrir la probabilidad casi hasta 1
    // Usamos 'hours * 2' o un límite razonable como 15-20 para visualización
    int limit = math.max(hours, 15); 
    
    for (int k = 0; k < limit; k++) {
      if (k == 0) {
        pk = eMinusLambda;
      } else {
        pk = pk * lambda / k;
      }
      cumulative += pk;
      table.add({'x': k.toDouble(), 'cdf': cumulative});
      if (cumulative > 0.9999) break;
    }
    return table;
  }

  List<Map<String, dynamic>> _buildRandomsMapped(List<Map<String, double>> cdfTable, int n) {
    final rnd = math.Random();
    List<Map<String, dynamic>> rows = [];
    for (int i = 0; i < n; i++) {
      double u = rnd.nextDouble();
      int xi = 0;
      for (final row in cdfTable) {
        if (u <= row['cdf']!) {
          xi = row['x']!.toInt();
          break;
        }
      }
      rows.add({'u': u, 'xi': xi});
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final poissonTable = _buildPoissonTable(lambda, hours);
    final mappedTable = _buildRandomsMapped(poissonTable, hours);

    return Card(
      color: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Tablas de Simulación (Poisson)", 
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 12),
            
            // Tabla 1: Poisson CDF
            const Text("1. Distribución de Probabilidad Acumulada", style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 32,
                dataRowMinHeight: 32,
                columnSpacing: 20,
                border: TableBorder.all(color: Colors.white10),
                columns: poissonTable.map((r) => DataColumn(label: Text('X=${r['x']!.toInt()}', style: const TextStyle(color: Colors.white)))).toList(),
                rows: [
                  DataRow(cells: poissonTable.map((r) => DataCell(Text(r['cdf']!.toStringAsFixed(4), style: const TextStyle(color: Colors.white70)))).toList())
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Tabla 2: Mapeo
            const Text("2. Generación de Aleatorios y Llegadas", style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 32,
                dataRowMinHeight: 32,
                columnSpacing: 20,
                border: TableBorder.all(color: Colors.white10),
                columns: List.generate(hours, (i) => DataColumn(label: Text('H${i+1}', style: const TextStyle(color: Colors.white)))),
                rows: [
                  DataRow(cells: mappedTable.map((r) => DataCell(Text((r['u'] as double).toStringAsFixed(4), style: const TextStyle(color: Colors.orangeAccent)))).toList()),
                  DataRow(cells: mappedTable.map((r) => DataCell(Text('${r['xi']}', style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold)))).toList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}