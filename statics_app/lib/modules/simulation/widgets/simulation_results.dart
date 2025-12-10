import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/simulation_models.dart';

class SimulationResults extends StatelessWidget {
  final SimResultV2 result;
  final double lambda;
  final int hours;

  const SimulationResults({
    super.key, 
    required this.result, 
    required this.lambda, 
    required this.hours
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        _PoissonAndRandomsCard(lambda: lambda, hours: hours),
        const SizedBox(height: 12),
        _GlobalSummaryCard(result: result),
        const SizedBox(height: 12),
        _HourlyDetailList(hoursList: result.hours),
      ],
    );
  }
}

// --- WIDGETS PRIVADOS INTERNOS (Extraídos del archivo original) ---

class _GlobalSummaryCard extends StatelessWidget {
  final SimResultV2 result;
  const _GlobalSummaryCard({required this.result});

  // Widget Donut privado (ya no se ve en la pantalla principal)
  Widget _donut(double pct, Color color, String label, {double size = 72}) {
    final value = (pct.clamp(0.0, 100.0)) / 100.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            value: value,
            strokeWidth: 10,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${pct.toStringAsFixed(0)}%", style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        )
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cálculos de totales
    int totalSatisfied = 0;
    int totalUnsatisfied = 0;
    int totalPending = 0;

    for (final h in result.hours) {
      totalSatisfied += h.served;
      totalPending += h.pending;
      // Lógica de conteo de insatisfechos
      try {
        if ((h as dynamic).leftCount != null) {
          totalUnsatisfied += (h as dynamic).leftCount as int;
        } else {
           totalUnsatisfied += h.cars.where((c) {
              try { return (c as dynamic).left == true; } catch (_) { return false; }
           }).length;
        }
      } catch (_) {
         totalUnsatisfied += h.cars.where((c) {
            try { return (c as dynamic).left == true; } catch (_) { return false; }
         }).length;
      }
    }

    final double satPct = result.totalCars == 0 ? 0.0 : (totalSatisfied / result.totalCars) * 100.0;
    final double unsatPct = result.totalCars == 0 ? 0.0 : ((totalUnsatisfied+totalPending) / result.totalCars) * 100.0;

    return Card(
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statItem(result.totalCars.toString(), "Total Autos"),
                const SizedBox(width: 16),
                _statItem(result.avgWaitTime.toStringAsFixed(2), "Espera Prom. (min)"),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Satisfacción del Cliente", style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(children: [_donut(satPct, Colors.green, "Satisfechos", size: 80), const SizedBox(height: 8), Text("$totalSatisfied autos", style: TextStyle(fontSize: 12, color: Colors.white70))]),
                      Column(children: [_donut(unsatPct, Colors.red, "Insatisfechos", size: 80), const SizedBox(height: 8), Text("$totalUnsatisfied autos", style: TextStyle(fontSize: 12, color: Colors.white70))]),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withOpacity(0.3))),
                      child: Text("Pendientes hoy: $totalPending autos", style: const TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String val, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(val, style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
        ],
      ),
    );
  }
}

class _PoissonAndRandomsCard extends StatelessWidget {
  final double lambda;
  final int hours;
  const _PoissonAndRandomsCard({required this.lambda, required this.hours});

  List<Map<String,double>> _buildPoissonTable(double lambda, int hours) {
    List<Map<String,double>> table = [];
    double e_minus_lambda = math.exp(-lambda);
    double pk = e_minus_lambda; 
    double cumulative = 0.0;
    for (int k = 0; k < hours; k++) {
      if (k == 0) pk = e_minus_lambda;
      else pk = pk * lambda / k;
      cumulative += pk;
      table.add({ 'x': k.toDouble(), 'cdf': cumulative });
    }
    return table;
  }

  List<Map<String, dynamic>> _buildRandomsMapped(List<Map<String,double>> cdfTable, int n) {
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
    return Card(
      color: AppColors.bgCard,
      child: SizedBox(
        height: 180,
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Poisson y mapeo (Horizontales)", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: poissonTable.map((r) => DataColumn(label: Text('X=${r['x']!.toInt()}'))).toList(),
                  rows: [DataRow(cells: poissonTable.map((r) => DataCell(Text(r['cdf']!.toStringAsFixed(4)))).toList())],
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: List.generate(hours, (i) => DataColumn(label: Text('${i+1}'))),
                  rows: [
                    DataRow(cells: _buildRandomsMapped(poissonTable, hours).map((r) => DataCell(Text((r['u'] as double).toStringAsFixed(4)))).toList()),
                    DataRow(cells: _buildRandomsMapped(poissonTable, hours).map((r) => DataCell(Text('${r['xi']}'))).toList()),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _HourlyDetailList extends StatelessWidget {
  final List<HourMetrics> hoursList;
  const _HourlyDetailList({required this.hoursList});

  Widget _badge(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.4))),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: hoursList.length,
      itemBuilder: (ctx, idx) {
        final h = hoursList[idx];
        // ... (Lógica de conteo repetida pero encapsulada aquí para pintar la tarjeta de hora) ...
        int hSatisfied = h.served;
        int hPending = h.pending;
        int hUnsatisfied = h.cars.where((c) {
             try { return (c as dynamic).left == true; } catch (_) { return false; }
        }).length;

        return Card(
          color: AppColors.bgCard,
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Hora ${h.hourIndex} • Llegadas estimadas: ${h.estimated}", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                _badge(Colors.green, "Satisfechos: $hSatisfied"),
                const SizedBox(width: 8),
                _badge(Colors.red, "Insatisfechos: ${hUnsatisfied+hPending}"), // Simplificado
              ]),
              const SizedBox(height: 10),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text("Detalle de carros", style: TextStyle(color: Colors.white70, fontSize: 13)),
                children: h.cars.map((c) => ListTile(
                  title: Text("Carro ${c.id}"), 
                  subtitle: Text("Espera: ${c.wait.toStringAsFixed(2)} min"),
                  trailing: Text("${(c.total-c.wait).toStringAsFixed(2)} min total", style: TextStyle(color: AppColors.green)),
                )).toList(),
              ),
            ]),
          ),
        );
      },
    );
  }
}